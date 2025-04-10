#!/bin/bash
# dashboard_dns_helper.sh - DNS Helper for Dashboard Access
#
# This utility script helps verify DNS configuration for dashboard access
# and provides troubleshooting steps for common issues.
#
# Author: AgencyStack Team
# Date: 2025-04-10

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Usage information
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  --domain DOMAIN       Domain to check (default: ${DOMAIN})"
  echo "  --client-id CLIENT_ID Client ID (default: ${CLIENT_ID})"
  echo "  --fix                 Apply recommended fixes automatically"
  echo "  --verbose             Enable verbose output"
  echo "  --help                Display this help message"
  echo
  exit 1
}

# Parse command-line arguments
VERBOSE=false
FIX=false

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
    --fix)
      FIX=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      ;;
  esac
done

# Function to verify DNS resolution
verify_dns() {
  local domain="$1"
  local expected_ip="$2"
  local result
  
  log_info "Checking DNS resolution for ${domain}..."
  result=$(dig +short "${domain}" || echo "FAILED")
  
  if [ -z "${result}" ]; then
    log_error "DNS resolution failed for ${domain}: No A record found"
    return 1
  elif [ "${result}" != "${expected_ip}" ]; then
    log_warning "DNS resolution mismatch for ${domain}"
    log_warning "  Expected: ${expected_ip}"
    log_warning "  Actual:   ${result}"
    return 2
  else
    log_success "DNS resolution correct for ${domain}: ${result}"
    return 0
  fi
}

# Function to check hosts file
check_hosts_file() {
  local domain="$1"
  local remove_entry="$2"
  
  log_info "Checking hosts file for ${domain}..."
  
  if grep -q "${domain}" /etc/hosts; then
    if [ "${remove_entry}" = "true" ]; then
      log_warning "Found ${domain} in hosts file, removing..."
      if [ "${FIX}" = "true" ]; then
        sudo sed -i "/\s${domain}/d" /etc/hosts
        log_success "Removed ${domain} from hosts file"
      else
        log_warning "Use --fix to remove the hosts file entry"
      fi
    else
      log_warning "Found ${domain} in hosts file. This may interfere with proper DNS resolution."
    fi
    return 1
  else
    log_success "No hosts file entry for ${domain}"
    return 0
  fi
}

# Function to check Traefik configuration
check_traefik() {
  local client_id="$1"
  
  log_info "Checking Traefik configuration..."
  
  # Paths
  TRAEFIK_DIR="/opt/agency_stack/clients/${client_id}/traefik"
  TRAEFIK_CONFIG="${TRAEFIK_DIR}/config/traefik.yml"
  
  if [ ! -d "${TRAEFIK_DIR}" ]; then
    log_error "Traefik directory not found: ${TRAEFIK_DIR}"
    return 1
  fi
  
  if [ ! -f "${TRAEFIK_CONFIG}" ]; then
    log_error "Traefik configuration not found: ${TRAEFIK_CONFIG}"
    return 1
  fi
  
  # Check HTTP to HTTPS redirection
  if grep -q "redirections" "${TRAEFIK_CONFIG}"; then
    log_warning "HTTP to HTTPS redirection is enabled in Traefik"
    log_warning "This may cause issues if SSL certificates are not properly set up"
    
    if [ "${FIX}" = "true" ]; then
      log_info "Creating backup of Traefik configuration..."
      cp "${TRAEFIK_CONFIG}" "${TRAEFIK_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
      
      log_info "Removing HTTP to HTTPS redirection..."
      sed -i '/redirections/,+4d' "${TRAEFIK_CONFIG}"
      
      log_success "Updated Traefik configuration"
    else
      log_warning "Use --fix to modify Traefik configuration"
    fi
    
    return 1
  else
    log_success "Traefik HTTP configuration looks good (no forced HTTPS redirection)"
    return 0
  fi
}

# Function to check dashboard container
check_dashboard() {
  local client_id="$1"
  local container_name="dashboard_${client_id}"
  
  log_info "Checking dashboard container..."
  
  if ! docker ps | grep -q "${container_name}"; then
    log_error "Dashboard container not running: ${container_name}"
    
    if docker ps -a | grep -q "${container_name}"; then
      log_warning "Container exists but is not running"
      
      if [ "${FIX}" = "true" ]; then
        log_info "Starting dashboard container..."
        docker start "${container_name}"
        log_success "Started dashboard container"
      else
        log_warning "Use --fix to start the container"
      fi
    else
      log_error "Container does not exist"
    fi
    
    return 1
  else
    log_success "Dashboard container is running: ${container_name}"
    return 0
  fi
}

# Perform comprehensive check
log_info "Starting dashboard DNS verification..."
log_info "Domain: ${DOMAIN}"
log_info "Server IP: ${SERVER_IP}"
log_info "Client ID: ${CLIENT_ID}"

# Check hosts file first
check_hosts_file "${DOMAIN}" true

# Check DNS resolution
verify_dns "${DOMAIN}" "${SERVER_IP}"
DNS_STATUS=$?

# Check Traefik configuration
check_traefik "${CLIENT_ID}"
TRAEFIK_STATUS=$?

# Check dashboard container
check_dashboard "${CLIENT_ID}"
DASHBOARD_STATUS=$?

# Print access URLs
log_info "==========================================================="
log_info "DASHBOARD ACCESS URLS:"
echo "1. HTTP FQDN (Root):       http://${DOMAIN}"
echo "2. HTTP FQDN (Path):       http://${DOMAIN}/dashboard"
echo "3. Direct IP (Main):       http://${SERVER_IP}:3001"
echo "4. Direct IP (Fallback):   http://${SERVER_IP}:8080"
echo "5. Direct IP (Guaranteed): http://${SERVER_IP}:8888"
log_info "==========================================================="

# Final status summary
log_info "Status Summary:"
if [ "${DNS_STATUS}" -eq 0 ]; then
  log_success "DNS: ✓ Correctly configured"
else
  log_error "DNS: ✗ Issues detected"
fi

if [ "${TRAEFIK_STATUS}" -eq 0 ]; then
  log_success "Traefik: ✓ Correctly configured"
else
  log_warning "Traefik: ⚠ Configuration issues"
fi

if [ "${DASHBOARD_STATUS}" -eq 0 ]; then
  log_success "Dashboard: ✓ Container running"
else
  log_error "Dashboard: ✗ Container issues"
fi

# Overall recommendation
if [ "${DNS_STATUS}" -eq 0 ] && [ "${TRAEFIK_STATUS}" -eq 0 ] && [ "${DASHBOARD_STATUS}" -eq 0 ]; then
  log_success "All checks passed! Dashboard should be accessible via all methods."
else
  if [ "${DNS_STATUS}" -ne 0 ]; then
    log_warning "For immediate access, use direct IP method: http://${SERVER_IP}:8888"
  else
    log_warning "Try accessing the dashboard via http://${DOMAIN}/dashboard"
  fi
fi

exit 0
