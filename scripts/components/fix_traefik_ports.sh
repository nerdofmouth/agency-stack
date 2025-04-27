#!/bin/bash
# fix_traefik_ports.sh - Fix Traefik Ports for Standard HTTP/HTTPS Access
#
# This script diagnoses and fixes issues with Traefik binding to
# standard web ports (80/443) following the AgencyStack Alpha Phase
# Repository Integrity Policy.
#
# Author: AgencyStack Team
# Date: 2025-04-26
# Updated to support Traefik-Keycloak SSO integration

# Verify running from repository context
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  echo "ERROR: This script must be run from the repository context"
  echo "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1
fi

# DEPRECATION NOTICE: This script's logic should be merged into install_traefik.sh and install_traefik_with_keycloak.sh as part of port validation and remediation. This script will be removed after migration is complete.

set -e

# Self-contained utilities
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

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')
HTTP_PORT="80"
HTTPS_PORT="443"
DASHBOARD_PORT="${TRAEFIK_PORT:-8090}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-8091}"
SSO_ENABLED="${SSO_ENABLED:-false}"

# Paths
INSTALL_ROOT="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_ROOT}/traefik"
TRAEFIK_KEYCLOAK_DIR="${INSTALL_ROOT}/traefik-keycloak"
TRAEFIK_CONFIG_DIR="${TRAEFIK_DIR}/config"
TRAEFIK_DYNAMIC_DIR="${TRAEFIK_CONFIG_DIR}/dynamic"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/traefik-ports-fix.log"

# Parse command-line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false
CHECK_ONLY=false

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
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Start logging
log_info "Starting Traefik ports fix..."
log_info "Domain: ${DOMAIN}"
log_info "Client ID: ${CLIENT_ID}"
log_info "Server IP: ${SERVER_IP}"

# Function to check if a port is in use
check_port_in_use() {
  local port="$1"
  local result
  
  # Try to use netstat to check if port is in use
  if command -v netstat &>/dev/null; then
    result=$(netstat -tuln | grep ":${port} " || echo "")
    
    if [ -n "${result}" ]; then
      log_warning "Port ${port} is already in use:"
      echo "${result}"
      return 0
    else
      log_success "Port ${port} is not in use by any other process"
      return 1
    fi
  else
    # Try to use ss as alternative
    if command -v ss &>/dev/null; then
      result=$(ss -tuln | grep ":${port} " || echo "")
      
      if [ -n "${result}" ]; then
        log_warning "Port ${port} is already in use:"
        echo "${result}"
        return 0
      else
        log_success "Port ${port} is not in use by any other process"
        return 1
      fi
    else
      # Fall back to lsof if available
      if command -v lsof &>/dev/null; then
        result=$(lsof -i :${port} || echo "")
        
        if [ -n "${result}" ]; then
          log_warning "Port ${port} is already in use:"
          echo "${result}"
          return 0
        else
          log_success "Port ${port} is not in use by any other process"
          return 1
        fi
      else
        log_warning "Cannot check if port ${port} is in use: netstat, ss, and lsof not available"
        return 2
      fi
    fi
  fi
}

# Function to check if a port is accessible from outside
check_port_accessible() {
  local port="$1"
  
  log_info "Checking if port ${port} is accessible from localhost..."
  
  # Try to connect to the port
  if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/${port}" 2>/dev/null; then
    log_success "Port ${port} is accessible from localhost"
    return 0
  else
    log_warning "Port ${port} is not accessible from localhost"
    return 1
  fi
}

