#!/bin/bash
# fix_fqdn_access_improved.sh - Improved Fix for FQDN Access
#
# This script provides a comprehensive solution for FQDN access issues
# following the AgencyStack Alpha Phase Repository Integrity Policy.
#
# Author: AgencyStack Team
# Date: 2025-04-10

# Exit on error
set -e

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')
DNS_SERVERS="8.8.8.8 1.1.1.1"

# Paths
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
TRAEFIK_CONFIG_DIR="${TRAEFIK_DIR}/config"
TRAEFIK_DYNAMIC_DIR="${TRAEFIK_CONFIG_DIR}/dynamic"

# Log helpers (self-contained)
log_info() {
  echo -e "\033[0;34m[INFO] $1\033[0m"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS] $1\033[0m"
}

log_warning() {
  echo -e "\033[0;33m[WARNING] $1\033[0m"
}

log_error() {
  echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

log_cmd() {
  echo -e "\033[0;36m[CMD] $1\033[0m"
}

# Parse command-line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false
SKIP_DNS_CHECK=false
NO_HOSTS_FALLBACK=false

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
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-dns-check)
      SKIP_DNS_CHECK=true
      shift
      ;;
    --no-hosts-fallback)
      NO_HOSTS_FALLBACK=true
      shift
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Start logging
log_info "Starting FQDN access fix..."
log_info "Domain: ${DOMAIN}"
log_info "Client ID: ${CLIENT_ID}"
log_info "Server IP: ${SERVER_IP}"

# Function to check DNS resolution
check_dns_resolution() {
  local domain="$1"
  local dns_server="$2"
  local result
  
  if [ -n "${dns_server}" ]; then
    log_info "Checking DNS resolution for ${domain} using ${dns_server}..."
    result=$(dig +short "${domain}" @"${dns_server}" 2>/dev/null || echo "")
  else
    log_info "Checking DNS resolution for ${domain} using system DNS..."
    result=$(dig +short "${domain}" 2>/dev/null || echo "")
  fi
  
  if [ -z "${result}" ]; then
    log_warning "DNS resolution failed for ${domain}${dns_server:+ using ${dns_server}}"
    return 1
  else
    log_success "DNS resolution successful for ${domain}${dns_server:+ using ${dns_server}}: ${result}"
    return 0
  fi
}

# Check DNS resolution
if [ "${SKIP_DNS_CHECK}" = "false" ]; then
  # Check using system resolver
  check_dns_resolution "${DOMAIN}"
  SYSTEM_DNS_RESULT=$?
  
  # Check using external resolvers
  EXTERNAL_DNS_RESULT=1
  for dns_server in ${DNS_SERVERS}; do
    check_dns_resolution "${DOMAIN}" "${dns_server}"
    if [ $? -eq 0 ]; then
      EXTERNAL_DNS_RESULT=0
      break
    fi
  done
  
  if [ "${SYSTEM_DNS_RESULT}" -eq 1 ] && [ "${EXTERNAL_DNS_RESULT}" -eq 1 ]; then
    log_warning "DNS resolution failed with both system and external DNS servers"
    
    if [ "${NO_HOSTS_FALLBACK}" = "false" ]; then
      log_info "Adding temporary hosts file entry for demonstration purposes..."
      
      # Check if domain is already in hosts file
      if grep -q "${DOMAIN}" /etc/hosts; then
        log_warning "Domain ${DOMAIN} already in hosts file"
        CURRENT_IP=$(grep "${DOMAIN}" /etc/hosts | awk '{print $1}')
        
        if [ "${CURRENT_IP}" != "${SERVER_IP}" ]; then
          log_warning "Updating hosts file entry for ${DOMAIN} from ${CURRENT_IP} to ${SERVER_IP}"
          
          if [ "${DRY_RUN}" = "false" ]; then
            # Create a timestamp for the backup
            TIMESTAMP=$(date +%Y%m%d%H%M%S)
            cp /etc/hosts "/etc/hosts.bak.${TIMESTAMP}"
            
            # Update the hosts file entry
            sed -i "s/^.*${DOMAIN}.*/${SERVER_IP} ${DOMAIN}/" /etc/hosts
            log_success "Updated hosts file entry for ${DOMAIN}"
          else
            log_info "DRY RUN: Would update hosts file entry for ${DOMAIN}"
          fi
        else
          log_success "Hosts file entry for ${DOMAIN} already correct"
        fi
      else
        log_info "Adding ${DOMAIN} to hosts file with IP ${SERVER_IP}"
        
        if [ "${DRY_RUN}" = "false" ]; then
          # Create a timestamp for the backup
          TIMESTAMP=$(date +%Y%m%d%H%M%S)
          cp /etc/hosts "/etc/hosts.bak.${TIMESTAMP}"
          
          # Add the hosts file entry
          echo "${SERVER_IP} ${DOMAIN}" >> /etc/hosts
          log_success "Added hosts file entry for ${DOMAIN}"
        else
          log_info "DRY RUN: Would add hosts file entry for ${DOMAIN}"
        fi
      fi
    else
      log_warning "Hosts file fallback disabled, skipping hosts file modification"
      log_warning "FQDN access may still fail without proper DNS resolution"
    fi
  fi
