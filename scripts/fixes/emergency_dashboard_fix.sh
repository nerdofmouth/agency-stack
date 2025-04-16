#!/bin/bash
# emergency_dashboard_fix.sh - Emergency fix for FQDN access to dashboard
#
# This script implements critical fixes to ensure Dashboard is accessible
# via FQDN for demo purposes, addressing browser compatibility issues.
#
# Author: AgencyStack Team
# Date: 2025-04-10

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Log function
log() {
  echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[✗]${NC} $1" >&2
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --domain DOMAIN       Domain to use (default: proto001.alpha.nerdofmouth.com)"
      echo "  --client-id ID        Client ID (default: default)"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log "EMERGENCY FIX: Dashboard FQDN Access"
log "Domain: ${DOMAIN}"
log "Client ID: ${CLIENT_ID}"
log "Server IP: ${SERVER_IP}"

# Paths
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
DASHBOARD_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
TRAEFIK_CONFIG="${TRAEFIK_DIR}/config/traefik.yml"
DYNAMIC_DIR="${TRAEFIK_DIR}/config/dynamic"
DASHBOARD_ROUTE="${DYNAMIC_DIR}/dashboard-route.yml"

# Check if directories exist
if [ ! -d "${TRAEFIK_DIR}" ]; then
  error "Traefik directory not found at ${TRAEFIK_DIR}"
  exit 1
fi

if [ ! -d "${DASHBOARD_DIR}" ]; then
  error "Dashboard directory not found at ${DASHBOARD_DIR}"
  exit 1
fi

# 1. UPDATE HOSTS FILE
log "Checking hosts file configuration..."
if grep -q "${DOMAIN}" /etc/hosts; then
  HOSTS_IP=$(grep "${DOMAIN}" /etc/hosts | awk '{print $1}')
  if [ "${HOSTS_IP}" != "${SERVER_IP}" ]; then
    warn "Hosts file has incorrect IP for ${DOMAIN}: ${HOSTS_IP} (should be ${SERVER_IP})"
    log "Updating hosts file entry..."
    sed -i "s/^.*${DOMAIN}.*/${SERVER_IP} ${DOMAIN} ${DOMAIN%%.*}/" /etc/hosts
    success "Updated hosts file entry to point to ${SERVER_IP}"
  else
    success "Hosts file correctly configured: ${DOMAIN} → ${SERVER_IP}"
  fi
else
  warn "No entry for ${DOMAIN} in hosts file"
  log "Adding hosts file entry..."
  echo "${SERVER_IP} ${DOMAIN} ${DOMAIN%%.*}" >> /etc/hosts
  success "Added hosts file entry: ${DOMAIN} → ${SERVER_IP}"
fi

# 2. DISABLE HTTPS REDIRECTION COMPLETELY
log "Disabling HTTPS redirection in Traefik..."
TRAEFIK_BACKUP="${TRAEFIK_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
cp "${TRAEFIK_CONFIG}" "${TRAEFIK_BACKUP}"
success "Backed up Traefik config to ${TRAEFIK_BACKUP}"

# Remove all redirections configuration from traefik.yml
sed -i '/redirections/d' "${TRAEFIK_CONFIG}" 
sed -i '/entryPoint/d' "${TRAEFIK_CONFIG}"
sed -i '/scheme/d' "${TRAEFIK_CONFIG}"
sed -i '/to:/d' "${TRAEFIK_CONFIG}"
success "Removed HTTP-to-HTTPS redirection"

# 3. CREATE OPTIMIZED DASHBOARD ROUTE
log "Creating optimized dashboard route configuration..."
DASHBOARD_BACKUP="${DASHBOARD_ROUTE}.bak.$(date +%Y%m%d%H%M%S)"
cp "${DASHBOARD_ROUTE}" "${DASHBOARD_BACKUP}"
success "Backed up dashboard route to ${DASHBOARD_BACKUP}"

# Create new dashboard route that works on domain directly and with /dashboard path
cat > "${DASHBOARD_ROUTE}" <<EOF
http:
  routers:
    # Root path HTTP router (for domain homepage)
    dashboard-root:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      priority: 100
    
    # Dashboard path HTTP router 
    dashboard-path:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      priority: 200
    
    # Secure routes (fallback)
    dashboard-root-secure:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      priority: 100
      tls: {}
      
    dashboard-path-secure:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      priority: 200
      tls: {}

  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_default:80"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
EOF
success "Created optimized dashboard route configuration"

# 4. CREATE A DIRECT ROUTE FILE
log "Creating direct IP route configuration..."
DIRECT_ROUTE="${DYNAMIC_DIR}/direct-ip-route.yml"

cat > "${DIRECT_ROUTE}" <<EOF
http:
  routers:
    # Direct IP router
    ip-router:
      rule: "HostRegexp(\`{ip:${SERVER_IP}}\`) || HostRegexp(\`{ip:192\\.64\\.72\\.162}\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      priority: 300
      
  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_default:80"
EOF
success "Created direct IP route configuration"

# 5. ADD WILDCARD ROUTE
log "Creating wildcard route for all subdomains..."
WILDCARD_ROUTE="${DYNAMIC_DIR}/wildcard-route.yml"

cat > "${WILDCARD_ROUTE}" <<EOF
http:
  routers:
    # Wildcard router for all subdomains
    wildcard-router:
      rule: "HostRegexp(\`{subdomain:[a-z0-9-]+}.${DOMAIN}\`) || HostRegexp(\`{subdomain:[a-z0-9-]+}.alpha.nerdofmouth.com\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      priority: 50
      
  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_default:80"
EOF
success "Created wildcard route configuration"

# 6. ADD CORS HEADERS
log "Creating CORS headers middleware..."
CORS_CONFIG="${DYNAMIC_DIR}/cors-headers.yml"

cat > "${CORS_CONFIG}" <<EOF
http:
  middlewares:
    cors-headers:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
          - POST
          - DELETE
        accessControlAllowOriginList:
          - "http://${DOMAIN}"
          - "https://${DOMAIN}"
          - "http://*.${DOMAIN}"
          - "https://*.${DOMAIN}"
          - "http://192.64.72.162"
          - "https://192.64.72.162"
        accessControlAllowHeaders:
          - "*"
        accessControlMaxAge: 100
        addVaryHeader: true
        
    security-headers:
      headers:
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        referrerPolicy: "no-referrer-when-downgrade"
        contentTypeNosniff: true
        browserXssFilter: true
        forceSTSHeader: false
EOF
success "Created CORS headers middleware"

# 7. APPLY CORS TO ALL ROUTES
log "Adding CORS middleware to all routes..."
sed -i 's/dashboard-strip"/dashboard-strip", "cors-headers", "security-headers"/g' "${DASHBOARD_ROUTE}"
success "Added CORS headers to dashboard routes"

# 8. RESTART TRAEFIK TO APPLY CHANGES
log "Restarting Traefik to apply all changes..."
cd "${TRAEFIK_DIR}" && docker-compose down && docker-compose up -d
success "Traefik restarted successfully"

# 9. TEST ACCESS
log "Testing access to dashboard..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}/dashboard")
log "HTTP status for http://${DOMAIN}/dashboard: ${HTTP_STATUS}"

HTTP_ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}")
log "HTTP status for http://${DOMAIN}: ${HTTP_ROOT_STATUS}"

HTTP_IP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}")
log "HTTP status for http://${SERVER_IP}: ${HTTP_IP_STATUS}"

log "-----------------------------------------------------"
log "DASHBOARD ACCESS URLS:"
echo "1. HTTP FQDN (Root):    http://${DOMAIN}"
echo "2. HTTP FQDN (Path):    http://${DOMAIN}/dashboard"
echo "3. Direct IP:           http://${SERVER_IP}:3001"
log "-----------------------------------------------------"

log "EMERGENCY FIX COMPLETE!"
log "The dashboard should now be accessible via any of the above URLs."
log "For production deployments, ensure proper DNS is configured."

exit 0
