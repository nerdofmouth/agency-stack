#!/bin/bash

# PeaceFestivalUSA Direct Docker Approach
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Strict Containerization
# - Component Consistency

set -e

# Configuration
CLIENT_ID="peacefestivalusa"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_DIR}/traefik"
WORDPRESS_DIR="${INSTALL_DIR}/wordpress"

# Simple logging
log_info() { echo -e "[INFO] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

log_info "Starting direct Docker approach for ${CLIENT_ID}"

# 1. Clean up any existing resources
log_info "Cleaning up existing resources..."
docker stop ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true
docker rm ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true
docker network rm ${CLIENT_ID}_traefik_network 2>/dev/null || true
docker network rm ${CLIENT_ID}_wordpress_network 2>/dev/null || true

# 2. Create networks
log_info "Creating Docker networks..."
docker network create ${CLIENT_ID}_traefik_network
docker network create ${CLIENT_ID}_wordpress_network

# 3. Set up necessary directories
log_info "Setting up directories..."
mkdir -p "${TRAEFIK_DIR}/config/dynamic"
mkdir -p "${TRAEFIK_DIR}/logs"
mkdir -p "${WORDPRESS_DIR}/wp-content"
mkdir -p "${WORDPRESS_DIR}/db_data"

# 4. Create Traefik configuration
log_info "Creating Traefik configuration..."

cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${CLIENT_ID}_traefik_network"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

log:
  level: "DEBUG"
  filePath: "/var/log/traefik/traefik.log"

accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# Dashboard configuration
log_info "Creating Traefik dashboard configuration..."
DASHBOARD_PASSWORD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin admin123 | sed -e s/\\$/\\$\\$/g)

cat > "${TRAEFIK_DIR}/config/dynamic/dashboard.yml" << EOL
# Dynamic configuration for Traefik dashboard
http:
  routers:
    api:
      rule: "Host(\`traefik.${CLIENT_ID}.localhost\`)"
      service: "api@internal"
      middlewares:
        - "auth"
  middlewares:
    auth:
      basicAuth:
        users:
          - "${DASHBOARD_PASSWORD}"
EOL

# Default catch-all configuration
cat > "${TRAEFIK_DIR}/config/dynamic/default.yml" << EOL
# Default catch-all configuration
http:
  routers:
    catchall:
      rule: "HostRegexp(\`{host:.+}\`)"
      priority: 1
      service: "wordpress"
  services:
    wordpress:
      loadBalancer:
        servers:
          - url: "http://wordpress"
EOL

# WordPress specific configuration
cat > "${TRAEFIK_DIR}/config/dynamic/wordpress.yml" << EOL
# WordPress configuration
http:
  routers:
    wordpress:
      rule: "Host(\`${CLIENT_ID}.localhost\`) || Host(\`localhost\`)"
      priority: 100
      service: "wordpress"
  services:
    wordpress:
      loadBalancer:
        servers:
          - url: "http://wordpress"
EOL

# 5. Add hosts entries
log_info "Adding hosts entries..."
if ! grep -q "${CLIENT_ID}.localhost" /etc/hosts; then
  log_info "Adding ${CLIENT_ID}.localhost to /etc/hosts"
  echo "127.0.0.1 ${CLIENT_ID}.localhost traefik.${CLIENT_ID}.localhost" | sudo tee -a /etc/hosts > /dev/null
else
  log_info "Host entries already exist"
fi