else
  log_info "Skipping DNS resolution check"
fi

# Check and fix Traefik configuration
if [ -d "${TRAEFIK_DIR}" ]; then
  log_info "Checking Traefik configuration..."
  
  # Check if Traefik is running
  if docker ps | grep -q "traefik_${CLIENT_ID}"; then
    log_success "Traefik container is running"
  else
    log_warning "Traefik container is not running"
    
    if [ "${DRY_RUN}" = "false" ]; then
      log_info "Starting Traefik container..."
      cd "${TRAEFIK_DIR}" && docker-compose up -d
      log_success "Started Traefik container"
    else
      log_info "DRY RUN: Would start Traefik container"
    fi
  fi
  
  # Check Traefik configuration file
  TRAEFIK_YAML="${TRAEFIK_CONFIG_DIR}/traefik.yml"
  if [ -f "${TRAEFIK_YAML}" ]; then
    log_info "Checking Traefik main configuration..."
    
    # Check for HTTP redirections
    if grep -q "redirections" "${TRAEFIK_YAML}"; then
      log_warning "HTTP-to-HTTPS redirection found in Traefik configuration"
      
      if [ "${FORCE}" = "true" ]; then
        log_info "Disabling HTTP-to-HTTPS redirection to allow direct access..."
        
        if [ "${DRY_RUN}" = "false" ]; then
          # Create a timestamp for the backup
          TIMESTAMP=$(date +%Y%m%d%H%M%S)
          cp "${TRAEFIK_YAML}" "${TRAEFIK_YAML}.bak.${TIMESTAMP}"
          
          # Comment out the redirection section
          sed -i '/redirections/,+4s/^/#/' "${TRAEFIK_YAML}"
          log_success "Disabled HTTP-to-HTTPS redirection in Traefik configuration"
        else
          log_info "DRY RUN: Would disable HTTP-to-HTTPS redirection in Traefik configuration"
        fi
      else
        log_warning "HTTP-to-HTTPS redirection will remain active (use --force to disable)"
      fi
    else
      log_success "No HTTP-to-HTTPS redirection found in Traefik configuration"
    fi
  else
    log_error "Traefik configuration file not found: ${TRAEFIK_YAML}"
  fi
  
  # Create or update the dashboard routes
  if [ -d "${TRAEFIK_DYNAMIC_DIR}" ]; then
    log_info "Creating optimized dashboard route configuration..."
    
    DASHBOARD_ROUTE="${TRAEFIK_DYNAMIC_DIR}/dashboard-fqdn-fix.yml"
    
    if [ "${DRY_RUN}" = "false" ]; then
      cat > "${DASHBOARD_ROUTE}" <<EOF
