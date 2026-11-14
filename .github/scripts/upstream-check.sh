#!/usr/bin/env bash
## compares what the Dockerfiles pin against upstream && opens a PR into testing that bumps the pin
##   n0mjs710/hblink3 main      vs  HBLINK_GIT_REF       in v3/Dockerfile
##   s6-overlay latest release  vs  S6_OVERLAY_VERSION   in Dockerfile && v3/Dockerfile
## lz5pn/HBlink3 && sp2ong/HBmonitor (legacy image) are frozen / archived, so they aren't checked
##
## one branch per upstream version (upstream/<name>-<version>):
##   same version next week   -> the open PR's description is refreshed
##   newer version            -> new PR, the older one is closed as superseded
##   PR closed without merge  -> its branch is left alone && that version isn't proposed again
##   pin already up to date   -> leftover upstream PRs for it are closed
## new PRs get a build check by dispatching docker-images on the branch (it publishes no tags there),
## since pushes / PRs made with GITHUB_TOKEN don't trigger workflows themselves
##
## run from a checkout of BASE (testing)
## env:
##   GH_TOKEN               token for gh (contents, pull-requests, actions: write)
##   REPO                   owner/repo (github.repository)
##   BASE                   branch the PRs target (default testing)
##   DRY_RUN                true = print the reports && the pin diffs only, touch nothing
##   HBLINK_PINNED_OVERRIDE optional sha to pretend is pinned (testing)
##   S6_PINNED_OVERRIDE     optional version to pretend is pinned (testing)

set -euo pipefail

DRY_RUN=${DRY_RUN:-false}
BASE=${BASE:-testing}
BOT_NAME="github-actions[bot]"
BOT_EMAIL="41898283+github-actions[bot]@users.noreply.github.com"

## pin bumps, run from the repo root (or a copy of it)
bump_hblink() { sed -i "s/^ARG HBLINK_GIT_REF=.*/ARG HBLINK_GIT_REF=$1/" v3/Dockerfile; }
bump_s6() { sed -i "s/^ARG S6_OVERLAY_VERSION=[^ ]*/ARG S6_OVERLAY_VERSION=$1/" Dockerfile v3/Dockerfile; }

## close open upstream PRs for <name> other than <keep> : close_stale <name> <keep branch> <comment>
close_stale() {
  local name=$1 keep=$2 comment=$3 n
  for n in $(gh pr list -R "${REPO}" --state open --json number,headRefName \
      -q ".[] | select(.headRefName | startswith(\"upstream/${name}-\")) | select(.headRefName != \"${keep}\") | .number"); do
    if [ "${DRY_RUN}" = "true" ]; then
      echo "dry run - would close PR #${n}: ${comment}"
    else
      gh pr close "${n}" -R "${REPO}" --comment "${comment}" --delete-branch
    fi
  done
}

## open or refresh the bump PR : open_pr <name> <version> <title> <body> <bump command>
open_pr() {
  local name=$1 version=$2 title=$3 body=$4 bump=$5
  local branch="upstream/${name}-${version}" existing tmp new
  echo "${title}"
  echo
  echo "${body}"
  echo

  if [ "${DRY_RUN}" = "true" ]; then
    tmp=$(mktemp -d)
    mkdir -p "${tmp}/v3"
    cp Dockerfile "${tmp}/Dockerfile"
    cp v3/Dockerfile "${tmp}/v3/Dockerfile"
    (cd "${tmp}" && ${bump})
    echo "dry run - ${branch} would change:"
    diff -u Dockerfile "${tmp}/Dockerfile" || true
    diff -u v3/Dockerfile "${tmp}/v3/Dockerfile" || true
    rm -rf "${tmp}"
    close_stale "${name}" "${branch}" "superseded by ${branch}"
    return
  fi

  existing=$(gh pr list -R "${REPO}" --state open --head "${branch}" --json number -q '.[0].number // empty')
  if [ -n "${existing}" ]; then
    gh pr edit "${existing}" -R "${REPO}" --title "${title}" --body "${body}"
    echo "refreshed PR #${existing}"
  elif git ls-remote --exit-code --heads origin "${branch}" > /dev/null; then
    echo "${branch} exists with no open PR - that version was declined, not proposing it again"
    return
  else
    git switch -q -c "${branch}"
    ${bump}
    git -c user.name="${BOT_NAME}" -c user.email="${BOT_EMAIL}" commit -q -am "${title}"
    git push -q origin "${branch}"
    git switch -q "${BASE}"
    new=$(gh pr create -R "${REPO}" --base "${BASE}" --head "${branch}" --title "${title}" --body "${body}")
    echo "opened ${new}"
    gh workflow run docker-images.yml -R "${REPO}" --ref "${branch}"
    echo "dispatched docker-images on ${branch} as a build check"
    close_stale "${name}" "${branch}" "superseded by ${new}"
  fi
}

