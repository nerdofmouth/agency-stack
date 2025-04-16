#!/bin/bash
# dns_checker.sh - DNS Configuration Validation Utility
#
# This script validates DNS resolution for AgencyStack components
# and verifies that domains point to the correct server IP.
#
# Author: AgencyStack Team
# Date: 2025-04-10

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
SERVER_IP=""
COMPONENTS_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
LOG_DIR="/var/log/agency_stack/dns"
LOG_FILE="${LOG_DIR}/dns_check.log"
REPORT_FILE="${LOG_DIR}/dns_report.md"
DNS_CACHE_FILE="${LOG_DIR}/dns_cache.json"

# Command-line arguments
VERBOSE=false
GENERATE_REPORT=false
FIX_HOSTS=false
EXTERNAL_CHECK=false

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --domain DOMAIN       Domain to check (default: value from env or localhost)"
  echo "  --client-id ID        Client ID (default: default)"
  echo "  --ip IP               Server IP address (auto-detected if not provided)"
  echo "  --generate-report     Generate a detailed DNS report"
  echo "  --fix-hosts           Add missing entries to /etc/hosts (requires sudo)"
  echo "  --external-check      Check external DNS resolution via public resolvers"
  echo "  --verbose             Show detailed output"
  echo "  --help                Show this help message"
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
    --ip)
      SERVER_IP="$2"
      shift 2
      ;;
    --generate-report)
      GENERATE_REPORT=true
      shift
      ;;
    --fix-hosts)
      FIX_HOSTS=true
      shift
      ;;
    --external-check)
      EXTERNAL_CHECK=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Create log directory
mkdir -p "${LOG_DIR}"

# Get server IP if not provided
if [[ -z "${SERVER_IP}" ]]; then
  log_info "Auto-detecting server IP address..."
  SERVER_IP=$(hostname -I | awk '{print $1}')
  if [[ -z "${SERVER_IP}" ]]; then
    log_error "Failed to detect server IP. Please provide it with --ip."
    exit 1
  fi
  log_info "Using server IP: ${SERVER_IP}"
fi

# Initialize report
if [[ "${GENERATE_REPORT}" == "true" ]]; then
  cat > "${REPORT_FILE}" <<EOF
# AgencyStack DNS Resolution Report

Generated on: $(date)

| Domain | Expected IP | Actual IP | Status |
|--------|-------------|-----------|--------|
EOF
fi

# Initialize DNS cache
if [[ ! -f "${DNS_CACHE_FILE}" ]]; then
  echo "{}" > "${DNS_CACHE_FILE}"
fi

# Find all component directories
log_info "Scanning for installed components..."
COMPONENTS=()
while IFS= read -r dir; do
  if [[ -d "${dir}" ]]; then
    component=$(basename "${dir}")
    COMPONENTS+=("${component}")
    log_info "Found component: ${component}"
  fi
done < <(find "${COMPONENTS_DIR}" -maxdepth 1 -type d | grep -v "^${COMPONENTS_DIR}$")

# Add core domains
DOMAINS_TO_CHECK=()

# Add the base domain
DOMAINS_TO_CHECK+=("${DOMAIN}")

# Add component-specific domains
for component in "${COMPONENTS[@]}"; do
  case "${component}" in
    traefik)
      DOMAINS_TO_CHECK+=("traefik.${DOMAIN}")
      ;;
    dashboard)
      DOMAINS_TO_CHECK+=("${DOMAIN}")
      DOMAINS_TO_CHECK+=("dashboard.${DOMAIN}")
      ;;
    keycloak)
      DOMAINS_TO_CHECK+=("auth.${DOMAIN}")
      DOMAINS_TO_CHECK+=("keycloak.${DOMAIN}")
      ;;
    grafana)
      DOMAINS_TO_CHECK+=("grafana.${DOMAIN}")
      ;;
    prometheus)
      DOMAINS_TO_CHECK+=("metrics.${DOMAIN}")
      ;;
    *)
      DOMAINS_TO_CHECK+=("${component}.${DOMAIN}")
      ;;
  esac
done

