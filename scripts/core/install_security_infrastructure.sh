#!/bin/bash
# install_security_infrastructure.sh - Security infrastructure setup for AgencyStack
# https://stack.nerdofmouth.com
#
# This script installs and configures core security components:
# - Traefik reverse proxy with SSL/TLS
# - Fail2ban for intrusion prevention
# - Security headers and middleware
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
INSTALL_LOG="${LOG_DIR}/security_install.log"
TRAEFIK_DIR="${CONFIG_DIR}/traefik"
TRAEFIK_DATA="${TRAEFIK_DIR}/data"
TRAEFIK_CONF="${TRAEFIK_DIR}/conf"
FAIL2BAN_DIR="${CONFIG_DIR}/fail2ban"
VERBOSE=false
DOMAIN=""
EMAIL=""

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Security Infrastructure Setup${NC}"
  echo -e "============================================="
  echo -e "This script installs and configures core security infrastructure:"
  echo -e "  - Traefik reverse proxy with SSL/TLS"
  echo -e "  - Fail2ban for intrusion prevention"
  echo -e "  - Security headers and middleware"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>   Primary domain for SSL certificates (required)"
  echo -e "  ${BOLD}--email${NC} <email>     Email for Let's Encrypt notifications (required)"
  echo -e "  ${BOLD}--verbose${NC}           Show detailed output during installation"
  echo -e "  ${BOLD}--skip-traefik${NC}      Skip Traefik installation"
  echo -e "  ${BOLD}--skip-fail2ban${NC}     Skip Fail2ban installation"
  echo -e "  ${BOLD}--help${NC}              Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain example.com --email admin@example.com --verbose"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  exit 0
}

# Parse arguments
SKIP_TRAEFIK=false
SKIP_FAIL2BAN=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --email)
      EMAIL="$2"
      shift
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --skip-traefik)
      SKIP_TRAEFIK=true
      shift
      ;;
    --skip-fail2ban)
      SKIP_FAIL2BAN=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ] && [ "$SKIP_TRAEFIK" = false ]; then
  echo -e "${RED}Error: --domain is required for Traefik installation${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$EMAIL" ] && [ "$SKIP_TRAEFIK" = false ]; then
  echo -e "${RED}Error: --email is required for Let's Encrypt${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Security Infrastructure Setup${NC}"
echo -e "============================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

log "INFO: Starting AgencyStack security infrastructure installation" "${BLUE}Starting security infrastructure installation...${NC}"

#######################
# TRAEFIK INSTALLATION
#######################

if [ "$SKIP_TRAEFIK" = false ]; then
  log "INFO: Installing Traefik with SSL" "${BLUE}Installing Traefik with SSL...${NC}"
  
  # Create Traefik directories
  log "INFO: Creating Traefik directories" "${CYAN}Creating Traefik directories...${NC}"
  mkdir -p "${TRAEFIK_DATA}"
  mkdir -p "${TRAEFIK_CONF}"
  mkdir -p "${TRAEFIK_DIR}/logs"
  
  # Touch required files
  touch "${TRAEFIK_DATA}/acme.json"
  chmod 600 "${TRAEFIK_DATA}/acme.json"
  
  # Create traefik.yml configuration
  log "INFO: Creating Traefik configuration" "${CYAN}Creating Traefik configuration...${NC}"
  cat > "${TRAEFIK_CONF}/traefik.yml" <<EOF
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: myresolver
      middlewares:
        - secure-headers@file

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/conf"
    watch: true

certificatesResolvers:
  myresolver:
    acme:
      email: ${EMAIL}
      storage: "/etc/traefik/data/acme.json"
      httpChallenge:
        entryPoint: web

accessLog:
  filePath: "/etc/traefik/logs/access.log"
  format: common
  bufferingSize: 100

log:
  filePath: "/etc/traefik/logs/traefik.log"
  level: "INFO"
EOF
  
  # Create dynamic configuration for middleware
  log "INFO: Creating Traefik middleware configuration" "${CYAN}Creating Traefik middleware configuration...${NC}"
  cat > "${TRAEFIK_CONF}/middleware.yml" <<EOF
http:
  middlewares:
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        contentTypeNosniff: true
        browserXssFilter: true
        customFrameOptionsValue: "SAMEORIGIN"
        contentSecurityPolicy: "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; connect-src 'self' https:; font-src 'self' data: https:; object-src 'none'; media-src 'self' https:; frame-src 'self' https:;"
        referrerPolicy: "strict-origin-when-cross-origin"
        permissionsPolicy: "geolocation=(), camera=(), microphone=()"
    
    # Middleware for authentication with Keycloak
    keycloak-auth:
      forwardAuth:
        address: "http://keycloak:8080/auth/realms/master/protocol/openid-connect/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-Auth-User"
          - "X-Auth-Email"
          - "X-Auth-Roles"
    
    # Middleware for rate limiting
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m
    
    # Middleware for retries on failure
    retry-middleware:
      retry:
        attempts: 3
        initialInterval: 100ms
    
    # Middleware for serving custom error pages
    offline-fallback:
      errors:
        status: ["500-599"]
        service: "static"
        query: "/{status}.html"
EOF
  
  # Create Docker Compose file for Traefik
  log "INFO: Creating Traefik Docker Compose file" "${CYAN}Creating Traefik Docker Compose file...${NC}"
  cat > "${TRAEFIK_DIR}/docker-compose.yml" <<EOF
version: "3.7"

