#!/usr/bin/env bash
## compares what the Dockerfiles pin against upstream && opens / updates one issue per upstream that moved
##   n0mjs710/hblink3 main      vs  HBLINK_GIT_REF       in v3/Dockerfile
##   s6-overlay latest release  vs  S6_OVERLAY_VERSION   in Dockerfile && v3/Dockerfile
## lz5pn/HBlink3 && sp2ong/HBmonitor (legacy image) are frozen / archived, so they aren't checked
##
## env:
##   GH_TOKEN               token for gh (issues: write)
##   REPO                   owner/repo to file the issues in (github.repository)
##   DRY_RUN                true = print the reports only, never touch issues
##   HBLINK_PINNED_OVERRIDE optional sha to pretend is pinned (testing)
##   S6_PINNED_OVERRIDE     optional version to pretend is pinned (testing)

set -euo pipefail

DRY_RUN=${DRY_RUN:-false}

## open or update the single open issue whose title starts with a prefix : file_issue <prefix> <title> <body>
file_issue() {
  local prefix=$1 title=$2 body=$3 existing
  echo "${title}"
  echo
  echo "${body}"
  echo
  if [ "${DRY_RUN}" = "true" ]; then
    echo "dry run - not touching issues"
    return
  fi
  existing=$(gh issue list -R "${REPO}" --state open --search "in:title \"${prefix}\"" \
    --json number,title -q "[.[] | select(.title | startswith(\"${prefix}\"))][0].number // empty")
  if [ -n "${existing}" ]; then
    gh issue edit "${existing}" -R "${REPO}" --title "${title}" --body "${body}"
    echo "updated issue #${existing}"
  else
    gh issue create -R "${REPO}" --title "${title}" --body "${body}"
  fi
}

#########################
###### hblink3 (v3) ######
#########################