# Function to check if UFW is blocking ports
check_ufw_status() {
  if command -v ufw &>/dev/null; then
    log_info "Checking UFW firewall status..."
    
    if ufw status | grep -q "Status: active"; then
      log_warning "UFW firewall is active, checking rules..."
      
      # Check HTTP port
      if ! ufw status | grep -q "${HTTP_PORT}/tcp.*ALLOW"; then
        log_warning "HTTP port ${HTTP_PORT} is not allowed by UFW"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding UFW rule to allow HTTP port ${HTTP_PORT}..."
          ufw allow ${HTTP_PORT}/tcp
          log_success "Added UFW rule for HTTP port ${HTTP_PORT}"
        else
          log_info "Would add UFW rule for HTTP port ${HTTP_PORT}"
        fi
      else
        log_success "HTTP port ${HTTP_PORT} is allowed by UFW"
      fi
      
      # Check HTTPS port
      if ! ufw status | grep -q "${HTTPS_PORT}/tcp.*ALLOW"; then
        log_warning "HTTPS port ${HTTPS_PORT} is not allowed by UFW"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding UFW rule to allow HTTPS port ${HTTPS_PORT}..."
          ufw allow ${HTTPS_PORT}/tcp
          log_success "Added UFW rule for HTTPS port ${HTTPS_PORT}"
        else
          log_info "Would add UFW rule for HTTPS port ${HTTPS_PORT}"
        fi
      else
        log_success "HTTPS port ${HTTPS_PORT} is allowed by UFW"
      fi
      
      # Check dashboard port
      if ! ufw status | grep -q "${DASHBOARD_PORT}/tcp.*ALLOW"; then
        log_warning "Dashboard port ${DASHBOARD_PORT} is not allowed by UFW"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding UFW rule to allow dashboard port ${DASHBOARD_PORT}..."
          ufw allow ${DASHBOARD_PORT}/tcp
          log_success "Added UFW rule for dashboard port ${DASHBOARD_PORT}"
        else
          log_info "Would add UFW rule for dashboard port ${DASHBOARD_PORT}"
        fi
      else
        log_success "Dashboard port ${DASHBOARD_PORT} is allowed by UFW"
      fi
    else
      log_success "UFW firewall is not active"
    fi
  else
    log_info "UFW firewall is not installed"
  fi
}

# Function to check if iptables has rules blocking ports
check_iptables_rules() {
  if command -v iptables &>/dev/null; then
    log_info "Checking iptables rules..."
    
    # Check for rules blocking HTTP port
    if iptables -L INPUT -n | grep -q "DROP.*dpt:${HTTP_PORT}"; then
      log_warning "iptables rule found blocking HTTP port ${HTTP_PORT}"
      
      if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
        log_cmd "Removing iptables rule blocking HTTP port ${HTTP_PORT}..."
        iptables -D INPUT -p tcp --dport ${HTTP_PORT} -j DROP
        log_success "Removed iptables rule blocking HTTP port ${HTTP_PORT}"
      else
        log_info "Would remove iptables rule blocking HTTP port ${HTTP_PORT}"
      fi
    else
      log_success "No iptables rules blocking HTTP port ${HTTP_PORT}"
    fi
    
    # Check for rules blocking HTTPS port
    if iptables -L INPUT -n | grep -q "DROP.*dpt:${HTTPS_PORT}"; then
      log_warning "iptables rule found blocking HTTPS port ${HTTPS_PORT}"
      
      if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
        log_cmd "Removing iptables rule blocking HTTPS port ${HTTPS_PORT}..."
        iptables -D INPUT -p tcp --dport ${HTTPS_PORT} -j DROP
        log_success "Removed iptables rule blocking HTTPS port ${HTTPS_PORT}"
      else
        log_info "Would remove iptables rule blocking HTTPS port ${HTTPS_PORT}"
      fi
    else
      log_success "No iptables rules blocking HTTPS port ${HTTPS_PORT}"
    fi
  else
    log_info "iptables is not available"
  fi
}

