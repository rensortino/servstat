# Use .PHONY to declare targets that are not actual files.
# This prevents conflicts with files of the same name and improves performance.
.PHONY: build up down restart logs ps prune rebuild-frontend 

# Build the Docker images as defined in docker-compose.yml
build:
	docker compose build

# Create and start the containers in detached mode
up:
	docker compose up -d

# Stop and remove the containers, networks, and volumes
down:
	docker compose down

# A convenient shortcut to restart the services
restart: down up

# Follow the logs of the running services
logs:
	docker compose logs -f

# List the running containers
ps:
	docker compose ps

prune:
	docker container prune
	docker image prune

# Rebuild the frontend service specifically and restart it without affecting other services.
# This assumes you have a service named 'frontend' in your docker-compose.yml.
rebuild-frontend:
	cd frontend; \
	npm run build; \
	cd ..; \
	docker build -t servstat-frontend frontend; \