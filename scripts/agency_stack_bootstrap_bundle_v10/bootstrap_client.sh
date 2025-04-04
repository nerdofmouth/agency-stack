#!/bin/bash
# AgencyStack Client Bootstrap Script
# https://stack.nerdofmouth.com

# Exit immediately if a command exits with a non-zero status.
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging setup
LOGDIR="/var/log/agency_stack"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/client-setup-$(date +%Y%m%d-%H%M%S).log"
touch "$LOGFILE"

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack] [$level] $message" | tee -a "$LOGFILE"
}

# Visual feedback
print_header() { echo -e "\n${MAGENTA}${BOLD}$1${NC}\n"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

### VARS ###
CLIENT_DOMAIN="$1"
if [ -z "$CLIENT_DOMAIN" ]; then
  print_error "Usage: $0 client.domain.com"
  log "ERROR" "No domain provided for client setup"
  exit 1
fi

CLIENT_NAME="${CLIENT_DOMAIN%%.*}" # e.g. peacefestival
CLIENT_DIR="clients/${CLIENT_DOMAIN}"
ENV_FILE="${CLIENT_DIR}/.env"
COMPOSE_FILE="${CLIENT_DIR}/docker-compose.yml"

# Display header
print_header "🏢 AgencyStack Client Setup: $CLIENT_DOMAIN"
log "INFO" "Starting client setup for $CLIENT_DOMAIN"

# Display random tagline
SCRIPT_PATH="$(dirname "$(realpath "$0")")"
AGENCY_BRANDING="$SCRIPT_PATH/../agency_branding.sh"
if [ -f "$AGENCY_BRANDING" ]; then
  source "$AGENCY_BRANDING" && random_tagline
  echo ""
fi

### DIR SETUP ###
print_info "Creating client directory structure"
mkdir -p "$CLIENT_DIR"
log "INFO" "Created directory $CLIENT_DIR"

### GENERATE .env ###
print_info "Generating .env for $CLIENT_DOMAIN"
cat > "$ENV_FILE" <<EOF
SITE_NAME=$CLIENT_DOMAIN
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
PEERTUBE_DOMAIN=media.${CLIENT_DOMAIN}
BUILDER_ENABLE=false
# The following will be populated by the builderio_provision.sh script if BUILDER_ENABLE=true
BUILDER_IO_SPACE_ID=
BUILDER_IO_API_KEY=
EOF

### GENERATE docker-compose.yml ###
print_info "Generating docker-compose.yml for $CLIENT_DOMAIN"
cat > "$COMPOSE_FILE" <<EOF
version: "3.7"
services:
  erpnext:
    image: frappe/erpnext:version-14
    container_name: erp_${CLIENT_DOMAIN}
    environment:
      - SITE_NAME=${CLIENT_DOMAIN}
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.rule=Host(\`${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.middlewares=offline-fallback@file"
    volumes:
      - ${CLIENT_DIR}/erpnext_data:/var/lib/mysql
    networks:
      - traefik

  peertube:
    image: chocobozzz/peertube:production-bookworm
    container_name: peertube_${CLIENT_DOMAIN}
    environment:
      - PEERTUBE_WEBSERVER_HOSTNAME=media.${CLIENT_DOMAIN}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.rule=Host(\`media.${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.middlewares=offline-fallback@file"
    volumes:
      - ${CLIENT_DIR}/peertube_data:/data
    networks:
      - traefik

  # Offline fallback static files server (used by Traefik for error pages)
  static:
    image: nginx:alpine
    container_name: static_${CLIENT_DOMAIN}
    volumes:
      - ${CLIENT_DIR}/static:/usr/share/nginx/html:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.rule=Host(\`static.${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.services.static_${CLIENT_DOMAIN}.loadbalancer.server.port=80"
    networks:
      - traefik

networks:
  traefik:
    external: true
EOF

### CREATE DIRECTORIES FOR VOLUMES ###
print_info "Creating directories for volumes"
mkdir -p "${CLIENT_DIR}/erpnext_data"
mkdir -p "${CLIENT_DIR}/peertube_data"
mkdir -p "${CLIENT_DIR}/static"
log "INFO" "Created directories for volumes"

# Create basic offline fallback page
print_info "Creating basic offline fallback page"
cat > "${CLIENT_DIR}/static/offline.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Temporarily Offline - $CLIENT_NAME</title>
  <style>
    body {
      font-family: sans-serif;
      text-align: center;
      padding: 50px;
    }
    h1 { color: #333; }
  </style>
</head>
<body>
  <h1>We'll be right back</h1>
  <p>Our services are temporarily unavailable. Please check back shortly.</p>
  <p><strong>$CLIENT_NAME</strong></p>
</body>
</html>
EOF
log "INFO" "Created basic offline fallback page"

### PROVISION Builder.io space (optional) ###
print_info "Checking for Builder.io integration..."

# Source the .env file to get the BUILDER_ENABLE variable
source "$ENV_FILE"

if [ "$BUILDER_ENABLE" = "true" ]; then
  print_info "Provisioning Builder.io space for ${CLIENT_NAME}..."
  
  # Get the absolute path to the builderio_provision.sh script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
  BUILDERIO_SCRIPT="$REPO_ROOT/scripts/builderio_provision.sh"
  
  # Check if the script exists
  if [ -f "$BUILDERIO_SCRIPT" ]; then
    # Check if BUILDER_API_KEY is set in the environment
    if [ -z "$BUILDER_API_KEY" ]; then
      print_error "BUILDER_API_KEY environment variable is not set."
      log "ERROR" "BUILDER_API_KEY environment variable is not set."
      print_info "Please set it with: export BUILDER_API_KEY=\"your_api_key\""
      print_info "Builder.io integration will be skipped."
    else
      bash "$BUILDERIO_SCRIPT" "$CLIENT_NAME" "$CLIENT_DOMAIN"
      
      # Create Traefik configuration for the Builder.io offline fallback
      # (This step is now handled by the builderio_provision.sh script)
    fi
  else
    print_error "Builder.io provisioning script not found at: $BUILDERIO_SCRIPT"
    log "ERROR" "Builder.io provisioning script not found at: $BUILDERIO_SCRIPT"
    print_info "Please ensure the script exists or update this script with the correct path."
  fi
fi

### DONE ###
print_success "Client ${CLIENT_DOMAIN} bootstrapped."
log "INFO" "Client ${CLIENT_DOMAIN} bootstrapped."

# Show motto after successful bootstrap
if [ -f "$AGENCY_BRANDING" ]; then
  source "$AGENCY_BRANDING" && random_tagline
  echo ""
fi

print_info "Next step: cd ${CLIENT_DIR} && docker compose up -d"
print_info ""
print_info "Available services after startup:"
print_info "  • ERPNext:  https://${CLIENT_DOMAIN}"
print_info "  • PeerTube: https://media.${CLIENT_DOMAIN}"
if [ "$BUILDER_ENABLE" = "true" ]; then
  print_info "  • Builder.io integration is enabled - check your Builder.io dashboard"
fi