services:
  traefik:
    image: traefik:v2.9
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TRAEFIK_CONF}/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${TRAEFIK_CONF}/:/etc/traefik/conf:ro
      - ${TRAEFIK_DATA}/:/etc/traefik/data
      - ${TRAEFIK_DIR}/logs:/etc/traefik/logs
    environment:
      - TZ=UTC
    labels:
      - "traefik.enable=true"
      # Dashboard
      - "traefik.http.routers.traefik.rule=Host(\`traefik.${DOMAIN}\`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=secure-headers@file,traefik-auth"
      # Dashboard Auth
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$apr1$$YpdO1S9g$$YHZmVQgLLX.8PU9qPWpvU0"
    networks:
      - agency-network

networks:
  agency-network:
    external: true
EOF
  
  # Start Traefik
  log "INFO: Starting Traefik" "${CYAN}Starting Traefik...${NC}"
  cd "${TRAEFIK_DIR}" && docker-compose up -d
  
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to start Traefik" "${RED}Failed to start Traefik. See log for details.${NC}"
    exit 1
  fi
  
  log "INFO: Traefik installed and started" "${GREEN}✅ Traefik installed and started successfully${NC}"
  log "INFO: Traefik dashboard available at https://traefik.${DOMAIN}" "${CYAN}Traefik dashboard available at: https://traefik.${DOMAIN}${NC}"
  log "INFO: Default credentials: admin / admin" "${YELLOW}Default credentials: admin / admin${NC}"
  log "INFO: Please change these credentials for production use" "${YELLOW}Please change these credentials for production use${NC}"
fi

#######################
# FAIL2BAN INSTALLATION
#######################

if [ "$SKIP_FAIL2BAN" = false ]; then
  log "INFO: Installing Fail2ban" "${BLUE}Installing Fail2ban...${NC}"
  
  # Install Fail2ban
  log "INFO: Installing Fail2ban package" "${CYAN}Installing Fail2ban package...${NC}"
  apt-get update >> "$INSTALL_LOG" 2>&1
  apt-get install -y fail2ban >> "$INSTALL_LOG" 2>&1
  
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to install Fail2ban" "${RED}Failed to install Fail2ban. See log for details.${NC}"
    exit 1
  fi
  
  # Create Fail2ban directory
  mkdir -p "${FAIL2BAN_DIR}/filter.d"
  mkdir -p "${FAIL2BAN_DIR}/jail.d"
  
  # Create custom jail configuration
  log "INFO: Creating Fail2ban configuration" "${CYAN}Creating Fail2ban configuration...${NC}"
  cat > "${FAIL2BAN_DIR}/jail.d/agency-stack.conf" <<EOF
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600
# A host is banned if it has 5 failed login attempts within 10 minutes
findtime = 600
maxretry = 5

# SSH
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

# Traefik
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = ${TRAEFIK_DIR}/logs/access.log
maxretry = 5

# AgencyStack Services
[agency-stack]
enabled = true
port = http,https
filter = agency-stack
logpath = /var/log/agency_stack/*.log
maxretry = 5
EOF
  
  # Create custom filter for Traefik
  log "INFO: Creating Traefik Fail2ban filter" "${CYAN}Creating Traefik Fail2ban filter...${NC}"
  cat > "${FAIL2BAN_DIR}/filter.d/traefik-auth.conf" <<EOF
[Definition]
failregex = ^.*\"(GET|POST|HEAD).*\" 401 .*$
            ^.*\"(GET|POST|HEAD).*\" 403 .*$
ignoreregex =
EOF
  
  # Create custom filter for AgencyStack services
  log "INFO: Creating AgencyStack Fail2ban filter" "${CYAN}Creating AgencyStack Fail2ban filter...${NC}"
  cat > "${FAIL2BAN_DIR}/filter.d/agency-stack.conf" <<EOF
[Definition]
failregex = ^.*authentication failure.*$
            ^.*login failed.*$
            ^.*unauthorized access.*$
            ^.*invalid credentials.*$
ignoreregex =
EOF
  
  # Copy configurations to system
  cp "${FAIL2BAN_DIR}/jail.d/agency-stack.conf" /etc/fail2ban/jail.d/
  cp "${FAIL2BAN_DIR}/filter.d/traefik-auth.conf" /etc/fail2ban/filter.d/
  cp "${FAIL2BAN_DIR}/filter.d/agency-stack.conf" /etc/fail2ban/filter.d/
  
  # Restart Fail2ban
  log "INFO: Restarting Fail2ban" "${CYAN}Restarting Fail2ban...${NC}"
  systemctl restart fail2ban
  
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to restart Fail2ban" "${RED}Failed to restart Fail2ban. See log for details.${NC}"
    exit 1
  fi
  
  # Enable Fail2ban
  log "INFO: Enabling Fail2ban" "${CYAN}Enabling Fail2ban...${NC}"
  systemctl enable fail2ban
  
  log "INFO: Fail2ban installed and configured" "${GREEN}✅ Fail2ban installed and configured successfully${NC}"
  log "INFO: Checking Fail2ban status" "${CYAN}Checking Fail2ban status...${NC}"
  
  # Show Fail2ban status
  fail2ban-client status >> "$INSTALL_LOG" 2>&1
  if [ "$VERBOSE" = true ]; then
    fail2ban-client status
  fi
fi

# Final message
log "INFO: Security infrastructure installation completed successfully" "${GREEN}${BOLD}✅ AgencyStack security infrastructure installation completed successfully!${NC}"
echo -e "${CYAN}You should set up authentication for Traefik dashboard by modifying the basicauth in the docker-compose.yml${NC}"
echo -e "${CYAN}The system is now protected with Fail2ban and Traefik with SSL/TLS${NC}"

exit 0
