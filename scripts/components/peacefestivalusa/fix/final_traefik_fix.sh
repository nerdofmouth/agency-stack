#!/bin/bash

# PeaceFestivalUSA Final Traefik Fix
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Component Consistency
# - Strict Containerization
# - WSL2/Docker Mount Safety

set -e

# Script location 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ID="peacefestivalusa"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_DIR}/traefik"
WORDPRESS_DIR="${INSTALL_DIR}/wordpress"

# Simple logging functions
log_info() { echo -e "[INFO] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

log_info "Starting final Traefik fix for ${CLIENT_ID}"

# Check if WSL environment
if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  log_info "Detected WSL environment"
  WSL_ENV=true
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  log_info "Windows Host IP: ${WINDOWS_HOST_IP}"
else
  log_info "Not running in WSL"
  WSL_ENV=false
  WINDOWS_HOST_IP="127.0.0.1"
fi

# 1. Make sure docker network exists
if ! docker network ls | grep -q "${CLIENT_ID}_traefik_network"; then
  log_info "Creating traefik network"
  docker network create ${CLIENT_ID}_traefik_network
else
  log_info "Traefik network already exists"
fi

# 2. Create appropriate Traefik static configuration
log_info "Creating Traefik static configuration"
mkdir -p "${TRAEFIK_DIR}/config/dynamic"
mkdir -p "${TRAEFIK_DIR}/logs"

cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 Principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

# API and Dashboard (insecure for development only)
api:
  dashboard: true
  insecure: true

# Entry points configuration
entryPoints:
  web:
    address: ":80"

providers:
  # Docker provider configuration
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${CLIENT_ID}_traefik_network"
    
  # File provider for dynamic configuration
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Debug logging for development
log:
  level: "DEBUG"
  filePath: "/var/log/traefik/traefik.log"

accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# 3. Create Traefik dynamic configuration
log_info "Creating Traefik dynamic configuration"

# Dashboard security configuration
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

# Default route for root domain
cat > "${TRAEFIK_DIR}/config/dynamic/default.yml" << EOL
# Default routing configuration
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

# WordPress configuration
cat > "${TRAEFIK_DIR}/config/dynamic/wordpress.yml" << EOL
# WordPress routing configuration
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

# 4. Create docker-compose.yml for Traefik
log_info "Creating Traefik docker-compose.yml"
cat > "${TRAEFIK_DIR}/docker-compose.yml" << EOL
services:
  traefik:
    container_name: ${CLIENT_ID}_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro
      - ${TRAEFIK_DIR}/logs:/var/log/traefik
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(\`traefik.${CLIENT_ID}.localhost\`)"
      - "traefik.http.routers.api.service=api@internal"
      - "traefik.http.services.api.loadbalancer.server.port=8080"

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
EOL

# 5. Update WordPress docker-compose.yml
log_info "Updating WordPress docker-compose.yml"
cat > "${WORDPRESS_DIR}/docker-compose.yml" << EOL
services:
  wordpress:
    container_name: ${CLIENT_ID}_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
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
      - default
    depends_on:
      - mariadb
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(\`${CLIENT_ID}.localhost\`) || Host(\`localhost\`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
  
  mariadb:
    container_name: ${CLIENT_ID}_mariadb
    image: mariadb:10.5
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: ${CLIENT_ID}_wordpress
      MYSQL_USER: ${CLIENT_ID}_wp
      MYSQL_PASSWORD: 5oOqapxbb98hQPov
    volumes:
      - ${WORDPRESS_DIR}/db_data:/var/lib/mysql
    networks:
      - default

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
  default:
    name: ${CLIENT_ID}_wordpress_network
EOL

# 6. Add necessary host entries
log_info "Adding host entries"
if ! grep -q "${CLIENT_ID}.localhost" /etc/hosts; then
  log_info "Adding ${CLIENT_ID}.localhost to /etc/hosts"
  echo "127.0.0.1 ${CLIENT_ID}.localhost traefik.${CLIENT_ID}.localhost" | sudo tee -a /etc/hosts > /dev/null
fi

# 7. Create Windows hosts file helper for WSL environments
if [ "$WSL_ENV" = true ]; then
  log_info "Creating Windows hosts file helper"
  cat > "${INSTALL_DIR}/add_windows_hosts.bat" << EOL
@echo off
:: PeaceFestivalUSA Windows Hosts File Setup
:: Following AgencyStack Charter v1.0.3 Principles

echo Adding host entries to Windows hosts file...
echo This requires Administrator privileges
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

:: Add host entries
echo 127.0.0.1 ${CLIENT_ID}.localhost >> %windir%\System32\drivers\etc\hosts
echo 127.0.0.1 traefik.${CLIENT_ID}.localhost >> %windir%\System32\drivers\etc\hosts

echo.
echo Done! You can now access:
echo   - WordPress: http://${CLIENT_ID}.localhost
echo   - Traefik Dashboard: http://traefik.${CLIENT_ID}.localhost
echo.
pause
EOL
fi

# 8. Stop and remove existing containers
log_info "Stopping existing containers"
docker stop ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true
docker rm ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true

# 9. Start Traefik
log_info "Starting Traefik"
cd "${TRAEFIK_DIR}" && docker-compose up -d

# Wait for Traefik to be ready
log_info "Waiting for Traefik to start..."
sleep 5

# 10. Handle WordPress network
log_info "Handling WordPress network"
if docker network ls | grep -q "${CLIENT_ID}_wordpress_network"; then
  log_info "Removing existing WordPress network"
  docker network rm ${CLIENT_ID}_wordpress_network || true
fi
log_info "Creating WordPress network"
docker network create ${CLIENT_ID}_wordpress_network

# 11. Start WordPress
log_info "Starting WordPress"
cd "${WORDPRESS_DIR}" && docker-compose up -d

# 12. Create a verification guide
log_info "Creating verification guide"
cat > "${INSTALL_DIR}/verify_access.md" << EOL
# PeaceFestivalUSA Deployment Verification Guide
# Following AgencyStack Charter v1.0.3 Principles

## Access Points

### From WSL/Linux:
- WordPress: http://localhost or http://${CLIENT_ID}.localhost
- Traefik Dashboard: http://traefik.${CLIENT_ID}.localhost (login: admin/admin123)

### From Windows:
- WordPress: http://${CLIENT_ID}.localhost
- Traefik Dashboard: http://traefik.${CLIENT_ID}.localhost (login: admin/admin123)

## Verification Tests

Run the following command to verify access:
\`\`\`
/root/_repos/agency-stack/scripts/components/peacefestivalusa/test/verify_windows_access.sh
\`\`\`

## Troubleshooting

1. If Windows browser access doesn't work:
   - Run the Windows hosts file helper at: ${INSTALL_DIR}/add_windows_hosts.bat
   - Try accessing via IP: http://${WINDOWS_HOST_IP}

2. If container networking issues occur:
   - Check container status: \`docker ps -a\`
   - View Traefik logs: \`docker logs ${CLIENT_ID}_traefik\`
   - Restart containers: \`cd ${INSTALL_DIR} && ./fix/final_traefik_fix.sh\`

3. For WSL-specific issues:
   - Check WSL integration: \`cat /proc/version\`
   - Verify Windows Host IP: \`cat /etc/resolv.conf | grep nameserver\`
   - Restart WSL: \`wsl --shutdown\` (from Windows PowerShell)
EOL

# 13. Create a brief test script
cat > "${INSTALL_DIR}/test_access.sh" << 'EOL'
#!/bin/bash
# PeaceFestivalUSA Quick Access Test

echo "Testing local access..."
curl -v http://localhost 2>&1 | grep -i "wordpress"
echo ""

echo "Testing with host header..."
curl -v -H "Host: peacefestivalusa.localhost" http://localhost 2>&1 | grep -i "wordpress"
echo ""

if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  WSL_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  echo "Testing Windows host IP access ($WSL_HOST_IP)..."
  curl -v http://$WSL_HOST_IP 2>&1 | grep -i "wordpress"
fi
EOL
chmod +x "${INSTALL_DIR}/test_access.sh"

# 14. Test the setup
log_info "Testing the setup..."
sleep 10  # Give services a moment to fully initialize

# Test local access
if curl -s http://localhost | grep -q -i "wordpress"; then
  log_success "Local access is working!"
else
  log_warning "Local access may not be working, check logs"
fi

# Test with host header
if curl -s -H "Host: ${CLIENT_ID}.localhost" http://localhost | grep -q -i "wordpress"; then
  log_success "Host header routing is working!"
else
  log_warning "Host header routing may not be working, check logs"
fi

log_info "Final Traefik fix completed"
log_info "To verify, run: ${INSTALL_DIR}/test_access.sh"
log_info "For Windows browser access, follow instructions in: ${INSTALL_DIR}/verify_access.md"
