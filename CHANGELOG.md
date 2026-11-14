# Changelog

Notable changes to the images in this repository. Versions follow the git tags: `vX.Y.Z` is the
[n0mjs710/hblink3](https://github.com/n0mjs710/hblink3) release the v3 image is built from, `-N` counts the
releases of this repository on top of it (the pinned commit can be past that release - see `HBLINK_GIT_REF`).
Pushing a `vX.Y.Z[-N]` tag publishes `:X.Y.Z[-N]` (v3) and `:legacy-X.Y.Z[-N]` (legacy) and a GitHub release
whose notes are that version's section below, so add the section before tagging (see [CI](./README.md#ci)).

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).


## [Unreleased]

### Added
- v3 image (`v3/Dockerfile`): [n0mjs710/hblink3](https://github.com/n0mjs710/hblink3) `f9292c2` (past v3.0.0,
  which predates XLX support) + its FastAPI dashboard on :8080 + the legacy twisted parrot (lz5pn `playback.py`,
  port 54100), as s6-overlay services (#1)
- `v3/migrate_config.py`: converts a legacy `hblink.cfg` / `rules.py` to v3, failing on anything v3 would
  silently skip; `v3/dashboard-config.py` template (#1)
- GitHub Actions builds of both images on native amd64 + arm64 runners, pushed to Docker Hub and GHCR, plus a
  weekly rebuild of `main` (#1)
- Weekly upstream check: opens a PR into `testing` when n0mjs710/hblink3 `main` or s6-overlay moves past the pin,
  with the new commits, "Action required" CHANGELOG lines and a build check (#2)
- README as a setup guide and a working example `docker-compose.yml` (#3)
- Dashboard config documents the unix-socket report feed (`REPORT_TRANSPORT: unix`) and `FILTER_COUNTRIES` (#6)
- This changelog, and a GitHub release for each `v*` tag (#9)

### Changed
- Tags: v3 is `:latest` / `:test` / `:X.Y.Z` (and still `:v3` on `main`); the legacy image moved to `:legacy` /
  `:legacy-test` / `:legacy-X.Y.Z`. **`:latest` changed meaning** - pull `:legacy` for the old image (#7)
- Legacy image: s6-overlay 3.2.0.2 -> 3.2.3.2 (services in `/etc/s6-overlay/user-bundles.d/user`), dmr_utils3
  0.1.29 -> 0.1.31, base pinned to `ubuntu:24.04`, HBlink3 / HBmonitor pinned to their final upstream commits,
  `autobahn==24.4.2` (newer breaks Twisted on Debian's pyOpenSSL) (#1)

### Removed
- `configs/` (legacy-format sample configs) and the old `manifest-*.yaml` multi-arch files (#4, #5)


[Unreleased]: https://github.com/cbodden/hblink3-docker/commits/main
