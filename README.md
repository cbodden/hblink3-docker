# hblink3-docker

[HBlink3](https://github.com/n0mjs710/hblink3) - a DMR server / conference bridge - in one container, with its
web dashboard and a parrot (echo test on TG 9999), all run under [s6-overlay](https://github.com/just-containers/s6-overlay).
Multi-arch (amd64 / arm64) images on Docker Hub as `cbodden/hblink3-docker` and on ghcr.

| service | what | where |
|---|---|---|
| `hblink` | `bridge.py` from n0mjs710/hblink3 v3 | one UDP port per system in `hblink.cfg`, reporting feed on a unix socket (or 4321/tcp) |
| `dashboard` | the hblink3 v3 web dashboard | http on 8080, live updates over a websocket at `/ws` |
| `parrot` | the classic twisted `playback.py` (v3 archived it) | HBP server on 127.0.0.1:54100 |

## quick start

1. make a folder for the config (the example compose file uses `${STORAGE}/hblink3-docker`) and copy the samples
   out of the image:

   ```sh
   mkdir -p hblink3-docker/alias && cd hblink3-docker
   img=cbodden/hblink3-docker:latest
   docker run --rm --entrypoint cat $img /opt/HBlink3/hblink-SAMPLE.cfg          > hblink.cfg
   docker run --rm --entrypoint cat $img /opt/HBlink3/rules_SAMPLE.py            > rules.py
   docker run --rm --entrypoint cat $img /opt/HBlink3/dashboard/config_sample.py > config.py
   ```

   or start `config.py` from [`v3/dashboard-config.py`](v3/dashboard-config.py), which already points the
   alias files at `/alias/`.

2. edit them - see [configuration](#configuration) below.
3. start it with [`docker-compose.yml`](docker-compose.yml):

   ```sh
   STORAGE=/path/above/hblink3-docker docker compose up -d
   docker logs -f radio-hblink3
   ```

4. open `http://<host>:8080`.

The container uses host networking: hblink needs a UDP port per system, and with host networking
those don't have to be listed (or kept in sync) in the compose file.

## configuration

Upstream's [CONFIGURING.md](https://github.com/n0mjs710/hblink3/blob/main/CONFIGURING.md) covers every
setting. The parts that matter for this container:

| file | mounted at | notes |
|---|---|---|
| `hblink.cfg` | `/opt/HBlink3/hblink.cfg` | `[REPORTS]` needs `REPORT: True`, `REPORT_PORT` and `REPORT_CLIENTS` (read even when unused); add `REPORT_TRANSPORT: unix` and `REPORT_SOCKET: /tmp/hblink3-report.sock` so the feed doesn't listen on the host network |
| `rules.py` | `/opt/HBlink3/rules.py` | must define `BRIDGES` and `UNIT` (`UNIT = []` is fine); XLX systems go in `XLX_BRIDGES` |
| `config.py` | `/opt/HBlink3/dashboard/config.py` | dashboard: `HBLINK_TRANSPORT = 'unix'` + `HBLINK_SOCKET` matching hblink.cfg (or `HBLINK_IP` / `HBLINK_PORT` for tcp), `WEB_PORT = 8080`, and `FILTER_COUNTRIES` to keep the alias database (and RAM) small |
| `alias/` | `/alias/` | radioid peer / subscriber / talkgroup files the dashboard downloads and reads (`PATH = '/alias/'`) |

v3 gotchas:

- system modes are `SERVER` (repeaters / hotspots connect in), `OUTBOUND` (we connect out, including to
  XLX) and `OPENBRIDGE`. A stanza with any other `MODE` - like the old `MASTER` / `PEER` - is **skipped
  without an error**.
- `IP:` must be an address (`0.0.0.0` for all); an empty value stops startup.
- XLX: `MODE: OUTBOUND` with `XLX_MODULE: <letter>`, `LOOSE: True`, `SERVER_PORT: 62030`, and the system
  mapped to one bridge in `XLX_BRIDGES` (not listed in `BRIDGES`).

### parrot

The parrot listens on 127.0.0.1:54100 inside the container. Connect hblink to it with an `OUTBOUND`
stanza and put it on a TG 9999 bridge:

```ini
[PARROT]
MODE: OUTBOUND
ENABLED: True
LOOSE: False
IP: 0.0.0.0
PORT: 54099
SERVER_IP: 127.0.0.1
SERVER_PORT: 54100
PASSPHRASE: <see below>
CALLSIGN: ECHO
RADIO_ID: 9999
...                   # the rest of an OUTBOUND stanza as in hblink-SAMPLE.cfg
```

```python
BRIDGES = {
    'PARROT': [
        {'SYSTEM': 'PARROT',     'TS': 2, 'TGID': 9999, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [9999], 'OFF': [],     'RESET': []},
        {'SYSTEM': 'SERVER-1',   'TS': 2, 'TGID': 9999, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'OFF',  'ON': [9999], 'OFF': [0, 1], 'RESET': []},
    ],
}
```

The passphrase has to match the one the parrot ships with:

```sh
docker run --rm --entrypoint grep cbodden/hblink3-docker:latest PASSPHRASE /opt/parrot/playback.cfg
```

### reverse proxy

Send everything, including `/ws`, to port 8080 and let websocket upgrades through. Don't strip `/ws` -
the dashboard serves its websocket there itself. (HBmonitor, in the legacy image, used a separate port
9000 behind a stripped `/ws`.)

## images && tags

| tag | built from | |
|---|---|---|
| `:latest` | `v3/Dockerfile` on `main` | **use this** (also published as `:v3`) |
| `:test` | `v3/Dockerfile` on `testing` | for trying changes before they reach `main` |
| `:legacy` / `:legacy-test` | `Dockerfile` on `main` / `testing` | legacy: [lz5pn/HBlink3](https://github.com/lz5pn/HBlink3) (frozen 2020) + [HBmonitor](https://github.com/sp2ong/HBmonitor) (archived) - kept for rollback |
| `:X.Y.Z[-N]` / `:legacy-X.Y.Z[-N]` | a `vX.Y.Z[-N]` git tag | `X.Y.Z` = the n0mjs710/hblink3 release, `-N` = this repo's releases on top of it; changes per version in [`CHANGELOG.md`](CHANGELOG.md) |

Before 2026-11-09 the tags were the other way round (`:latest` was the legacy image, v3 was `:v3`).

Every upstream source is pinned by an `ARG` at the top of its Dockerfile: `HBLINK_GIT_REF` (n0mjs710/hblink3,
currently past v3.0.0 - the tag predates XLX support), `PARROT_GIT_REF`, `S6_OVERLAY_VERSION`. The v3 image is
based on `alpine:3.23` (Python 3.12), the legacy image on `ubuntu:24.04` (it needs Ubuntu's Twisted packages).

### CI

- [`docker-images.yml`](.github/workflows/docker-images.yml) builds both images on native amd64 && arm64
  runners and pushes them to Docker Hub && ghcr: push to `testing` -> the `-test` tags, merge to `main` ->
  `:latest` (+ `:v3`) && `:legacy`, plus a rebuild every Monday for base image / security updates. Needs the repo secrets
  `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
- [`upstream-check.yml`](.github/workflows/upstream-check.yml) runs every Monday and opens a PR into
  `testing` when n0mjs710/hblink3 `main` or s6-overlay has moved past the pin. The PR only bumps the pin;
  its description lists the new commits, CHANGELOG lines marked "Action required", and the changed files to
  check, and an image build runs on the branch as a check. A newer version closes the older PR; closing a PR
  without merging stops that version being proposed again. Needs "Allow GitHub Actions to create and approve
  pull requests" on in the repo settings.
- [`release.yml`](.github/workflows/release.yml) runs on a `v*` tag push and creates the GitHub release, with
  that version's section of [`CHANGELOG.md`](CHANGELOG.md) as the notes - it fails if the section is missing.
  Re-run it from the Actions tab with the tag to create or refresh the release of an existing tag (it then
  reads `CHANGELOG.md` from `main`). The same tag push builds `:X.Y.Z[-N]` / `:legacy-X.Y.Z[-N]`.

Nothing merges or deploys by itself. The usual flow for an upstream PR:

1. read the PR and wait for the build check
2. add a line under `## [Unreleased]` in `CHANGELOG.md` (push it to the PR branch)
3. merge it into `testing` -> `:test`
4. run `:test` on the server and check repeater logins, XLX links, the parrot and the dashboard
5. merge `testing` into `main` -> `:latest`, then pull / redeploy the stack

Releasing: rename `## [Unreleased]` to the version (`## [3.0.0-2] - YYYY-MM-DD`), add a new empty
`## [Unreleased]` above it and the compare links at the bottom, merge that to `main`, then tag `main`
(`v3.0.0-2`). Bump `-N` for changes to this repo; when the pin reaches a new n0mjs710/hblink3 release, the
next tag is that release (`v3.1.0`), then `v3.1.0-1`, ...

## moving from the legacy image

v3 renamed the system modes and moved XLX links into their own table. Convert the old files with
[`v3/migrate_config.py`](v3/migrate_config.py) rather than by hand - it fails loudly on anything v3 would
silently skip:

```sh
python3 v3/migrate_config.py old/hblink.cfg old/rules.py new/hblink.cfg new/rules.py
```

- `MODE: MASTER` -> `SERVER` (`MAX_PEERS` -> `MAX_REPEATERS`)
- `MODE: PEER` -> `OUTBOUND` (`MASTER_IP` / `MASTER_PORT` -> `SERVER_IP` / `SERVER_PORT`)
- `MODE: XLXPEER` + `XLXMODULE: 4004` -> `OUTBOUND` + `XLX_MODULE: D`, its `BRIDGES` entry moved to `XLX_BRIDGES`
- empty `IP:` -> `0.0.0.0`; `EXPORT_AMBE` / `XLXOPTIONS` dropped; `UNIT = []` added if missing

The old files are only read. Then swap the image to `:latest`, mount the new files (and a dashboard `config.py`)
as above, and point the proxy's `/ws` at 8080. Both versions use the same ports, so it's a stop / start swap.
To roll back, put back `:legacy` with the old files and the old proxy rule.
