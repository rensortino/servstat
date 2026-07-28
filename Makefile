# ServStat is deployed by role across machines:
#   * backend  — on every monitored server   (docker-compose.backend.yml)
#   * frontend — on the one client machine    (docker-compose.frontend.yml)
#
# Use the role-specific targets below on the matching machine.
.PHONY: \
	backend-build backend-up backend-down backend-restart backend-logs backend-ps \
	frontend-build frontend-up frontend-down frontend-restart frontend-logs frontend-ps \
	reload-frontend rebuild-frontend prune

BACKEND  := docker compose -f docker-compose.backend.yml
FRONTEND := docker compose -f docker-compose.frontend.yml

# --- Backend (run on each monitored server) ---------------------------------
backend-build:
	$(BACKEND) build

backend-up:
	$(BACKEND) up -d

backend-down:
	$(BACKEND) down

backend-restart: backend-down backend-up

backend-logs:
	$(BACKEND) logs -f

backend-ps:
	$(BACKEND) ps

# --- Frontend (run on the one client machine) -------------------------------
frontend-build:
	$(FRONTEND) build

frontend-up:
	$(FRONTEND) up -d

frontend-down:
	$(FRONTEND) down

frontend-restart: frontend-down frontend-up

frontend-logs:
	$(FRONTEND) logs -f

frontend-ps:
	$(FRONTEND) ps

# Apply server-list changes: nginx.conf + config.json are bind-mounted, so a
# config test + reload picks them up with no rebuild and no dropped connections.
reload-frontend:
	$(FRONTEND) exec frontend nginx -t
	$(FRONTEND) exec frontend nginx -s reload

# Rebuild the frontend image and recreate it (after changing the SPA source).
rebuild-frontend:
	$(FRONTEND) build
	$(FRONTEND) up -d

# --- Shared -----------------------------------------------------------------
prune:
	docker container prune
	docker image prune
