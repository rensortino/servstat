# ServStat: Server Usage Monitoring Tool

ServStat is a robust tool designed to monitor multiple servers for CPU, memory, and GPU usage. 

![Demonstration Image](https://user-images.githubusercontent.com/17045050/81972895-dfd6bc00-9655-11ea-9e1c-bda752e6b6bc.png)

The backend collects the stats of the machine where it is deployed and one instance should be deployed on each machine to monitor.

The frontend provides a user-friendly interface to visualize the collected data and should be deployed on only one machine. It periodically queries the hosts specified in `frontend/public/config.json` and displays the collected data in a web interface.

## Docker Deployment (Recommended)

ServStat is deployed by role across machines:

- **Backend** — runs on **every server you want to monitor**. It queries the local machine for CPU, memory, GPU, and disk usage and serves them at `:9989/stat`.
- **Frontend** — runs on **one client machine only**. It serves the Vue.js UI and reverse-proxies each monitored backend through a single nginx entry point.

### On each monitored server

`setup.sh backend` installs the NVIDIA host dependencies (driver + Container Toolkit), starts the backend, and prints the `http://<ip>:9989/stat` URL to register on the client:

```shell
./setup.sh backend
```

Or drive it manually with the Makefile:

```shell
make backend-build
make backend-up          # backend-down / backend-restart / backend-logs
```

### On the client machine

Point the frontend at your servers by adding, **per monitored server**, a proxy block in `frontend/nginx.conf`:

```nginx
location = /stat/gpu01/ { proxy_pass http://192.168.1.11:9989/stat; ... }
```

and a matching entry in `frontend/public/config.json`:

```json
{ "name": "GPU 01", "link": "/stat/gpu01/" }
```

Then start the frontend. `setup.sh frontend` builds/starts it and prints the public URL:

```shell
./setup.sh frontend
```

Or manually:

```shell
make frontend-build
make frontend-up         # frontend-down / frontend-restart / frontend-logs
```

The frontend is published on host port `8000`.

> :warning: After editing `nginx.conf` or `config.json`, rebuild the frontend image with `make rebuild-frontend`.

## Manual Deployment

### Backend

Create a virtual environment and install the requirements:

```shell
cd backend
uv venv
source venv/bin/activate
uv pip install -r requirements.txt
```

Launch the API server:

```shell
python main.py --host=0.0.0.0 --port=9989
```

### Frontend

This process has been tested with Node.js v14.16.0 and Ubuntu 20.04.

```shell
cd frontend

npm install

# Add your server configuration
vim public/config.json

# Build the static site
npm run build

# Or build with a custom base path
npx vite build --base=/base/path/
```

After building, serve the `dist/` folder using a web server:

```shell
# Copy files to the document root
cp -r dist/* /var/www/html/
```