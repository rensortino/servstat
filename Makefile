# Makefile for Docker Compose project management

# Use .PHONY to declare targets that are not actual files.
# This prevents conflicts with files of the same name and improves performance.
.PHONY: build up down backend restart logs ps rebuild-frontend full

# --- Flag handling for full ---
# Check if full is passed as an argument to make.
# e.g., `make app full`
# We filter it out from MAKECMDGOALS so make doesn't try to find a target with that name.
ifneq ($(findstring full,$(MAKECMDGOALS)),)
  # If `full` is present, include the frontend profile
  COMPOSE_ARGS := --profile frontend
  # Remove the flag from the list of goals
  MAKECMDGOALS := $(filter-out full,$(MAKECMDGOALS))
else
  # Default behavior: run backend and nginx only
  COMPOSE_ARGS :=
endif


# Build the Docker images as defined in docker-compose.yml
build:
	docker compose build

# Create and start the containers in detached mode
# Use `make up full` to start without the frontend.
up:
	docker compose $(COMPOSE_ARGS) up -d

# Stop and remove the containers, networks, and volumes
# Use `make down full` to stop without the frontend profile.
down:
	docker compose $(COMPOSE_ARGS) down

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

# Rebuild the frontend service specifically and restart it without affecting other services.
# This assumes you have a service named 'frontend' in your docker-compose.yml.
rebuild-frontend:
	cd frontend; \
	npm run build; \
	cd ..; \
	docker build -t servstat-frontend frontend; \