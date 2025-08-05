# ServStat: Server Usage Monitoring Tool

ServStat is a robust tool designed to monitor multiple servers for CPU, memory, and GPU usage. 

![Demonstration Image](https://user-images.githubusercontent.com/17045050/81972895-dfd6bc00-9655-11ea-9e1c-bda752e6b6bc.png)

The backend collects the stats of the machine where it is deployed and one instance should be deployed on each machine to monitor.

The frontend provides a user-friendly interface to visualize the collected data and should be deployed on only one machine. It periodically queries the hosts specified in `frontend/public/config.json` and displays the collected data in a web interface.

## Docker Deployment (Recommended)

First, build the Docker images through the Makefile.

```shell
make build
```

This builds the following services:
- the backend, which is a simple Bottle application that queries the local machine for CPU, memory, and GPU usage,
- the frontend, a Vue.js application that queries a list of backends specified in the config.json file for the collected data and displays it in a user-friendly interface,
- an Nginx reverse proxy server that is used as a unique entry point for the frontend and backend services.

Then, start the services using Docker Compose:

```shell
make up
```

To stop the services, use:

```shell
make down
```

To restart the services, use:

```shell
make restart
```

> :warning: If you modify the frontend code, you will need to rebuild the static files using `make rebuild-frontend` before rebuilding the docker image.

## Backend Deployment

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

## Frontend Building Process

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