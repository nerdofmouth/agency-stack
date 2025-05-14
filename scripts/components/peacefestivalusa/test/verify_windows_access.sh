#!/bin/bash

# PeaceFestivalUSA Windows Browser Access Verification
# Following AgencyStack Charter v1.0.3 Principles
# - Test-Driven Development
# - Repository as Source of Truth
# - Component Consistency
# - Auditability & Documentation

set -e

# Script location and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost"
LOG_FILE="${SCRIPT_DIR}/windows_access_test_$(date +%Y%m%d).log"

# Simple logging functions
log_info() { echo -e "[INFO] $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1" | tee -a "$LOG_FILE"; }

# Initialize log file
echo "PeaceFestivalUSA Windows Browser Access Test - $(date)" > "$LOG_FILE"
echo "====================================================" >> "$LOG_FILE"

log_info "Starting Windows browser access verification"

# Check if running in WSL
IS_WSL=false
if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  IS_WSL=true
  log_info "Detected WSL environment: $(grep -Eo '(Microsoft|WSL)' /proc/version)"
  
  # Get Windows host IP
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  log_info "Windows Host IP: ${WINDOWS_HOST_IP}"
else
  log_warning "Not running in WSL environment, some tests may not be relevant"
  WINDOWS_HOST_IP="127.0.0.1"  # Fallback for testing
fi

# Test function for endpoint accessibility
test_endpoint() {
  local name="$1"
  local url="$2"
  local host_header="$3"
  local expected_code="$4"
  
  log_info "Testing ${name}..."
  
  local curl_cmd="curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${host_header}' '${url}'"
  log_info "Command: ${curl_cmd}"
  
  local result
  if [[ -n "$host_header" ]]; then
    result=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${host_header}" "${url}")
  else
    result=$(curl -s -o /dev/null -w '%{http_code}' "${url}")
  fi
  
  if [[ "$result" == "$expected_code" ]]; then
    log_success "${name}: Success (HTTP ${result})"
    return 0
  else
    log_error "${name}: Failed (HTTP ${result}, expected ${expected_code})"
    return 1
  fi
}

# Check if Docker containers are running
log_info "Checking Docker containers..."

docker_containers=("${CLIENT_ID}_traefik" "${CLIENT_ID}_wordpress" "${CLIENT_ID}_mariadb")
all_running=true

for container in "${docker_containers[@]}"; do
  if docker ps --filter "name=${container}" --format '{{.Status}}' | grep -q "Up"; then
    log_info "Container ${container} is running"
  else
    log_error "Container ${container} is not running"
    all_running=false
  fi
done

if ! $all_running; then
  log_error "Not all required containers are running. Please start them first."
  exit 1
fi

# Test local access
log_info "Testing local access..."
test_endpoint "Local Traefik root" "http://localhost:80" "" "200"
test_endpoint "Local WordPress" "http://localhost:80" "${CLIENT_ID}.${DOMAIN}" "200"

# Test Windows host access if in WSL
if $IS_WSL; then
  log_info "Testing Windows host browser access..."
  test_endpoint "Windows host Traefik" "http://${WINDOWS_HOST_IP}:80" "" "200"
  test_endpoint "Windows host WordPress" "http://${WINDOWS_HOST_IP}:80" "${CLIENT_ID}.${DOMAIN}" "200"
  test_endpoint "Windows host Traefik dashboard" "http://${WINDOWS_HOST_IP}:80" "traefik.${CLIENT_ID}.${DOMAIN}" "401"
else
  log_warning "Skipping Windows host browser access tests (not running in WSL)"
fi

# Generate Windows browser access instructions
cat << EOF

###############################################
# Windows Browser Access Instructions
###############################################

To access PeaceFestivalUSA WordPress from your Windows browser:

1. Add these entries to your Windows hosts file
   (C:\\Windows\\System32\\drivers\\etc\\hosts):

   127.0.0.1 ${CLIENT_ID}.${DOMAIN}
   127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN}

2. Access the following URLs in your browser:

   WordPress site:
   http://${CLIENT_ID}.${DOMAIN}

   Traefik dashboard (login: admin/admin123):
   http://traefik.${CLIENT_ID}.${DOMAIN}

3. If you encounter issues, try:
   - Direct IP access: http://${WINDOWS_HOST_IP}:80
   - Restart Docker Desktop
   - Restart WSL (wsl --shutdown in PowerShell)

###############################################

Test results have been saved to: ${LOG_FILE}
EOF

log_info "Windows browser access verification completed"
