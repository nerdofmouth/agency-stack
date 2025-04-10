#!/bin/bash
# fix_traefik_ports.sh - Fix Traefik Ports for Standard HTTP/HTTPS Access
#
# This script diagnoses and fixes issues with Traefik binding to
# standard web ports (80/443) following the AgencyStack Alpha Phase
# Repository Integrity Policy.
#
# Author: AgencyStack Team
# Date: 2025-04-10

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
DASHBOARD_PORT="3001"

# Paths
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
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
  
  if [ -d "${TRAEFIK_DIR}" ]; then
    local traefik_running=false
    
    # Check if Traefik container is running
    if docker ps | grep -q "traefik"; then
      log_success "Traefik container is running"
      traefik_running=true
    else
      log_warning "Traefik container is not running"
      
      if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
        log_cmd "Starting Traefik container..."
        cd "${TRAEFIK_DIR}" && docker-compose up -d
        log_success "Started Traefik container"
        traefik_running=true
      else
        log_info "Would start Traefik container"
      fi
    fi
    
    # Check Traefik configuration file
    local traefik_yaml="${TRAEFIK_CONFIG_DIR}/traefik.yml"
    if [ -f "${traefik_yaml}" ]; then
      log_info "Checking Traefik port configuration in ${traefik_yaml}..."
      
      # Extract entry points configuration
      local web_port=$(grep -A 10 "entryPoints:" "${traefik_yaml}" | grep -A 2 "web:" | grep "address:" | grep -o ":[0-9]*" | cut -d':' -f2 || echo "")
      local websecure_port=$(grep -A 15 "entryPoints:" "${traefik_yaml}" | grep -A 2 "websecure:" | grep "address:" | grep -o ":[0-9]*" | cut -d':' -f2 || echo "")
      
      # Check web entry point
      if [ "${web_port}" = "80" ]; then
        log_success "Traefik web entry point is correctly configured for port 80"
      else
        log_warning "Traefik web entry point is using non-standard port: ${web_port:-not set}"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Updating Traefik web entry point to use port 80..."
          
          # Create a backup of the configuration file
          local backup_file="${traefik_yaml}.bak.$(date +%Y%m%d%H%M%S)"
          cp "${traefik_yaml}" "${backup_file}"
          
          # Update the configuration
          if grep -q "web:" "${traefik_yaml}"; then
            # Entry point exists, update the address
            sed -i '/entryPoints:/,/web:/s/address:.*$/address: ":80"/' "${traefik_yaml}"
          else
            # Entry point doesn't exist, add it
            sed -i '/entryPoints:/a \  web:\n    address: ":80"' "${traefik_yaml}"
          fi
          
          log_success "Updated Traefik web entry point to use port 80"
        else
          log_info "Would update Traefik web entry point to use port 80"
        fi
      fi
      
      # Check websecure entry point
      if [ "${websecure_port}" = "443" ]; then
        log_success "Traefik websecure entry point is correctly configured for port 443"
      else
        log_warning "Traefik websecure entry point is using non-standard port: ${websecure_port:-not set}"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Updating Traefik websecure entry point to use port 443..."
          
          # Create a backup of the configuration file if not already done
          if [ ! -f "${backup_file}" ]; then
            local backup_file="${traefik_yaml}.bak.$(date +%Y%m%d%H%M%S)"
            cp "${traefik_yaml}" "${backup_file}"
          fi
          
          # Update the configuration
          if grep -q "websecure:" "${traefik_yaml}"; then
            # Entry point exists, update the address
            sed -i '/entryPoints:/,/websecure:/s/address:.*$/address: ":443"/' "${traefik_yaml}"
          else
            # Entry point doesn't exist, add it
            sed -i '/entryPoints:/a \  websecure:\n    address: ":443"' "${traefik_yaml}"
          fi
          
          log_success "Updated Traefik websecure entry point to use port 443"
        else
          log_info "Would update Traefik websecure entry point to use port 443"
        fi
      fi
      
      # Check HTTP to HTTPS redirection
      if grep -q "redirections" "${traefik_yaml}"; then
        if [ "${FORCE}" = "true" ]; then
          log_warning "HTTP to HTTPS redirection is enabled in Traefik configuration"
          
          if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
            log_cmd "Disabling HTTP to HTTPS redirection..."
            
            # Create a backup of the configuration file if not already done
            if [ ! -f "${backup_file}" ]; then
              local backup_file="${traefik_yaml}.bak.$(date +%Y%m%d%H%M%S)"
              cp "${traefik_yaml}" "${backup_file}"
            fi
            
            # Comment out the redirection section
            sed -i '/redirections/,+4s/^/#/' "${traefik_yaml}"
            
            log_success "Disabled HTTP to HTTPS redirection"
          else
            log_info "Would disable HTTP to HTTPS redirection"
          fi
        else
          log_info "HTTP to HTTPS redirection is enabled (use --force to disable)"
        fi
      else
        log_success "HTTP to HTTPS redirection is not enabled"
      fi
      
      # Restart Traefik if configuration was changed and not in dry run or check only mode
      if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ] && [ -f "${backup_file}" ]; then
        log_cmd "Restarting Traefik to apply configuration changes..."
        cd "${TRAEFIK_DIR}" && docker-compose restart
        log_success "Restarted Traefik"
      fi
    else
      log_error "Traefik configuration file not found: ${traefik_yaml}"
    fi
    
    # Check if docker-compose.yml has port mappings
    local docker_compose_file="${TRAEFIK_DIR}/docker-compose.yml"
    if [ -f "${docker_compose_file}" ]; then
      log_info "Checking Traefik port mappings in ${docker_compose_file}..."
      
      # Check if port 80 is mapped
      if grep -q "80:80" "${docker_compose_file}"; then
        log_success "Port 80 is mapped in Traefik docker-compose.yml"
      else
        log_warning "Port 80 is not mapped in Traefik docker-compose.yml"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding port 80 mapping to Traefik docker-compose.yml..."
          
          # Create a backup of the file
          local backup_file="${docker_compose_file}.bak.$(date +%Y%m%d%H%M%S)"
          cp "${docker_compose_file}" "${backup_file}"
          
          # Add port mapping to docker-compose.yml
          sed -i '/ports:/a \      - "80:80"' "${docker_compose_file}"
          
          log_success "Added port 80 mapping to Traefik docker-compose.yml"
        else
          log_info "Would add port 80 mapping to Traefik docker-compose.yml"
        fi
      fi
      
      # Check if port 443 is mapped
      if grep -q "443:443" "${docker_compose_file}"; then
        log_success "Port 443 is mapped in Traefik docker-compose.yml"
      else
        log_warning "Port 443 is not mapped in Traefik docker-compose.yml"
        
        if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ]; then
          log_cmd "Adding port 443 mapping to Traefik docker-compose.yml..."
          
          # Create a backup of the file if not already done
          if [ ! -f "${backup_file}" ]; then
            local backup_file="${docker_compose_file}.bak.$(date +%Y%m%d%H%M%S)"
            cp "${docker_compose_file}" "${backup_file}"
          fi
          
          # Add port mapping to docker-compose.yml
          sed -i '/ports:/a \      - "443:443"' "${docker_compose_file}"
          
          log_success "Added port 443 mapping to Traefik docker-compose.yml"
        else
          log_info "Would add port 443 mapping to Traefik docker-compose.yml"
        fi
      fi
      
      # Restart Traefik if configuration was changed and not in dry run or check only mode
      if [ "${DRY_RUN}" = "false" ] && [ "${CHECK_ONLY}" = "false" ] && [ -f "${backup_file}" ]; then
        log_cmd "Restarting Traefik to apply port mapping changes..."
        cd "${TRAEFIK_DIR}" && docker-compose down && docker-compose up -d
        log_success "Restarted Traefik"
      fi
    else
      log_error "Traefik docker-compose.yml file not found: ${docker_compose_file}"
    fi
  else
    log_error "Traefik directory not found: ${TRAEFIK_DIR}"
  fi
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

# Main checks
log_info "Running port checks..."

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

log_info "==========================================================="
log_info "PORT ACCESS FIX SUMMARY"
echo "Domain: ${DOMAIN}"
echo "Ports checked: ${HTTP_PORT}, ${HTTPS_PORT}"
echo ""
echo "RECOMMENDED ACCESS METHODS:"
echo "1. HTTP FQDN:         http://${DOMAIN}"
echo "2. HTTPS FQDN:        https://${DOMAIN}"
echo "3. Direct IP (Main):  http://${SERVER_IP}:${DASHBOARD_PORT}"
echo "4. Guaranteed Backup: http://${SERVER_IP}:8888"
log_info "==========================================================="

log_success "Traefik ports fix complete!"
exit 0