# De-duplicate domains
DOMAINS_TO_CHECK=($(echo "${DOMAINS_TO_CHECK[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

# Check domain resolution
log_info "Checking DNS resolution for ${#DOMAINS_TO_CHECK[@]} domains..."
ERRORS=0
WARNINGS=0
FIXED=0

check_domain() {
  local domain="$1"
  local expected_ip="$2"
  local status="✅ OK"
  local actual_ip=""
  
  log_info "Checking ${domain}..."
  
  # Check internal resolution first (using getent or nslookup)
  if command -v getent &>/dev/null; then
    actual_ip=$(getent hosts "${domain}" 2>/dev/null | awk '{print $1}' || echo "")
  else
    actual_ip=$(nslookup "${domain}" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' || echo "")
  fi
  
  # If external check is requested, use public DNS servers
  if [[ "${EXTERNAL_CHECK}" == "true" ]]; then
    log_info "Performing external DNS check for ${domain}..."
    external_ip=$(dig +short "${domain}" @8.8.8.8 || echo "")
    if [[ -n "${external_ip}" ]]; then
      actual_ip="${external_ip}"
      log_info "External resolution: ${domain} -> ${actual_ip}"
    else
      log_warning "External DNS resolution failed for ${domain}"
    fi
  fi
  
  # Check for successful resolution
  if [[ -z "${actual_ip}" ]]; then
    status="❌ Not Found"
    ERRORS=$((ERRORS + 1))
    
    # Check if entry exists in /etc/hosts
    local hosts_entry=$(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+.*${domain}" /etc/hosts || echo "")
    
    if [[ -n "${hosts_entry}" ]]; then
      local hosts_ip=$(echo "${hosts_entry}" | awk '{print $1}')
      log_warning "Found in /etc/hosts: ${domain} -> ${hosts_ip} (but not in DNS)"
      WARNINGS=$((WARNINGS + 1))
      
      if [[ "${hosts_ip}" != "${expected_ip}" ]]; then
        log_warning "IP mismatch in /etc/hosts: Expected ${expected_ip}, found ${hosts_ip}"
        
        if [[ "${FIX_HOSTS}" == "true" ]]; then
          log_info "Updating hosts entry for ${domain}..."
          if sudo sed -i "s/^.*[[:space:]]${domain}[[:space:]].*/${expected_ip} ${domain}/" /etc/hosts; then
            log_success "Updated /etc/hosts entry: ${domain} -> ${expected_ip}"
            FIXED=$((FIXED + 1))
          else
            log_error "Failed to update /etc/hosts entry for ${domain}"
          fi
        fi
      fi
    else
      log_warning "${domain} not found in DNS or /etc/hosts"
      
      if [[ "${FIX_HOSTS}" == "true" ]]; then
        log_info "Adding ${domain} to /etc/hosts..."
        if sudo bash -c "echo '${expected_ip} ${domain}' >> /etc/hosts"; then
          log_success "Added to /etc/hosts: ${domain} -> ${expected_ip}"
          FIXED=$((FIXED + 1))
        else
          log_error "Failed to add ${domain} to /etc/hosts"
        fi
      fi
    fi
  elif [[ "${actual_ip}" != "${expected_ip}" ]]; then
    status="⚠️ Wrong IP"
    WARNINGS=$((WARNINGS + 1))
    log_warning "IP mismatch for ${domain}: Expected ${expected_ip}, found ${actual_ip}"
  else
    log_success "${domain} correctly resolves to ${actual_ip}"
  fi
  
  # Update the report if requested
  if [[ "${GENERATE_REPORT}" == "true" ]]; then
    echo "| ${domain} | ${expected_ip} | ${actual_ip:-Not Resolved} | ${status} |" >> "${REPORT_FILE}"
  fi
  
  # Update DNS cache
  local current_time=$(date +%s)
  local cache_entry="{\"domain\":\"${domain}\",\"ip\":\"${actual_ip:-NOTFOUND}\",\"timestamp\":${current_time}}"
  tmp_cache=$(mktemp)
  jq ".\"${domain}\" = ${cache_entry}" "${DNS_CACHE_FILE}" > "${tmp_cache}" && mv "${tmp_cache}" "${DNS_CACHE_FILE}"
}

# Check each domain
for domain in "${DOMAINS_TO_CHECK[@]}"; do
  check_domain "${domain}" "${SERVER_IP}"
done

# Summarize results
log_info "DNS check completed."
log_info "Domains checked: ${#DOMAINS_TO_CHECK[@]}"
log_info "Errors found: ${ERRORS}"
log_info "Warnings found: ${WARNINGS}"
if [[ "${FIX_HOSTS}" == "true" ]]; then
  log_info "Fixes applied: ${FIXED}"
fi

if [[ "${GENERATE_REPORT}" == "true" ]]; then
  log_info "Report saved to: ${REPORT_FILE}"
  
  # Add recommendations to report
  cat >> "${REPORT_FILE}" <<EOF

## Recommendations

${ERRORS} domains failed to resolve correctly. Based on the results, we recommend:

1. **Configure DNS Records**: Set up proper A records for all domains to point to ${SERVER_IP}
2. **Verify Network Configuration**: Ensure firewall rules allow traffic on ports 80 and 443
3. **For Local Testing**: Add the following entries to your local hosts file:
   \`\`\`
$(for domain in "${DOMAINS_TO_CHECK[@]}"; do echo "${SERVER_IP} ${domain}"; done)
   \`\`\`

Remember that proper DNS resolution is essential for Traefik routing to work correctly.
EOF
fi

# Return appropriate exit code
if [[ ${ERRORS} -gt 0 ]]; then
  exit 1
elif [[ ${WARNINGS} -gt 0 ]]; then
  exit 2
else
  exit 0
fi
