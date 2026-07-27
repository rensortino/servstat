# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

ServStat is split into two independently deployed parts:

- **`backend/`** — A Python (Bottle) service that runs on **each monitored server** and exposes a single endpoint `GET /stat` returning a JSON snapshot of host name, CPU info/usage, memory, swap, GPU stats (via `gpustat`), and disk partitions/usage. Static CPU info is computed once at startup; GPU and disk queries are cached for `CACHE_TIME = 5` seconds (see `backend/main.py`). The endpoint sets `Access-Control-Allow-Origin: *` so the frontend can poll cross-origin.
- **`frontend/`** — A Vue 3 SPA (Vite + Pug templates + Less + Fomantic UI) that runs in the browser, fetches `public/config.json` at startup to learn which backend `/stat` URLs to poll, and re-fetches each server on its own interval (`server.interval` → `json.interval` → 5000 ms). State for pinned servers and dark mode is kept in `localStorage`. There is **no build-time coupling** between frontend and backend — the frontend talks to backends purely via the configured URLs at runtime.

Implications when editing:
- Changing the shape of `/stat` requires matching changes in `frontend/src/App.vue` (the keys are read directly there, e.g. `server.data.cpu.percent`, `gpu['memory.used']`, `disk.usage.total`).
- Adding new top-level metric panels usually means: add a function in `backend/main.py` (with caching if it's expensive), add it to the `/stat` dict, then render in `App.vue`.
- `public/config.json` is **served as a static asset** and read at runtime — it is not bundled. Deployments customize it per-install without rebuilding.

## Common commands

### Backend
```shell
cd backend
python3 -m pip install -r requirements.txt
python3 main.py --host=0.0.0.0 --port=9989          # defaults: gunicorn server, 1 worker
python3 main.py --server=wsgiref                    # swap to bottle's built-in dev server
```

There is no test suite, linter, or formatter configured. `backend/servstat.conf` is a supervisor unit for running the service under `/etc/supervisor/conf.d/`.

### Frontend
```shell
cd frontend
npm install
npm run dev                                          # vite dev server
npm run build                                        # → dist/
npx vite build --base=/some/sub/path/                # build for non-root deployment
```

After `npm run build`, copy `dist/*` to the webroot. Update `public/config.json` (or the deployed `config.json`) to point at the backend `/stat` URLs — each entry is either a bare URL string or `{ name, link, interval }`.

### Docker deployment

Deployment is **split by role** across machines — there is no combined compose file:

- **`docker-compose.backend.yml`** — run on **every monitored server**. Builds `backend` (Bottle + gunicorn, NVIDIA GPU reservation, mounts `/:/host_root:ro` and `/data:/host_data:ro` so disk stats reflect the host) and publishes `9989` so the frontend client can reach `/stat` over the LAN.
- **`docker-compose.frontend.yml`** — run on **one client machine only**. Builds `frontend` (multi-stage: Vite build → nginx:alpine serving the SPA *and* reverse-proxying `/stat/<slug>/` to each remote backend). Publishes host port `8000` → container `80`. No GPU.

`setup.sh <role>` drives each: `./setup.sh backend` installs the NVIDIA host deps (driver + Container Toolkit), starts the backend, and prints its `http://<ip>:9989/stat` URL; `./setup.sh frontend` starts the SPA and prints the public frontend URL. The `Makefile` has role-prefixed targets (`backend-*`, `frontend-*`, plus `rebuild-frontend`).

The frontend reaches backends via **nginx reverse-proxy per host** (not direct CORS). To add a monitored machine: add a `location = /stat/<slug>/ { proxy_pass http://<ip>:9989/stat; ... }` block in `frontend/nginx.conf`, a matching `{ "name": ..., "link": "/stat/<slug>/" }` entry in `frontend/public/config.json`, then `make rebuild-frontend`. Backends only need to be reachable from the frontend host (not from browsers directly).