# Function to check and fix Traefik configuration
check_traefik_config() {
  log_info "Checking Traefik configuration..."
  
  # Determine which Traefik install we're using - standard or with Keycloak
  if [ -d "${TRAEFIK_KEYCLOAK_DIR}" ] && [ -f "${TRAEFIK_KEYCLOAK_DIR}/docker-compose.yml" ]; then
    log_info "Found Traefik with Keycloak SSO installation"
    SSO_ENABLED="true"
    TRAEFIK_COMPOSE_FILE="${TRAEFIK_KEYCLOAK_DIR}/docker-compose.yml"
    TRAEFIK_CONFIG_DIR="${TRAEFIK_KEYCLOAK_DIR}/config/traefik"
    TRAEFIK_DYNAMIC_DIR="${TRAEFIK_CONFIG_DIR}/dynamic"
  elif [ -d "${TRAEFIK_DIR}" ] && [ -f "${TRAEFIK_DIR}/docker-compose.yml" ]; then
    log_info "Found standard Traefik installation"
    TRAEFIK_COMPOSE_FILE="${TRAEFIK_DIR}/docker-compose.yml"
  else
    log_error "No Traefik installation found in ${TRAEFIK_DIR} or ${TRAEFIK_KEYCLOAK_DIR}"
    return 1
  fi
  
  # Continue with existing check_traefik_config function...
  
  # If we're using the SSO version, update ports in docker-compose.yml
  if [ "${SSO_ENABLED}" = "true" ]; then
    log_info "Updating Traefik-Keycloak Docker Compose file..."
    
    if [ -f "${TRAEFIK_COMPOSE_FILE}" ]; then
      if ! grep -q "${HTTP_PORT}:80" "${TRAEFIK_COMPOSE_FILE}"; then
        log_warning "HTTP port mapping is not correctly configured in Docker Compose file"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Updating HTTP port mapping in Docker Compose file..."
          sed -i "s/- \"80:80\"/- \"${HTTP_PORT}:80\"/" "${TRAEFIK_COMPOSE_FILE}"
          sed -i "s/- \"[0-9]*:80\"/- \"${HTTP_PORT}:80\"/" "${TRAEFIK_COMPOSE_FILE}"
          log_success "Updated HTTP port mapping in Docker Compose file"
        else
          log_info "Would update HTTP port mapping in Docker Compose file"
        fi
      else
        log_success "HTTP port mapping is correctly configured in Docker Compose file"
      fi
      
      # Check if HTTPS port should be added to docker-compose.yml
      if ! grep -q "${HTTPS_PORT}:443" "${TRAEFIK_COMPOSE_FILE}" && ! grep -q "443:443" "${TRAEFIK_COMPOSE_FILE}"; then
        log_warning "HTTPS port mapping is not configured in Docker Compose file"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding HTTPS port mapping to Docker Compose file..."
          sed -i "/- \"${HTTP_PORT}:80\"/a \      - \"${HTTPS_PORT}:443\"" "${TRAEFIK_COMPOSE_FILE}"
          log_success "Added HTTPS port mapping to Docker Compose file"
        else
          log_info "Would add HTTPS port mapping to Docker Compose file"
        fi
      else
        if grep -q "443:443" "${TRAEFIK_COMPOSE_FILE}" && [ "${HTTPS_PORT}" != "443" ]; then
          log_warning "HTTPS port mapping is using default port 443, but we need to use ${HTTPS_PORT}"
          
          if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
            log_cmd "Updating HTTPS port mapping in Docker Compose file..."
            sed -i "s/- \"443:443\"/- \"${HTTPS_PORT}:443\"/" "${TRAEFIK_COMPOSE_FILE}"
            log_success "Updated HTTPS port mapping in Docker Compose file"
          else
            log_info "Would update HTTPS port mapping in Docker Compose file"
          fi
        else
          log_success "HTTPS port mapping is correctly configured in Docker Compose file"
        fi
      fi
    else
      log_error "Docker Compose file not found at ${TRAEFIK_COMPOSE_FILE}"
    fi
  }
}

# Function to check and configure cloud provider firewall
check_cloud_provider() {
  log_info "Checking cloud provider specific settings..."
  
  # Check if running on a cloud provider
  local cloud_provider=""
  
  # Check for Digital Ocean
  if [ -f /etc/digitalocean-agent.json ] || grep -q "digitalocean" /proc/cpuinfo 2>/dev/null; then
    cloud_provider="digitalocean"
  fi
  
  # Check for AWS
  if [ -f /sys/hypervisor/uuid ] && grep -q "ec2" /sys/hypervisor/uuid 2>/dev/null; then
    cloud_provider="aws"
  fi
  
  # Check for Google Cloud
  if [ -f /etc/google-fluentd/config.d/instance.conf ] || grep -q "Google" /proc/cpuinfo 2>/dev/null; then
    cloud_provider="gcp"
  fi
  
  # Check for Azure
  if grep -q "Microsoft Corporation" /proc/version 2>/dev/null || [ -f /etc/waagent.conf ]; then
    cloud_provider="azure"
  fi
  
  if [ -n "${cloud_provider}" ]; then
    log_info "Detected cloud provider: ${cloud_provider}"
    
    case "${cloud_provider}" in
      "digitalocean")
        log_warning "Digital Ocean may have firewall rules blocking ports 80 and 443"
        log_warning "Please ensure ports 80 and 443 are allowed in the Digital Ocean firewall"
        ;;
      "aws")
        log_warning "AWS may have security group rules blocking ports 80 and 443"
        log_warning "Please ensure ports 80 and 443 are allowed in the AWS security group"
        ;;
      "gcp")
        log_warning "Google Cloud may have firewall rules blocking ports 80 and 443"
        log_warning "Please ensure ports 80 and 443 are allowed in the GCP firewall"
        ;;
      "azure")
        log_warning "Azure may have network security group rules blocking ports 80 and 443"
        log_warning "Please ensure ports 80 and 443 are allowed in the Azure NSG"
        ;;
    esac
  else
    log_info "Not running on a detected cloud provider"
  fi
}

