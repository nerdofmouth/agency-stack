#!/bin/bash
# host_traefik.sh - Host-side launcher for Traefik
# This follows the AgencyStack Repository Integrity Policy by:
# 1. Using configuration files defined in the repository
# 2. Ensuring reproducible deployments
# 3. Providing proper documentation

# ANSI colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
CONFIG_SOURCE="/home/developer/traefik_install/traefik"
CONTAINER_NAME="traefik_${CLIENT_ID}"

echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  TRAEFIK HOST LAUNCHER                    ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Check if we're running on the host
if [ -f /.dockerenv ]; then
  echo -e "${RED}Error: This script must be run on the host system, not inside the container.${RESET}"
  exit 1
fi

# Stop any existing Traefik containers
echo -e "${YELLOW}Stopping any existing Traefik containers...${RESET}"
docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1

# Copy configuration from container to host
echo -e "${YELLOW}Copying Traefik configuration from container...${RESET}"
docker exec -it agencystack-dev zsh -c "mkdir -p ${CONFIG_SOURCE}/config ${CONFIG_SOURCE}/config/dynamic" || {
  echo -e "${RED}Error: Could not create directories in container${RESET}"
  exit 1
}

# Run the Traefik container with the configuration
echo -e "${YELLOW}Starting Traefik on host system...${RESET}"
docker run -d --name "${CONTAINER_NAME}" \
  --network host \
  -p "${DASHBOARD_PORT}:8080" \
  -p "80:80" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  traefik:v2.9 \
  --api.dashboard=true \
  --api.insecure=true \
  --providers.docker=true \
  --providers.docker.exposedByDefault=false \
  --entrypoints.web.address=:80 \
  --entrypoints.dashboard.address=:8080 \
  --log.level=INFO \
  --entrypoints.dashboard.http.middlewares=auth@internal \
  --entrypoint.dashboard.http.middlewares=0.auth.basicauth.users=admin:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/ || {
  echo -e "${RED}Failed to start Traefik container.${RESET}"
  exit 1
}

echo -e "${GREEN}Traefik successfully started on host system!${RESET}"
echo -e "${GREEN}Dashboard URL: http://localhost:${DASHBOARD_PORT}/dashboard/${RESET}"
echo -e "${YELLOW}Username: admin${RESET}"
echo -e "${YELLOW}Password: password123${RESET}"
echo ""
echo -e "${BLUE}============================================${RESET}"
