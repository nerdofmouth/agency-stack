#!/bin/bash
# verify_dns.sh - Verify DNS configuration for AgencyStack
# https://stack.nerdofmouth.com
#
# This script verifies DNS configuration for AgencyStack components
# and provides recommendations for DNS setup.
#
# Author: AgencyStack Team
# Date: 2025-04-10

# Source the DNS checker utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/common.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log directory
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/dns-check-$(date +%Y%m%d-%H%M%S).log"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
GENERATE_REPORT=false
FIX_HOSTS=false
DIRECT_CHECK=false

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
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
    --fix-hosts)
      FIX_HOSTS=true
      shift
      ;;
    --generate-report)
      GENERATE_REPORT=true
      shift
      ;;
    --direct-check)
      DIRECT_CHECK=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --domain DOMAIN       Domain to check (default: value from env or localhost)"
      echo "  --client-id ID        Client ID (default: default)"
      echo "  --fix-hosts           Add missing entries to /etc/hosts (requires sudo)"
      echo "  --generate-report     Generate a detailed DNS report"
      echo "  --direct-check        Test direct component access (bypassing Traefik)"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

# If domain is not provided, try to detect it
if [ "$DOMAIN" == "localhost" ]; then
  # Check if config.env exists and get domain from there
  if [ -f "/opt/agency_stack/config.env" ]; then
    source "/opt/agency_stack/config.env"
    if [ -n "$PRIMARY_DOMAIN" ]; then
      DOMAIN="$PRIMARY_DOMAIN"
      log "${BLUE}Using domain from config: ${DOMAIN}${NC}"
    fi
  fi
fi

log "${BLUE}🔍 AgencyStack DNS Verification${NC}"
log "====================================="
log "Date: $(date)"
log "Domain: ${DOMAIN}"
log "Client ID: ${CLIENT_ID}"
log ""

# Run the comprehensive DNS checker
DNS_CHECK_ARGS=""
if [ "$GENERATE_REPORT" == "true" ]; then
  DNS_CHECK_ARGS="$DNS_CHECK_ARGS --generate-report"
fi

if [ "$FIX_HOSTS" == "true" ]; then
  DNS_CHECK_ARGS="$DNS_CHECK_ARGS --fix-hosts"
fi

log "${BLUE}Running DNS configuration check...${NC}"
"${SCRIPT_DIR}/utils/dns_checker.sh" --domain "$DOMAIN" --client-id "$CLIENT_ID" $DNS_CHECK_ARGS
DNS_CHECK_STATUS=$?

# If direct component check is requested, perform additional tests
if [ "$DIRECT_CHECK" == "true" ]; then
  log ""
  log "${BLUE}Testing direct component access...${NC}"
  log "This will bypass Traefik and test components directly on their exposed ports."
  log ""
  
  # Get the server IP
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  # Test dashboard direct access
  if [ -d "/opt/agency_stack/clients/${CLIENT_ID}/dashboard" ]; then
    log "${YELLOW}Testing dashboard direct access...${NC}"
    DASHBOARD_PORT=$(docker ps | grep dashboard | grep -oP '\d+->80' | cut -d'-' -f1 || echo "3001")
    
    if curl -s "http://localhost:${DASHBOARD_PORT}" | grep -q "html"; then
      log "${GREEN}✅ Dashboard is directly accessible at: http://${SERVER_IP}:${DASHBOARD_PORT}${NC}"
    else
      log "${RED}❌ Dashboard is not directly accessible at: http://${SERVER_IP}:${DASHBOARD_PORT}${NC}"
    fi
  fi
  
  # Test other components as needed
  # ...
fi

log ""
log "${BLUE}DNS verification results:${NC}"
if [ $DNS_CHECK_STATUS -eq 0 ]; then
  log "${GREEN}✅ DNS verification passed successfully!${NC}"
elif [ $DNS_CHECK_STATUS -eq 2 ]; then
  log "${YELLOW}⚠️ DNS verification completed with warnings${NC}"
  log "Some domains may have incorrect or missing DNS entries."
  log "Please check the detailed report for recommendations."
else
  log "${RED}❌ DNS verification failed${NC}"
  log "Critical DNS configuration issues were found."
  log "Please check the detailed report for recommendations."
fi

log ""
log "For proper access to AgencyStack components, ensure:"
log "1. DNS records are properly configured to point to ${SERVER_IP}"
log "2. Traefik is correctly configured and running"
log "3. Components are registered with Traefik using the correct domain names"
log ""
log "Detailed results saved to: $LOG_FILE"

if [ "$GENERATE_REPORT" == "true" ]; then
  REPORT_FILE="/var/log/agency_stack/dns/dns_report.md"
  if [ -f "$REPORT_FILE" ]; then
    log "Comprehensive DNS report: $REPORT_FILE"
  fi
fi

# Return appropriate exit code
exit $DNS_CHECK_STATUS
