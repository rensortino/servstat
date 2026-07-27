#!/usr/bin/env bash
#
# setup.sh — Deploy one ServStat role and print the URL it serves.
#
# ServStat is split across machines:
#   * backend  — run on EVERY monitored server. Installs the NVIDIA host
#                dependencies (driver + Container Toolkit), then starts the
#                backend, which serves GET :9989/stat.
#   * frontend — run on ONE client machine. Starts the SPA + nginx, which
#                reverse-proxies /stat/<slug>/ to each monitored backend
#                (configured in frontend/nginx.conf). No GPU needed.
#
# Usage:
#   ./setup.sh backend  [--no-up]   # on each monitored server
#   ./setup.sh frontend [--no-up]   # on the one client machine
#
#   --no-up   install/prepare only; skip build + up, but still print the URL.
#
set -euo pipefail

cd "$(dirname "$0")"

ROLE=""
RUN_UP=1
for arg in "$@"; do
  case "$arg" in
    backend|frontend) ROLE="$arg" ;;
    --no-up) RUN_UP=0 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

if [ -z "$ROLE" ]; then
  err "Specify a role: ./setup.sh backend | frontend   (see --help)"
  exit 1
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    err "This script needs root privileges (or sudo) to install packages."
    exit 1
  fi
fi

# --- Address helpers --------------------------------------------------------
# LAN address other machines on the network use to reach this host.
lan_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }
# Public (internet-facing) address, if reachable; empty otherwise.
public_ip() { curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true; }

# Host-side port from the frontend 'ports' mapping (e.g. "8000:80" -> 8000).
frontend_port() {
  local p
  p="$(grep -oE '"[0-9]+:[0-9]+"' docker-compose.frontend.yml | head -n1 | tr -d '"' | cut -d: -f1)"
  echo "${p:-80}"
}

# ============================================================================
# NVIDIA host dependencies (backend role only)
# ============================================================================
install_driver() {
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    log "NVIDIA driver already present:"
    nvidia-smi -L | sed 's/^/    /'
    return
  fi

  log "Installing NVIDIA driver via ubuntu-drivers autoinstall…"
  $SUDO apt-get update
  $SUDO apt-get install -y ubuntu-drivers-common
  $SUDO ubuntu-drivers autoinstall

  warn "A driver was just installed — a REBOOT is usually required before the"
  warn "GPU is usable by containers. Re-run this script after rebooting."
}

install_container_toolkit() {
  if command -v nvidia-ctk >/dev/null 2>&1; then
    log "NVIDIA Container Toolkit already installed ($(nvidia-ctk --version | head -n1))."
  else
    log "Installing NVIDIA Container Toolkit…"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | $SUDO gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | $SUDO tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

    $SUDO apt-get update
    $SUDO apt-get install -y nvidia-container-toolkit
  fi

  log "Wiring the NVIDIA runtime into Docker…"
  $SUDO nvidia-ctk runtime configure --runtime=docker
  if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl restart docker
  else
    warn "systemctl not found — restart the Docker daemon manually for the"
    warn "runtime change to take effect."
  fi
}

verify_gpu() {
  log "Verifying Docker can see the GPU…"
  if docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi -L; then
    log "GPU is visible inside containers. ✔"
  else
    warn "Could not run a GPU container. If you just installed the driver, reboot"
    warn "and re-run this script. Otherwise check 'nvidia-smi' on the host."
  fi
}

# ============================================================================
# Roles
# ============================================================================
setup_backend() {
  install_driver
  install_container_toolkit
  verify_gpu

  if [ "$RUN_UP" -eq 1 ]; then
    log "Building and starting the backend…"
    docker compose -f docker-compose.backend.yml build
    docker compose -f docker-compose.backend.yml up -d
  fi

  local ip; ip="$(lan_ip)"; ip="${ip:-<this-host-ip>}"
  printf '\n'
  log "Backend is serving stats at:"
  printf '\n    \033[1;32mhttp://%s:9989/stat\033[0m\n\n' "$ip"
  log "On the frontend client, add this server to frontend/nginx.conf:"
  printf '        location = /stat/<slug>/ { proxy_pass http://%s:9989/stat; }\n' "$ip"
  log "and a matching entry in frontend/public/config.json, then 'make reload-frontend'."
  log "Tip: set BACKEND_BIND=<vpn-ip> to bind :9989 to the VPN interface only."
}

setup_frontend() {
  if [ "$RUN_UP" -eq 1 ]; then
    log "Building and starting the frontend…"
    docker compose -f docker-compose.frontend.yml build
    docker compose -f docker-compose.frontend.yml up -d
  fi

  local port; port="$(frontend_port)"
  local ip; ip="$(public_ip)"; [ -z "$ip" ] && ip="$(lan_ip)"; ip="${ip:-localhost}"

  local url
  if [ "$port" = "80" ]; then url="http://$ip"; else url="http://$ip:$port"; fi

  printf '\n'
  log "ServStat frontend is available at:"
  printf '\n    \033[1;32m%s\033[0m\n\n' "$url"
}

case "$ROLE" in
  backend)  setup_backend ;;
  frontend) setup_frontend ;;
esac
