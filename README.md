# hblink3-docker

HBlink3 DMR server in a container, run under s6-overlay with its dashboard and a parrot.

Two images are built from this repo:

| | `Dockerfile` (legacy) | `v3/Dockerfile` |
|---|---|---|
| HBlink3 | [lz5pn/HBlink3](https://github.com/lz5pn/HBlink3) (frozen 2020) | [n0mjs710/hblink3](https://github.com/n0mjs710/hblink3) (pinned past v3.0.0 for XLX support) |
| dashboard | [sp2ong/HBmonitor](https://github.com/sp2ong/HBmonitor) on 8080 (archived) | v3's own dashboard on 8080 |
| parrot | `playback.py` | the same legacy `playback.py`, in its own venv |
| tags | `:test` / `:latest` / `:X.Y.Z` | `:v3-test` / `:v3` / `:v3-X.Y.Z` |

## builds

GitHub Actions (`.github/workflows/docker-images.yml`) builds both images on native amd64 + arm64
runners and pushes multi-arch tags to Docker Hub (`cbodden/hblink3-docker`) and ghcr:

- push to `testing` -> `:test` and `:v3-test`
- merge to `main` -> `:latest` and `:v3`, plus a weekly rebuild for base image updates
- tag `vX.Y.Z` -> `:X.Y.Z` and `:v3-X.Y.Z`

Needs the repo secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.

Upstream repos and s6-overlay are pinned by `ARG`s at the top of each Dockerfile.

## volumes

| legacy | v3 | |
|---|---|---|
| `/opt/HBlink3/hblink.cfg` | `/opt/HBlink3/hblink.cfg` | main config |
| `/opt/HBlink3/rules.py` | `/opt/HBlink3/rules.py` | bridges |
| `/opt/HBmonitor/config.py` | `/opt/HBlink3/dashboard/config.py` | dashboard config |
| `/alias/` | `/alias/` | radioid alias files |

Both run with host networking (see `docker-compose.yml` / `v3/docker-compose.yml`).

## moving to v3

v3 renamed the system modes and moved XLX links into their own table, so the configs need converting.
Unknown modes are skipped silently by v3, so don't hand-edit - use the script, which fails loudly instead.

1. convert the live configs (writes new files, leaves the old ones alone):

   ```sh
   python3 v3/migrate_config.py hblink.cfg rules.py v3/hblink.cfg v3/rules.py
   ```

   - `MODE: MASTER` -> `SERVER` (`MAX_PEERS` -> `MAX_REPEATERS`)
   - `MODE: PEER` -> `OUTBOUND` (`MASTER_IP`/`MASTER_PORT` -> `SERVER_IP`/`SERVER_PORT`)
   - `MODE: XLXPEER` + `XLXMODULE: 4004` -> `OUTBOUND` + `XLX_MODULE: D`, members moved to `XLX_BRIDGES`
   - empty `IP:` -> `0.0.0.0`, `EXPORT_AMBE` / `XLXOPTIONS` dropped, `UNIT = []` added if missing

2. copy `v3/dashboard-config.py` to `v3/config.py` next to them.
3. swap the stack to `v3/docker-compose.yml` (`:v3`). Host networking means the two can't run side by side.
4. point the reverse proxy's `/ws` at the dashboard port (8080) without stripping `/ws` - HBmonitor's
   websocket was a separate port (9000) behind a stripped `/ws`.
5. check: the log shows each repeater logging in and `XLX module link sent: unlink then module X` per XLX
   system; xlxd shows each module linked; parrot on TG 9999 echoes; dashboard on :8080 updates live.
6. roll back by pointing the stack at `:latest` (or the old image) with the old files and the proxy's
   `/ws` back on 9000 - nothing in the old files was changed.

Done on server-sendai-005 2026-11-09: the old image is kept locally as `cbodden/hblink3-docker:pre-v3`,
Portainer's original stack file as `docker-compose.yml.pre-v3` next to it, and the Traefik route as
`/docker-swarm/appdata/traefik/hblink.yml.bak-pre-v3`.
