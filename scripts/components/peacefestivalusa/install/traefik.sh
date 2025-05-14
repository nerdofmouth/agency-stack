#!/bin/bash

# PeaceFestivalUSA Traefik Installation Script
# Following AgencyStack Charter v1.0.3 Principles

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$TRAEFIK_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Setting up Traefik for ${CLIENT_ID}"

# Create Traefik directory structure
mkdir -p "${TRAEFIK_DIR}/config"
mkdir -p "${TRAEFIK_DIR}/config/dynamic"
mkdir -p "${TRAEFIK_DIR}/certs"
mkdir -p "${TRAEFIK_DIR}/logs"

# Create Traefik configuration
log_info "Creating Traefik configuration files"

# Main traefik.yml
cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: "INFO"
  filePath: "/var/log/traefik/traefik.log"

api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    # HTTP-only configuration for local development
    # For production, use HTTPS and redirections
  
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Configure service discovery
accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# Dashboard security configuration
DASHBOARD_PASSWORD=$(htpasswd -nb admin admin123 | sed -e s/\\$/\\$\\$/g)
cat > "${TRAEFIK_DIR}/config/dynamic/dashboard.yml" << EOL
# Dynamic configuration for Traefik dashboard
http:
  routers:
    dashboard:
      rule: "Host(\`traefik.${CLIENT_ID}.${DOMAIN}\`)"
      service: "api@internal"
      middlewares:
        - "auth"
  middlewares:
    auth:
      basicAuth:
        users:
          - "${DASHBOARD_PASSWORD}"
EOL

# WordPress routing configuration
cat > "${TRAEFIK_DIR}/config/dynamic/wordpress.yml" << EOL
# Dynamic configuration for WordPress routing
http:
  routers:
    wordpress:
      rule: "Host(\`${CLIENT_ID}.${DOMAIN}\`)"
      service: "wordpress"
  services:
    wordpress:
      loadBalancer:
        servers:
          - url: "http://wordpress"
EOL

# Create Traefik docker-compose.yml
cat > "${TRAEFIK_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  traefik:
    container_name: ${CLIENT_ID}_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro
      - ${TRAEFIK_DIR}/logs:/var/log/traefik
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: false
EOL

log_info "Traefik configuration complete"
