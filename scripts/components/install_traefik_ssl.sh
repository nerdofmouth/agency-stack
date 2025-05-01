#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: traefik_ssl.sh
# Path: /scripts/components/install_traefik_ssl.sh
#

# Enforce containerization (prevent host contamination)

# install_traefik_ssl.sh: Installs Traefik reverse proxy with SSL for AgencyStack
set -e
COMPONENT=traefik_ssl
LOGFILE="/var/log/agency_stack/components/${COMPONENT}.log"
CLIENT_ID=${CLIENT_ID:-default}
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
mkdir -p "$INSTALL_DIR"
mkdir -p "$(dirname "$LOGFILE")"

# Write a basic docker-compose.yml for Traefik with self-signed SSL (dev mode)
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  traefik:
    image: traefik:v2.11
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.dev.acme.tlschallenge=true
      - --certificatesresolvers.dev.acme.email=admin@localhost
      - --certificatesresolvers.dev.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - agency_stack_net
networks:
  agency_stack_net:
    external: true
EOF

# Create the Docker network if it doesn't exist
if ! docker network ls | grep -q agency_stack_net; then
  docker network create agency_stack_net

# Prepare letsencrypt storage
mkdir -p "$INSTALL_DIR/letsencrypt"
touch "$INSTALL_DIR/letsencrypt/acme.json"
chmod 600 "$INSTALL_DIR/letsencrypt/acme.json"

# Start Traefik
cd "$INSTALL_DIR"
echo "[INFO] Starting Traefik via docker compose..." | tee -a "$LOGFILE"
docker compose up -d | tee -a "$LOGFILE"

# Print dashboard info
echo "[INFO] Traefik dashboard should be available on https://<your-domain>:8080 (insecure, dev mode)" | tee -a "$LOGFILE"
echo "[SUCCESS] Traefik SSL install complete." | tee -a "$LOGFILE"
exit 0