check_hblink() {
  local upstream_repo=n0mjs710/hblink3 prefix="Upstream hblink3 update"
  local pinned upstream compare commits log watch actions tag title body

  pinned=${HBLINK_PINNED_OVERRIDE:-$(sed -n 's/^ARG HBLINK_GIT_REF=//p' v3/Dockerfile)}
  upstream=$(gh api "repos/${upstream_repo}/commits/main" --jq .sha)
  if [ -z "${pinned}" ] || [ -z "${upstream}" ]; then
    echo "hblink3: could not read pinned (${pinned:-none}) or upstream (${upstream:-none}) ref"
    return 1
  fi
  if [ "${pinned}" = "${upstream}" ]; then
    echo "hblink3 up to date : pinned ${pinned:0:7} == ${upstream_repo} main"
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
  [ "$(jq '.files | length' <<< "${compare}")" -ge 300 ] && watch="${watch}
- **list truncated** : github only returns the first 300 changed files - check the compare link"
  ## lines the CHANGELOG adds that call for config changes
  actions=$(jq -r '.files[] | select(.filename == "CHANGELOG.md") | .patch // ""' <<< "${compare}" \
    | grep -E '^\+.*(Action required|breaking|startup error|no longer)' | sed -E 's/^\+ ?/> /' || true)
  tag=$(gh api "repos/${upstream_repo}/tags" --jq '.[0].name // "none"')

  title="${prefix}: ${commits} new commits on main (${pinned:0:7} -> ${upstream:0:7})"
  body=$(cat <<EOF
${upstream_repo} main has moved past the commit pinned in \`v3/Dockerfile\`.

| | pinned | upstream main |
| :-- | :-- | :-- |
| commit | \`${pinned:0:7}\` | \`${upstream:0:7}\` |

latest tag: \`${tag}\` - **${commits} new commits** - [compare](https://github.com/${upstream_repo}/compare/${pinned}...${upstream})

### recent commits
${log}

### CHANGELOG lines that may need config changes
${actions:-- none found}

### changed files worth checking before upgrading
${watch:-- none of the usual suspects (requirements, config parsing, samples, CHANGELOG)}

### upgrade steps
- [ ] set \`ARG HBLINK_GIT_REF=${upstream}\` in \`v3/Dockerfile\`
- [ ] read the CHANGELOG; update \`v3/migrate_config.py\` / the v3 configs on 005 if the format changed
- [ ] push to \`testing\` -> CI publishes \`:v3-test\`
- [ ] run \`:v3-test\` on 005 (stack hblink3) and check logins, XLX module links, parrot, dashboard
- [ ] merge \`testing\` -> \`main\` -> CI publishes \`:v3\`, then redeploy the stack

_updated by the upstream-check workflow - $(date -u +%Y-%m-%d)_
EOF
)
  file_issue "${prefix}" "${title}" "${body}"
}

#########################
###### s6-overlay ######
#########################

check_s6() {
  local upstream_repo=just-containers/s6-overlay prefix="Upstream s6-overlay update"
  local pinned_legacy pinned_v3 pinned latest notes title body

  pinned_legacy=$(sed -n 's/^ARG S6_OVERLAY_VERSION=\([^ ]*\).*/\1/p' Dockerfile)
  pinned_v3=$(sed -n 's/^ARG S6_OVERLAY_VERSION=\([^ ]*\).*/\1/p' v3/Dockerfile)
  pinned=${S6_PINNED_OVERRIDE:-${pinned_v3}}
  latest=$(gh api "repos/${upstream_repo}/releases/latest" --jq '.tag_name | ltrimstr("v")')
  if [ -z "${pinned}" ] || [ -z "${latest}" ]; then
    echo "s6-overlay: could not read pinned (${pinned:-none}) or latest (${latest:-none}) version"
    return 1
  fi
  if [ "${pinned}" = "${latest}" ]; then
    echo "s6-overlay up to date : pinned ${pinned} == latest release"
    if [ "${pinned_legacy}" != "${pinned_v3}" ]; then
      echo "WARNING : legacy (${pinned_legacy}) && v3 (${pinned_v3}) pins differ"
    fi
    return
  fi

  ## the CHANGELOG entries newer than the pinned version (3.2.3.2 moved the user bundle - this is where it said so)
  ## not every release has a heading, so stop at the first one at or below the pinned version
  local changelog stop="" v
  changelog=$(curl -fsSL "https://raw.githubusercontent.com/${upstream_repo}/v${latest}/CHANGELOG.md" || true)
  while read -r v; do
    if [ "$(printf '%s\n%s\n' "${v}" "${pinned}" | sort -V | head -1)" = "${v}" ]; then
      stop="### Version ${v}"
      break
    fi
  done < <(sed -n 's/^### Version //p' <<< "${changelog}")
  notes=$(awk -v stop="${stop}" 'stop != "" && $0 == stop {exit} /^### Version /{f=1} f' <<< "${changelog}" | head -80)

  title="${prefix}: ${pinned} -> ${latest}"
  body=$(cat <<EOF
${upstream_repo} has a release newer than the version pinned in the Dockerfiles.

| | pinned | latest release |
| :-- | :-- | :-- |
| \`Dockerfile\` (legacy) | ${pinned_legacy} | ${latest} |
| \`v3/Dockerfile\` | ${pinned_v3} | ${latest} |

[release notes](https://github.com/${upstream_repo}/releases/tag/v${latest})

### CHANGELOG since ${pinned}
${notes:-- could not read the CHANGELOG}

### upgrade steps
- [ ] set \`ARG S6_OVERLAY_VERSION=${latest}\` in \`Dockerfile\` && \`v3/Dockerfile\`
- [ ] check the CHANGELOG for moved paths (services are registered in \`/etc/s6-overlay/user-bundles.d/user/contents.d\`)
- [ ] push to \`testing\` -> CI publishes \`:test\` && \`:v3-test\`
- [ ] run \`:v3-test\` on 005 and check all three services start
- [ ] merge \`testing\` -> \`main\` -> CI publishes \`:latest\` && \`:v3\`, then redeploy the stack

_updated by the upstream-check workflow - $(date -u +%Y-%m-%d)_
EOF
)
  if [ "${pinned_legacy}" != "${pinned_v3}" ]; then
    body="${body}

**WARNING** : legacy (\`${pinned_legacy}\`) && v3 (\`${pinned_v3}\`) pins differ"
  fi
  file_issue "${prefix}" "${title}" "${body}"
}

## run both, fail the job if either failed
rc=0
check_hblink || rc=1
echo
check_s6 || rc=1
exit ${rc}