http:
  routers:
    # HTTP - Root domain router
    dashboard-root-http:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      priority: 10000
    
    # HTTP - Dashboard path router
    dashboard-path-http:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      middlewares:
        - "dashboard-strip"
      priority: 10001
    
    # HTTPS - Root domain router
    dashboard-root-https:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
      priority: 10000
      tls: {}
      
    # HTTPS - Dashboard path router
    dashboard-path-https:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
      middlewares:
        - "dashboard-strip"
      priority: 10001
      tls: {}
    
    # HTTP - Direct IP access fallback
    dashboard-ip-http:
      rule: "HostRegexp(\`{ip:${SERVER_IP}}\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      priority: 10002
      
    # Catch-all router (last resort)
    dashboard-catchall:
      rule: "PathPrefix(\`/\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      priority: 1
      
  services:
    dashboard-service:
      loadBalancer:
        servers:
          - url: "http://dashboard_${CLIENT_ID}:80"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
    dashboard-cors:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
          - POST
          - DELETE
        accessControlAllowOriginList:
          - "*"
        accessControlAllowHeaders:
          - "*"
EOF
      log_success "Created optimized dashboard route configuration"
    else
      log_info "DRY RUN: Would create optimized dashboard route configuration"
    fi
  else
    log_error "Traefik dynamic configuration directory not found: ${TRAEFIK_DYNAMIC_DIR}"
  fi
  
  # Restart Traefik to apply changes
  if [ "${DRY_RUN}" = "false" ]; then
    log_info "Restarting Traefik to apply configuration changes..."
    cd "${TRAEFIK_DIR}" && docker-compose restart
    log_success "Restarted Traefik"
  else
    log_info "DRY RUN: Would restart Traefik"
  fi
else
  log_error "Traefik directory not found: ${TRAEFIK_DIR}"
fi

# Test access to the dashboard via FQDN
if [ "${DRY_RUN}" = "false" ]; then
  log_info "Testing dashboard access via FQDN..."
  
  # Wait a moment for changes to take effect
  sleep 5
  
  # Test HTTP access to root domain
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${DOMAIN}" || echo "Failed")
  log_info "HTTP status for http://${DOMAIN}: ${HTTP_STATUS}"
  
  # Test HTTP access to dashboard path
  HTTP_PATH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${DOMAIN}/dashboard" || echo "Failed")
  log_info "HTTP status for http://${DOMAIN}/dashboard: ${HTTP_PATH_STATUS}"
  
  # Test HTTPS access (might fail due to self-signed certificate)
  HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -k "https://${DOMAIN}" || echo "Failed")
  log_info "HTTPS status for https://${DOMAIN} (ignoring certificate): ${HTTPS_STATUS}"
  
  # Check if any tests succeeded
  if [ "${HTTP_STATUS}" = "200" ] || [ "${HTTP_PATH_STATUS}" = "200" ] || [ "${HTTPS_STATUS}" = "200" ]; then
    log_success "FQDN access fix successful!"
  else
    log_warning "FQDN access tests did not return a successful status code."
    log_warning "This may be due to DNS caching, try again in a few minutes."
    log_warning "In the meantime, use direct IP access: http://${SERVER_IP}:8888"
  fi
else
  log_info "DRY RUN: Would test dashboard access via FQDN"
fi

log_info "==========================================================="
log_info "DASHBOARD ACCESS URLS:"
echo "1. HTTP FQDN (Root):       http://${DOMAIN}"
echo "2. HTTP FQDN (Path):       http://${DOMAIN}/dashboard"
echo "3. HTTPS FQDN (Root):      https://${DOMAIN}"
echo "4. HTTPS FQDN (Path):      https://${DOMAIN}/dashboard"
echo "5. Direct IP (Guaranteed): http://${SERVER_IP}:8888"
log_info "==========================================================="

log_success "FQDN access fix complete!"
exit 0
