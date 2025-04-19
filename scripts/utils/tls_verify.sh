#!/bin/bash
# tls_verify.sh - Verify TLS configuration and certificate status for agency stack components
# Part of the AgencyStack Alpha consolidation for client-ready TLS/SSO

# Exit on error
set -e
set -o pipefail

# Source utility functions
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/utils/common.sh" || { echo "Error: Could not source common utility functions" >&2; exit 1; }
source "${ROOT_DIR}/scripts/utils/logging.sh" || { echo "Error: Could not source logging utility functions" >&2; exit 1; }

# Initialize log file
COMPONENTS_LOG_DIR="/var/log/agency_stack/components"
mkdir -p "${COMPONENTS_LOG_DIR}"
LOG_FILE="${COMPONENTS_LOG_DIR}/tls_verify.log"

# Default domain and options
DOMAIN="${DOMAIN:-}"
VERBOSE="${VERBOSE:-false}"
CHECK_ALL="${CHECK_ALL:-true}"
TIMEOUT=10
MIN_WARN_DAYS=30
MIN_CRITICAL_DAYS=15

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Verify TLS configuration and certificates for AgencyStack components"
  echo ""
  echo "Options:"
  echo "  --domain DOMAIN       Domain to check (required if CHECK_ALL=false)"
  echo "  --verbose             Enable verbose output"
  echo "  --check-all           Check all domains in component registry (default: true)"
  echo "  --help                Display this help message"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      CHECK_ALL=false
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --check-all)
      CHECK_ALL=true
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Verify domain if CHECK_ALL is false
if [[ "${CHECK_ALL}" == "false" && -z "${DOMAIN}" ]]; then
  log_error "Domain is required when CHECK_ALL is false"
  print_usage
  exit 1
fi

# Function to check TLS configuration for a domain
check_tls() {
  local domain="$1"
  local service_name="${2:-Unknown}"
  local error_count=0
  
  log_info "Checking TLS for ${service_name} (${domain})..."
  
  # Check HTTP to HTTPS redirect
  local redirect_status
  redirect_status=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "http://${domain}" || echo "failed")
  
  if [[ "${redirect_status}" == "failed" ]]; then
    log_warning "HTTP connection to ${domain} failed - check DNS or firewall settings"
    error_count=$((error_count+1))
  elif [[ "${redirect_status}" -eq 301 || "${redirect_status}" -eq 302 || "${redirect_status}" -eq 308 ]]; then
    log_success "HTTP to HTTPS redirect is working for ${domain}"
  else
    log_warning "HTTP to HTTPS redirect not detected for ${domain} (status: ${redirect_status})"
    error_count=$((error_count+1))
  fi
  
  # Check TLS certificate validity
  local cert_status
  cert_status=$(curl -s -o /dev/null -w "%{ssl_verify_result}" -m ${TIMEOUT} "https://${domain}" || echo "failed")
  
  if [[ "${cert_status}" == "failed" ]]; then
    log_error "HTTPS connection to ${domain} failed - check DNS, TLS configuration, or firewall settings"
    error_count=$((error_count+1))
  elif [[ "${cert_status}" -eq 0 ]]; then
    log_success "TLS certificate is valid for ${domain}"
    
    # Check certificate expiration
    local cert_expiry
    cert_expiry=$(echo | openssl s_client -servername "${domain}" -connect "${domain}:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    if [[ -n "${cert_expiry}" ]]; then
      local expiry_seconds=$(date -d "${cert_expiry}" +%s)
      local current_seconds=$(date +%s)
      local seconds_left=$((expiry_seconds - current_seconds))
      local days_left=$((seconds_left / 86400))
      
      if [[ "${days_left}" -lt "${MIN_CRITICAL_DAYS}" ]]; then
        log_error "TLS certificate for ${domain} will expire in ${days_left} days (on ${cert_expiry})"
        error_count=$((error_count+1))
      elif [[ "${days_left}" -lt "${MIN_WARN_DAYS}" ]]; then
        log_warning "TLS certificate for ${domain} will expire in ${days_left} days (on ${cert_expiry})"
      else
        log_info "TLS certificate for ${domain} is valid for ${days_left} more days (expires on ${cert_expiry})"
      fi
    else
      log_warning "Could not determine certificate expiration date for ${domain}"
      error_count=$((error_count+1))
    fi
    # Get certificate details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
      local cert_info
      cert_info=$(echo | openssl s_client -servername "${domain}" -connect "${domain}:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -fingerprint -serial)
      log_info "Certificate details for ${domain}:\n${cert_info}"
      
      # Check cipher strength
      local cipher_info
      cipher_info=$(echo | openssl s_client -servername "${domain}" -connect "${domain}:443" 2>/dev/null | grep "Protocol\|Cipher")
      log_info "Cipher information:\n${cipher_info}"
      
      # Check for weak ciphers (TLS 1.0/1.1)
      if echo "${cipher_info}" | grep -q "TLSv1\.0\|TLSv1\.1"; then
        log_warning "Weak TLS protocol version detected for ${domain}"
        error_count=$((error_count+1))
      fi
    fi
  else
    log_error "TLS certificate validation failed for ${domain} (status: ${cert_status})"
    error_count=$((error_count+1))
  fi
  
  return $error_count
}

# Check specific domain
if [[ "${CHECK_ALL}" == "false" ]]; then
  log_info "Checking TLS configuration for ${DOMAIN}..."
  check_tls "${DOMAIN}" "Specified Service"
  RESULT=$?
  if [[ $RESULT -eq 0 ]]; then
    log_success "TLS configuration for ${DOMAIN} passed all checks"
    exit 0
  else
    log_error "TLS configuration for ${DOMAIN} has ${RESULT} issue(s)"
    exit 1
  fi
fi

# Check all domains from component registry
REGISTRY_FILE="${ROOT_DIR}/component_registry.json"
if [[ ! -f "${REGISTRY_FILE}" ]]; then
  log_error "Component registry file not found: ${REGISTRY_FILE}"
  exit 1
fi

# Process JSON registry to extract domains with TLS
log_info "Checking TLS for all components in registry..."
COMPONENTS=$(grep -o '"name": "[^"]*"' "${REGISTRY_FILE}" | cut -d '"' -f 4)
DOMAINS=$(grep -o '"url": "[^"]*"' "${REGISTRY_FILE}" | cut -d '"' -f 4 | grep -E '^https://' | sed 's|https://||')

if [[ -z "${DOMAINS}" ]]; then
  log_warning "No HTTPS domains found in component registry"
  exit 0
fi

# Track overall results
TOTAL_DOMAINS=0
FAILED_DOMAINS=0

# Check each domain
for domain in ${DOMAINS}; do
  # Find component name for this domain
  component=$(grep -B 3 "\"url\": \"https://${domain}\"" "${REGISTRY_FILE}" | grep -o '"name": "[^"]*"' | head -1 | cut -d '"' -f 4)
  TOTAL_DOMAINS=$((TOTAL_DOMAINS+1))
  
  check_tls "${domain}" "${component}"
  RESULT=$?
  if [[ $RESULT -ne 0 ]]; then
    FAILED_DOMAINS=$((FAILED_DOMAINS+1))
  fi
  echo ""
done

# Report final results
if [[ $FAILED_DOMAINS -eq 0 ]]; then
  log_success "All ${TOTAL_DOMAINS} domains passed TLS verification"
  exit 0
else
  log_error "${FAILED_DOMAINS} of ${TOTAL_DOMAINS} domains failed TLS verification"
  exit 1
fi