# Function to handle Docker Compose restart after changes
restart_docker_compose() {
  log_info "Restarting Docker Compose services..."
  
  if [ "${DRY_RUN}" = "true" ] || [ "${CHECK_ONLY}" = "true" ]; then
    log_info "Would restart Docker Compose services"
    return 0
  fi
  
  # Determine which Traefik service to restart
  if [ "${SSO_ENABLED}" = "true" ]; then
    if [ -f "${TRAEFIK_KEYCLOAK_DIR}/docker-compose.yml" ]; then
      log_cmd "Restarting Traefik with Keycloak services..."
      cd "${TRAEFIK_KEYCLOAK_DIR}" && docker-compose restart || {
        log_error "Failed to restart Traefik with Keycloak services"
        return 1
      }
      log_success "Restarted Traefik with Keycloak services"
    else
      log_error "Docker Compose file not found at ${TRAEFIK_KEYCLOAK_DIR}/docker-compose.yml"
      return 1
    fi
  else
    if [ -f "${TRAEFIK_DIR}/docker-compose.yml" ]; then
      log_cmd "Restarting standard Traefik service..."
      cd "${TRAEFIK_DIR}" && docker-compose restart || {
        log_error "Failed to restart standard Traefik service"
        return 1
      }
      log_success "Restarted standard Traefik service"
    else
      log_error "Docker Compose file not found at ${TRAEFIK_DIR}/docker-compose.yml"
      return 1
    fi
  fi
  
  return 0
}

# Main execution flow
log_info "Running port checks..."

# First determine if any Traefik installation exists and which type
if [ -d "${TRAEFIK_KEYCLOAK_DIR}" ] && [ -f "${TRAEFIK_KEYCLOAK_DIR}/docker-compose.yml" ]; then
  log_info "Detected Traefik with Keycloak SSO installation"
  SSO_ENABLED="true"
elif [ -d "${TRAEFIK_DIR}" ] && [ -f "${TRAEFIK_DIR}/docker-compose.yml" ]; then
  log_info "Detected standard Traefik installation"
else
  log_warning "No Traefik installation detected. This script is only for existing installations."
  log_info "To install Traefik, run: make traefik or make traefik-keycloak-sso"
  exit 0
fi

# Check if ports are in use
check_port_in_use "${HTTP_PORT}"
check_port_in_use "${HTTPS_PORT}"

# Check if ports are accessible
check_port_accessible "${HTTP_PORT}"
check_port_accessible "${HTTPS_PORT}"

# Check firewall configurations
check_ufw_status
check_iptables_rules

# Check Traefik configuration
check_traefik_config

# Check cloud provider specific settings
check_cloud_provider

# Test access to the dashboard via FQDN
if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
  log_info "Waiting for changes to take effect..."
  sleep 5
  
  log_info "Testing standard port access..."
  
  # Test HTTP access
  if curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${DOMAIN}" > /dev/null 2>&1; then
    log_success "HTTP access is working for http://${DOMAIN}"
  else
    log_warning "HTTP access is not working for http://${DOMAIN}"
    log_warning "You may need to wait for changes to propagate or check cloud provider firewall settings"
  fi
  
  # Test HTTPS access (might fail due to self-signed certificate)
  if curl -s -o /dev/null -w "%{http_code}" -m 5 -k "https://${DOMAIN}" > /dev/null 2>&1; then
    log_success "HTTPS access is working for https://${DOMAIN} (ignoring certificate)"
  else
    log_warning "HTTPS access is not working for https://${DOMAIN}"
    log_warning "You may need to wait for changes to propagate or check cloud provider firewall settings"
  fi
fi

# If we made any changes and we're not in check-only mode, restart services
if [ "${CHANGES_MADE}" = "true" ] && [ "${CHECK_ONLY}" = "false" ] && [ "${DRY_RUN}" = "false" ]; then
  restart_docker_compose
fi

# Final report
if [ "${CHANGES_MADE}" = "true" ]; then
  if [ "${DRY_RUN}" = "true" ]; then
    log_info "Dry run completed. Changes would be made to fix Traefik port issues."
  elif [ "${CHECK_ONLY}" = "true" ]; then
    log_warning "Check completed. Issues found that require fixing."
  else
    log_success "Traefik port issues fixed successfully."
  fi
else
  log_success "No issues found with Traefik port configuration."
fi

# Record this run in the repository context
if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  echo "$(date): fix_traefik_ports.sh run completed" >> "${REPO_ROOT}/traefik_fixes.log"
  echo "Repository Integrity Policy enforced" >> "${REPO_ROOT}/traefik_fixes.log"
fi

log_info "Traefik ports fix completed."
exit 0
