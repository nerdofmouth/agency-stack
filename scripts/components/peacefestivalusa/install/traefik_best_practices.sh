#!/bin/bash

# PeaceFestivalUSA Traefik Best Practices Implementation
# Following AgencyStack Charter v1.0.3 Principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Component Consistency
# - Idempotency & Automation

set -e

# Configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_DIR}/traefik"
WORDPRESS_DIR="${INSTALL_DIR}/wordpress"

# Simple logging
log_info() { echo -e "[INFO] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

log_info "Starting PeaceFestivalUSA Traefik best practices implementation"

# 1. Create necessary directories
log_info "Creating required directories"
mkdir -p "${TRAEFIK_DIR}/config/dynamic"
mkdir -p "${TRAEFIK_DIR}/logs"
mkdir -p "${WORDPRESS_DIR}/wp-content"
mkdir -p "${WORDPRESS_DIR}/db_data"

# 2. Clean up existing resources following idempotency principles
log_info "Cleaning up existing resources (idempotent operation)"
docker stop ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true
docker rm ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true
docker network rm ${CLIENT_ID}_traefik_network 2>/dev/null || true
docker network rm ${CLIENT_ID}_wordpress_network 2>/dev/null || true

# 3. Create explicit networks as recommended by Traefik docs
log_info "Creating Docker networks (best practice from Traefik docs)"
docker network create ${CLIENT_ID}_traefik_network
docker network create ${CLIENT_ID}_wordpress_network

# 4. Create Traefik configuration following best practices
log_info "Creating Traefik configuration with best practices"

cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles and Traefik best practices

global:
  checkNewVersion: false
  sendAnonymousUsage: false

# API and Dashboard with secure access
api:
  dashboard: true
  insecure: true  # Only for development

# Entry points configuration - explicitly binding to all interfaces for WSL compatibility
entryPoints:
  web:
    address: ":80"

# Provider configuration - Docker provider with explicit opt-in for container exposure
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${CLIENT_ID}_traefik_network"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Logging for debugging
log:
  level: "INFO"
  filePath: "/var/log/traefik/traefik.log"

accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# 5. Create Traefik dynamic configurations
log_info "Creating Traefik dynamic configuration files"

# Dashboard security configuration
DASHBOARD_PASSWORD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin admin123 | sed -e s/\\$/\\$\\$/g)

cat > "${TRAEFIK_DIR}/config/dynamic/dashboard.yml" << EOL
# Dynamic configuration for Traefik dashboard
http:
  routers:
    api:
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

# Default catch-all configuration (best practice)
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
      rule: "Host(\`${CLIENT_ID}.${DOMAIN}\`) || Host(\`localhost\`)"
      priority: 100
      service: "wordpress"
  services:
    wordpress:
      loadBalancer:
        servers:
          - url: "http://wordpress"
EOL

# 6. Create docker-compose.yml
log_info "Creating docker-compose.yml with best practices"

cat > "${TRAEFIK_DIR}/docker-compose.yml" << EOL
# Docker Compose configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles
# Following Traefik best practices

services:
  traefik:
    image: "traefik:v2.10"
    container_name: "${CLIENT_ID}_traefik"
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entryPoints.web.address=:80"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro"
      - "${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro"
      - "${TRAEFIK_DIR}/logs:/var/log/traefik"
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
    name: ${CLIENT_ID}_traefik_network
EOL

cat > "${WORDPRESS_DIR}/docker-compose.yml" << EOL
# Docker Compose configuration for PeaceFestivalUSA WordPress
# Following AgencyStack Charter v1.0.3 Principles
# Following Traefik best practices

