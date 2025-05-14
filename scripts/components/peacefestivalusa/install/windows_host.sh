#!/bin/bash

# PeaceFestivalUSA Windows Host Access Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - WSL2/Docker Mount Safety
# - Proper Change Workflow

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$TRAEFIK_DIR" || -z "$WORDPRESS_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Setting up Windows host browser access for ${CLIENT_ID}"

# Detect WSL environment
IS_WSL=false
if grep -q Microsoft /proc/version; then
  IS_WSL=true
  log_info "WSL environment detected"
else
  log_info "Not running in WSL, skipping Windows host access configuration"
  return 0
fi

# Get Windows host IP
WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
log_info "Windows Host IP detected: ${WINDOWS_HOST_IP}"

# Update Traefik configuration to ensure host headers are properly handled
log_info "Updating Traefik configuration for Windows host access"

# Check existing Docker network configuration
log_info "Verifying Docker network configuration"
if ! docker network ls | grep -q "${CLIENT_ID}_traefik_network"; then
  log_info "Creating traefik network"
  docker network create ${CLIENT_ID}_traefik_network
fi

# Update Traefik docker-compose to be accessible from Windows host
log_info "Updating Traefik docker-compose for Windows host access"
cat > "${TRAEFIK_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  traefik:
    container_name: ${CLIENT_ID}_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
      - "443:443"  # Adding HTTPS port for future TLS support
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro
      - ${TRAEFIK_DIR}/logs:/var/log/traefik
    networks:
      - traefik_network
    # Exposing ports and using '0.0.0.0' ensures access from Windows host
    command:
      - "--api.insecure=true"  # Making dashboard available for debugging - remove in production!
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--log.level=DEBUG"  # Temporarily increase log level for debugging
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.traefik-dashboard.loadbalancer.server.port=8080"

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
EOL

# Update Traefik static configuration
log_info "Updating Traefik static configuration"
cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles
# Updated for Windows host browser access

global:
  checkNewVersion: false
  sendAnonymousUsage: false

# Enable API and Dashboard
api:
  dashboard: true
  insecure: true  # Only for development/debugging

# Entry Points configuration - explicitly binding to all interfaces
entryPoints:
  web:
    address: ":80"
    # Using 0.0.0.0:80 to bind to all interfaces including WSL and Windows host

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${CLIENT_ID}_traefik_network"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Increase logging for debugging
log:
  level: "DEBUG"  # Will be set to INFO in production
  filePath: "/var/log/traefik/traefik.log"

accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# Update WordPress docker-compose for Windows host access
log_info "Updating WordPress docker-compose for Windows host access"
cat > "${WORDPRESS_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  wordpress:
    container_name: ${CLIENT_ID}_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
    env_file:
      - .env
    volumes:
      - ${WORDPRESS_DIR}/wp-content:/var/www/html/wp-content
      - ${WORDPRESS_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
    command: ["custom-entrypoint.sh", "apache2-foreground"]
    networks:
      - traefik_network
      - wordpress_network
    depends_on:
      - mariadb
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(\`${CLIENT_ID}.${DOMAIN}\`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
      - "traefik.docker.network=${CLIENT_ID}_traefik_network"
  
  mariadb:
    container_name: ${CLIENT_ID}_mariadb
    image: mariadb:10.5
    restart: always
    env_file:
      - .env
    environment:
      - MYSQL_DATABASE=\${WORDPRESS_DB_NAME}
      - MYSQL_USER=\${WORDPRESS_DB_USER}
      - MYSQL_PASSWORD=\${WORDPRESS_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
    volumes:
      - ${WORDPRESS_DIR}/db_data:/var/lib/mysql
    networks:
      - wordpress_network

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
  wordpress_network:
    name: ${CLIENT_ID}_wordpress_network
EOL

# Create Windows hosts file helper specifically for browser access
log_info "Creating Windows browser access guide"
cat > "${INSTALL_DIR}/windows_browser_access.md" << EOL
# Windows Browser Access Guide for PeaceFestivalUSA

## Overview

This guide explains how to access the PeaceFestivalUSA WordPress site from your Windows host browser when running in WSL.

## Adding Host Entries

For proper hostname resolution, you must add entries to your Windows hosts file:

1. Open Notepad as Administrator in Windows
2. Open the file: \`C:\\Windows\\System32\\drivers\\etc\\hosts\`
3. Add these lines to the bottom:
   ```
   127.0.0.1 ${CLIENT_ID}.${DOMAIN}
   127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN}
   ```
4. Save the file

## Accessing the Services

Once the host entries are added, you can access:

- **WordPress Site**: [http://${CLIENT_ID}.${DOMAIN}](http://${CLIENT_ID}.${DOMAIN})
- **Traefik Dashboard**: [http://traefik.${CLIENT_ID}.${DOMAIN}](http://traefik.${CLIENT_ID}.${DOMAIN})

## Troubleshooting

If you can't access the services from Windows:

1. **Check Docker Status**: Ensure the Docker containers are running:
   ```
   docker ps | grep ${CLIENT_ID}
   ```

2. **Verify Port Forwarding**: Make sure port 80 is accessible:
   ```
   curl -v localhost:80
   ```

3. **Check WSL Networking**: WSL should be forwarding ports correctly:
   ```
   netsh interface portproxy show v4tov4
   ```

4. **Restart WSL**: If needed, restart the WSL environment:
   ```
   wsl --shutdown
   ```

5. **Check Traefik Logs**:
   ```
   docker logs ${CLIENT_ID}_traefik
   ```
EOL

# Create convenience script for Windows browsers
log_info "Creating Windows browser test script"
cat > "${INSTALL_DIR}/test_windows_browser_access.sh" << 'EOL'
#!/bin/bash

# Windows Browser Access Test Script
# Following AgencyStack Charter v1.0.3 Principles

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ID=$(basename "$SCRIPT_DIR")
DOMAIN="${DOMAIN:-localhost}"

# Check if running in WSL
IS_WSL=false
if grep -q Microsoft /proc/version; then
  IS_WSL=true
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
else
  echo "ERROR: This script is intended for WSL environments only."
  exit 1
fi

echo "===== Windows Browser Access Test ====="
echo "Client ID: $CLIENT_ID"
echo "Domain: $DOMAIN"
echo "Windows Host IP: $WINDOWS_HOST_IP"
echo "========================================="

# Test from WSL to Windows loopback
echo -n "Testing Traefik access from WSL to Windows host... "
TRAEFIK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: traefik.${CLIENT_ID}.${DOMAIN}" "http://${WINDOWS_HOST_IP}:80")
if [[ "$TRAEFIK_STATUS" =~ ^(200|401|302|307)$ ]]; then
  echo "SUCCESS (HTTP $TRAEFIK_STATUS)"
else
  echo "FAILED (HTTP $TRAEFIK_STATUS)"
fi

echo -n "Testing WordPress access from WSL to Windows host... "
WP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.${DOMAIN}" "http://${WINDOWS_HOST_IP}:80")
if [[ "$WP_STATUS" =~ ^(200|302|307)$ ]]; then
  echo "SUCCESS (HTTP $WP_STATUS)"
else
  echo "FAILED (HTTP $WP_STATUS)"
fi

# Generate browser testing links
echo ""
echo "===== Browser Testing Instructions ====="
echo "Please open your Windows browser and visit:"
echo ""
echo "1. WordPress site:"
echo "   http://${CLIENT_ID}.${DOMAIN}"
echo ""
echo "2. Traefik dashboard:"
echo "   http://traefik.${CLIENT_ID}.${DOMAIN}"
echo "   (Login with admin/admin123)"
echo ""
echo "If these URLs don't work, please run:"
echo "$SCRIPT_DIR/add_windows_hosts.sh"
echo "========================================="
EOL

chmod +x "${INSTALL_DIR}/test_windows_browser_access.sh"

# Restart services to apply changes
log_info "Restarting services with Windows host compatible configuration"

# Stop all containers
log_info "Stopping existing containers"
cd "${WORDPRESS_DIR}" && docker-compose down
cd "${TRAEFIK_DIR}" && docker-compose down

# Restart Traefik with new settings
log_info "Starting Traefik with Windows host access settings"
cd "${TRAEFIK_DIR}" && docker-compose up -d

# Wait for Traefik to be ready
log_info "Waiting for Traefik to be ready..."
sleep 5

# Start WordPress
log_info "Starting WordPress with Windows host access settings"
cd "${WORDPRESS_DIR}" && docker-compose up -d

# Final verification
log_info "Testing Windows host browser access"
"${INSTALL_DIR}/test_windows_browser_access.sh"

log_info "Windows host browser access configuration complete"
log_info "Please follow the instructions in ${INSTALL_DIR}/windows_browser_access.md to access from your Windows browser"