# 6. Start Traefik with direct Docker command
log_info "Starting Traefik..."
docker run -d \
  --name ${CLIENT_ID}_traefik \
  --network ${CLIENT_ID}_traefik_network \
  -p 80:80 \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro \
  -v ${TRAEFIK_DIR}/logs:/var/log/traefik \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.api.rule=Host(\`traefik.${CLIENT_ID}.localhost\`)" \
  -l "traefik.http.routers.api.service=api@internal" \
  -l "traefik.http.services.api.loadbalancer.server.port=8080" \
  traefik:v2.10

log_info "Waiting for Traefik to initialize..."
sleep 5

# 7. Start MariaDB
log_info "Starting MariaDB..."
docker run -d \
  --name ${CLIENT_ID}_mariadb \
  --network ${CLIENT_ID}_wordpress_network \
  -v ${WORDPRESS_DIR}/db_data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=${CLIENT_ID}_wordpress \
  -e MYSQL_USER=${CLIENT_ID}_wp \
  -e MYSQL_PASSWORD=5oOqapxbb98hQPov \
  mariadb:10.5

log_info "Waiting for MariaDB to initialize..."
sleep 10

# 8. Start WordPress and connect to both networks
log_info "Starting WordPress..."
docker run -d \
  --name ${CLIENT_ID}_wordpress \
  --network ${CLIENT_ID}_wordpress_network \
  -v ${WORDPRESS_DIR}/wp-content:/var/www/html/wp-content \
  -e WORDPRESS_DB_HOST=mariadb \
  -e WORDPRESS_DB_NAME=${CLIENT_ID}_wordpress \
  -e WORDPRESS_DB_USER=${CLIENT_ID}_wp \
  -e WORDPRESS_DB_PASSWORD=5oOqapxbb98hQPov \
  -e WORDPRESS_DEBUG=1 \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.wordpress.rule=Host(\`${CLIENT_ID}.localhost\`) || Host(\`localhost\`)" \
  -l "traefik.http.services.wordpress.loadbalancer.server.port=80" \
  wordpress:6.1-php8.1-apache

# Connect WordPress to traefik network
log_info "Connecting WordPress to Traefik network..."
docker network connect ${CLIENT_ID}_traefik_network ${CLIENT_ID}_wordpress

# 9. Create Windows access helper for WSL environments
if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  log_info "Creating Windows host access helper..."
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  
  cat > "${INSTALL_DIR}/add_windows_hosts.bat" << EOL
@echo off
:: PeaceFestivalUSA Windows Hosts File Setup
:: Following AgencyStack Charter v1.0.3 Principles

echo Adding host entries to Windows hosts file...
echo This requires Administrator privileges
echo.

:: Add host entries
echo 127.0.0.1 ${CLIENT_ID}.localhost >> %windir%\\System32\\drivers\\etc\\hosts
echo 127.0.0.1 traefik.${CLIENT_ID}.localhost >> %windir%\\System32\\drivers\\etc\\hosts

echo.
echo Done! You can now access:
echo   - WordPress: http://${CLIENT_ID}.localhost
echo   - Traefik Dashboard: http://traefik.${CLIENT_ID}.localhost
echo.
pause
EOL

  # Create Windows browser access guide
  cat > "${INSTALL_DIR}/windows_browser_access.md" << EOL
# Windows Browser Access Guide for PeaceFestivalUSA

## Overview

This guide explains how to access the PeaceFestivalUSA WordPress site from your Windows host browser when running in WSL2.

## Quick Setup

1. **Run the Windows Hosts File Setup**
   - Open Command Prompt as Administrator
   - Run \`add_windows_hosts.bat\` which can be found at:
     \`\\\\wsl\$\\Ubuntu\\opt\\agency_stack\\clients\\${CLIENT_ID}\\add_windows_hosts.bat\`

2. **Access in Browser**
   - WordPress: [http://${CLIENT_ID}.localhost](http://${CLIENT_ID}.localhost)
   - Traefik Dashboard: [http://traefik.${CLIENT_ID}.localhost](http://traefik.${CLIENT_ID}.localhost)

## Manual Setup

If the quick setup doesn't work, follow these manual steps:

1. **Edit Windows Hosts File**
   - Open Notepad as Administrator
   - Open \`C:\\Windows\\System32\\drivers\\etc\\hosts\`
   - Add these lines:
     ```
     127.0.0.1 ${CLIENT_ID}.localhost
     127.0.0.1 traefik.${CLIENT_ID}.localhost
     ```
   - Save the file

2. **Direct IP Access**
   - If hostname resolution doesn't work, use direct IP access:
     - [http://${WINDOWS_HOST_IP}:80](http://${WINDOWS_HOST_IP}:80)

## Troubleshooting

1. **Check Traefik logs**:
   ```bash
   docker logs ${CLIENT_ID}_traefik
   ```

2. **Verify container status**:
   ```bash
   docker ps -a | grep ${CLIENT_ID}
   ```

3. **Restart WSL**:
   ```powershell
   wsl --shutdown
   ```
EOL
fi

# 10. Create test script
log_info "Creating test script..."
cat > "${INSTALL_DIR}/test_browser_access.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Browser Access Test
# Following AgencyStack Charter v1.0.3 Principles

CLIENT_ID="peacefestivalusa"

echo "Testing local access..."
echo -n "  Traefik root: "
curl -s -o /dev/null -w "%{http_code}" http://localhost

echo -n "  WordPress via Host header: "
curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.localhost" http://localhost

if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  echo "Detected WSL environment"
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  
  echo "Testing Windows host browser access..."
  echo -n "  Windows host direct: "
  curl -s -o /dev/null -w "%{http_code}" http://${WINDOWS_HOST_IP}
  
  echo -n "  Windows host with WordPress header: "
  curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.localhost" http://${WINDOWS_HOST_IP}
fi

echo "Done testing!"
EOL
chmod +x "${INSTALL_DIR}/test_browser_access.sh"

# 11. Run simple test
log_info "Running quick test..."
log_info "Wait a moment for all containers to initialize..."
sleep 10

if curl -s http://localhost | grep -q -i "wordpress"; then
  log_success "Local access is working!"
else
  log_warning "Local access test not returning WordPress content."
fi

log_success "PeaceFestivalUSA deployment is complete!"
log_info "Please follow the Windows browser access guide at: ${INSTALL_DIR}/windows_browser_access.md"
log_info "Run test script for more details: ${INSTALL_DIR}/test_browser_access.sh"