services:
  wordpress:
    image: "wordpress:6.1-php8.1-apache"
    container_name: "${CLIENT_ID}_wordpress"
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_NAME: ${CLIENT_ID}_wordpress
      WORDPRESS_DB_USER: ${CLIENT_ID}_wp
      WORDPRESS_DB_PASSWORD: 5oOqapxbb98hQPov
      WORDPRESS_DEBUG: 1
    volumes:
      - ${WORDPRESS_DIR}/wp-content:/var/www/html/wp-content
    networks:
      - traefik_network
      - wordpress_network
    depends_on:
      - mariadb
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(\`${CLIENT_ID}.${DOMAIN}\`) || Host(\`localhost\`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
  
  mariadb:
    image: "mariadb:10.5"
    container_name: "${CLIENT_ID}_mariadb"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: ${CLIENT_ID}_wordpress
      MYSQL_USER: ${CLIENT_ID}_wp
      MYSQL_PASSWORD: 5oOqapxbb98hQPov
    volumes:
      - ${WORDPRESS_DIR}/db_data:/var/lib/mysql
    networks:
      - wordpress_network

networks:
  traefik_network:
    external: true
    name: ${CLIENT_ID}_traefik_network
  wordpress_network:
    external: true
    name: ${CLIENT_ID}_wordpress_network
EOL

# 7. Host entries
log_info "Adding host entries"
if ! grep -q "${CLIENT_ID}.${DOMAIN}" /etc/hosts; then
  log_info "Adding ${CLIENT_ID}.${DOMAIN} to /etc/hosts"
  echo "127.0.0.1 ${CLIENT_ID}.${DOMAIN} traefik.${CLIENT_ID}.${DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
fi

# 8. WSL detection and Windows host access
if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  log_info "Detected WSL environment - configuring Windows host access"
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  
  cat > "${INSTALL_DIR}/windows_hosts.bat" << EOL
@echo off
:: PeaceFestivalUSA Windows Hosts File Setup
:: Following AgencyStack Charter v1.0.3 Principles

echo Adding host entries to Windows hosts file...
echo This requires Administrator privileges
echo.

:: Add host entries
echo 127.0.0.1 ${CLIENT_ID}.${DOMAIN} >> %windir%\\System32\\drivers\\etc\\hosts
echo 127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN} >> %windir%\\System32\\drivers\\etc\\hosts

echo.
echo Done! You can now access:
echo - WordPress: http://${CLIENT_ID}.${DOMAIN}
echo - Traefik Dashboard: http://traefik.${CLIENT_ID}.${DOMAIN}
echo.
pause
EOL

  cat > "${INSTALL_DIR}/windows_access.md" << EOL
# Windows Browser Access Guide

## Quick Setup

1. **Run the Windows Hosts File Helper**
   - Open Command Prompt as Administrator
   - Run \`windows_hosts.bat\` which can be found at:
     \`\\\\wsl\$\\Ubuntu\\opt\\agency_stack\\clients\\${CLIENT_ID}\\windows_hosts.bat\`

2. **Access in Browser**
   - WordPress: [http://${CLIENT_ID}.${DOMAIN}](http://${CLIENT_ID}.${DOMAIN})
   - Traefik Dashboard: [http://traefik.${CLIENT_ID}.${DOMAIN}](http://traefik.${CLIENT_ID}.${DOMAIN})

## Direct IP Access

If hostname resolution doesn't work:
- [http://${WINDOWS_HOST_IP}](http://${WINDOWS_HOST_IP})
EOL
fi

# 9. Start services
log_info "Starting services with best practices configuration"

log_info "Starting Traefik"
cd "${TRAEFIK_DIR}" && docker-compose up -d

log_info "Waiting for Traefik to initialize"
sleep 5

log_info "Starting WordPress"
cd "${WORDPRESS_DIR}" && docker-compose up -d

# 10. Test script
cat > "${INSTALL_DIR}/test_access.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Access Test
# Following AgencyStack Charter v1.0.3 Principles

CLIENT_ID=$(basename $(dirname "$0"))
DOMAIN="localhost"

echo "Testing access for ${CLIENT_ID}.${DOMAIN}..."

echo -n "Testing Traefik root access: "
curl -s -o /dev/null -w "%{http_code}" http://localhost
echo ""

echo -n "Testing WordPress with Host header: "
curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.${DOMAIN}" http://localhost
echo ""

if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  echo "Detected WSL environment"
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  
  echo -n "Testing Windows host direct access: "
  curl -s -o /dev/null -w "%{http_code}" http://${WINDOWS_HOST_IP}
  echo ""
  
  echo -n "Testing Windows host with WordPress header: "
  curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.${DOMAIN}" http://${WINDOWS_HOST_IP}
  echo ""
fi
EOL
chmod +x "${INSTALL_DIR}/test_access.sh"

# 11. Run quick test
log_info "Running quick access test"
sleep 10  # Allow services to fully initialize

if curl -s http://localhost | grep -q -i "wordpress"; then
  log_success "Local access is working!"
else
  log_warning "Local access not returning WordPress content yet"
fi

log_success "PeaceFestivalUSA deployment with Traefik best practices complete!"
log_info "Run test script for more details: ${INSTALL_DIR}/test_access.sh"