##########################
###### hblink3 (v3) ######
##########################

check_hblink() {
  local upstream_repo=n0mjs710/hblink3
  local pinned upstream compare commits log watch actions tag title body

  pinned=${HBLINK_PINNED_OVERRIDE:-$(sed -n 's/^ARG HBLINK_GIT_REF=//p' v3/Dockerfile)}
  upstream=$(gh api "repos/${upstream_repo}/commits/main" --jq .sha)
  if [ -z "${pinned}" ] || [ -z "${upstream}" ]; then
    echo "hblink3: could not read pinned (${pinned:-none}) or upstream (${upstream:-none}) ref"
    return 1
  fi
  if [ "${pinned}" = "${upstream}" ]; then
    echo "hblink3 up to date : pinned ${pinned:0:7} == ${upstream_repo} main"
    close_stale hblink3 "" "HBLINK_GIT_REF is already ${pinned:0:7} (upstream main) - closing"
    return
  fi

  compare=$(gh api "repos/${upstream_repo}/compare/${pinned}...${upstream}")
  commits=$(jq -r '.total_commits' <<< "${compare}")
  log=$(jq -r '.commits[-15:] | reverse | .[] | "- `\(.sha[0:7])` \(.commit.message | split("\n")[0])"' <<< "${compare}")
  ## files that feed the image build, the config format (v3/migrate_config.py) or the s6 run lines
  watch=$(jq -r '[.files[]
    | select((.filename | endswith("requirements.txt")) or .filename == "pyproject.toml"
             or .filename == "config.py" or .filename == "hblink-SAMPLE.cfg" or .filename == "rules_SAMPLE.py"
             or .filename == "dashboard/config_sample.py" or .filename == "CHANGELOG.md"
             or .status == "removed" or .status == "renamed")
    | "- `\(.filename)` (\(.status))"] | unique | .[]' <<< "${compare}")
  if [ "$(jq '.files | length' <<< "${compare}")" -ge 300 ]; then
    watch="${watch}
- **list truncated** : github only returns the first 300 changed files - check the compare link"
  fi
  ## lines the CHANGELOG adds that call for config changes
  actions=$(jq -r '.files[] | select(.filename == "CHANGELOG.md") | .patch // ""' <<< "${compare}" \
    | grep -E '^\+.*(Action required|breaking|startup error|no longer)' | sed -E 's/^\+ ?/> /' || true)
  tag=$(gh api "repos/${upstream_repo}/tags" --jq '.[0].name // "none"')

  title="hblink3: bump to ${upstream:0:7} (${commits} new commits on main)"
  body=$(cat <<EOF
${upstream_repo} main has moved past the commit pinned in \`v3/Dockerfile\`; this PR sets \`HBLINK_GIT_REF\` to upstream main.

| | pinned | upstream main |
| :-- | :-- | :-- |
| commit | \`${pinned:0:7}\` | \`${upstream:0:7}\` |

latest tag: \`${tag}\` - **${commits} new commits** - [compare](https://github.com/${upstream_repo}/compare/${pinned}...${upstream})

### recent commits
${log}

### CHANGELOG lines that may need config changes
${actions:-- none found}

### changed files worth checking before merging
${watch:-- none of the usual suspects (requirements, config parsing, samples, CHANGELOG)}

### before / after merging
- [ ] the docker images build check on this branch passed (amd64 + arm64)
- [ ] read the CHANGELOG; if the config format changed, update \`v3/migrate_config.py\` / the v3 configs on 005 (push to this branch)
- [ ] add a line under \`## [Unreleased]\` in this repo's \`CHANGELOG.md\` (push to this branch)
- [ ] merge -> CI publishes \`:test\`
- [ ] run \`:test\` on 005 (stack hblink3) and check logins, XLX module links, parrot, dashboard
- [ ] merge \`testing\` -> \`main\` -> CI publishes \`:latest\`, then redeploy the stack

_opened by the upstream-check workflow - refreshed $(date -u +%Y-%m-%d)_
EOF
)
  open_pr hblink3 "${upstream:0:7}" "${title}" "${body}" "bump_hblink ${upstream}"
}

########################
###### s6-overlay ######
########################

check_s6() {
  local upstream_repo=just-containers/s6-overlay
  local pinned_legacy pinned_v3 pinned latest changelog stop="" v notes title body

  pinned_legacy=$(sed -n 's/^ARG S6_OVERLAY_VERSION=\([^ ]*\).*/\1/p' Dockerfile)
  pinned_v3=$(sed -n 's/^ARG S6_OVERLAY_VERSION=\([^ ]*\).*/\1/p' v3/Dockerfile)
  pinned=${S6_PINNED_OVERRIDE:-${pinned_v3}}
  latest=$(gh api "repos/${upstream_repo}/releases/latest" --jq '.tag_name | ltrimstr("v")')
  if [ -z "${pinned}" ] || [ -z "${latest}" ]; then
    echo "s6-overlay: could not read pinned (${pinned:-none}) or latest (${latest:-none}) version"
    return 1
  fi
  if [ "${pinned}" = "${latest}" ] && [ "${pinned_legacy}" = "${latest}" ]; then
    echo "s6-overlay up to date : pinned ${pinned} == latest release"
    close_stale s6-overlay "" "S6_OVERLAY_VERSION is already ${latest} (latest release) - closing"
    return
  fi

  ## the CHANGELOG entries newer than the pinned version (3.2.3.2 moved the user bundle - this is where it said so)
  ## not every release has a heading, so stop at the first one at or below the pinned version
  changelog=$(curl -fsSL "https://raw.githubusercontent.com/${upstream_repo}/v${latest}/CHANGELOG.md" || true)
  while read -r v; do
    if [ "$(printf '%s\n%s\n' "${v}" "${pinned}" | sort -V | head -1)" = "${v}" ]; then
      stop="### Version ${v}"
      break
    fi
  done < <(sed -n 's/^### Version //p' <<< "${changelog}")
  notes=$(awk -v stop="${stop}" 'stop != "" && $0 == stop {exit} /^### Version /{f=1} f' <<< "${changelog}" | head -80)

  title="s6-overlay: bump ${pinned} -> ${latest}"
  body=$(cat <<EOF
${upstream_repo} has a release newer than the version pinned in the Dockerfiles; this PR sets \`S6_OVERLAY_VERSION\` to it in both.

| | pinned | latest release |
| :-- | :-- | :-- |
| \`Dockerfile\` (legacy) | ${pinned_legacy} | ${latest} |
| \`v3/Dockerfile\` | ${pinned_v3} | ${latest} |

[release notes](https://github.com/${upstream_repo}/releases/tag/v${latest})

### CHANGELOG since ${pinned}
${notes:-- could not read the CHANGELOG}

### before / after merging
- [ ] the docker images build check on this branch passed (amd64 + arm64)
- [ ] check the CHANGELOG for moved paths (services are registered in \`/etc/s6-overlay/user-bundles.d/user/contents.d\`)
- [ ] add a line under \`## [Unreleased]\` in this repo's \`CHANGELOG.md\` (push to this branch)
- [ ] merge -> CI publishes \`:test\` && \`:legacy-test\`
- [ ] run \`:test\` on 005 and check all three services start
- [ ] merge \`testing\` -> \`main\` -> CI publishes \`:latest\` && \`:legacy\`, then redeploy the stack

_opened by the upstream-check workflow - refreshed $(date -u +%Y-%m-%d)_
EOF
)
  open_pr s6-overlay "${latest}" "${title}" "${body}" "bump_s6 ${latest}"
}

## run both, fail the job if either failed
rc=0
check_hblink || rc=1
echo
check_s6 || rc=1
exit ${rc}
