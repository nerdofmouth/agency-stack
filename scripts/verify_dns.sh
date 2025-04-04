#!/bin/bash
# verify_dns.sh - Verify DNS configuration for AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log directory
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/dns-check-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if dig is installed
if ! command -v dig &> /dev/null; then
  log "${YELLOW}Installing dig (dnsutils)...${NC}"
  apt-get update -qq && apt-get install -y dnsutils
fi

# Function to check a DNS record
check_dns_record() {
  local domain="$1"
  local record_type="$2"
  local expected_value="$3"
  local description="$4"
  
  log "${BLUE}Checking ${record_type} record for ${domain}...${NC}"
  
  # Get the record value
  local result=$(dig +short "$record_type" "$domain" | tr -d '"' | tr -d '\n')
  
  if [ -z "$result" ]; then
    log "${RED}❌ No ${record_type} record found for ${domain}${NC}"
    log "   Expected: ${expected_value}"
    log "   Found: <none>"
    return 1
  fi
  
  # For TXT records, we just check if it contains the expected value
  if [ "$record_type" == "TXT" ]; then
    if echo "$result" | grep -q "$expected_value"; then
      log "${GREEN}✅ ${description} (${record_type}) is properly configured${NC}"
      log "   Expected to contain: ${expected_value}"
      log "   Found: ${result}"
      return 0
    else
      log "${RED}❌ ${description} (${record_type}) is not properly configured${NC}"
      log "   Expected to contain: ${expected_value}"
      log "   Found: ${result}"
      return 1
    fi
  fi
  
  # For A and MX records, we check for an exact match or if expected_value is "ANY" then any value is ok
  if [ "$expected_value" == "ANY" ] || [ "$result" == "$expected_value" ]; then
    log "${GREEN}✅ ${description} (${record_type}) is properly configured${NC}"
    log "   Expected: ${expected_value}"
    log "   Found: ${result}"
    return 0
  else
    log "${RED}❌ ${description} (${record_type}) is not properly configured${NC}"
    log "   Expected: ${expected_value}"
    log "   Found: ${result}"
    return 1
  fi
}

# Main function
main() {
  local domain="$1"
  
  if [ -z "$domain" ]; then
    # Check if config.env exists and get domain from there
    if [ -f "/opt/agency_stack/config.env" ]; then
      source "/opt/agency_stack/config.env"
      domain="$PRIMARY_DOMAIN"
    fi
    
    if [ -z "$domain" ]; then
      echo -e "${RED}Error: No domain specified and PRIMARY_DOMAIN not found in config.env${NC}"
      echo "Usage: $0 <domain>"
      exit 1
    fi
  fi
  
  log "${BLUE}🔍 Verifying DNS configuration for ${domain}${NC}"
  log "==============================================="
  log "$(date)"
  log ""
  
  # Check main domain A record
  check_dns_record "$domain" "A" "ANY" "Main domain IP address"
  
  # Check www subdomain
  check_dns_record "www.$domain" "A" "ANY" "WWW subdomain"
  
  # Check if Mailu is installed
  if [ -d "/opt/agency_stack/config/mailu" ]; then
    log "${BLUE}Checking Mailu DNS configuration...${NC}"
    
    # Get mail domain from Mailu config
    if [ -f "/opt/agency_stack/config/mailu/.env.mail" ]; then
      mail_domain=$(grep "DOMAIN=" "/opt/agency_stack/config/mailu/.env.mail" | cut -d'=' -f2)
      admin_domain=$(grep "ADMIN=" "/opt/agency_stack/config/mailu/.env.mail" | cut -d'=' -f2)
      webmail_domain=$(grep "WEBMAIL=" "/opt/agency_stack/config/mailu/.env.mail" | cut -d'=' -f2)
      
      if [ -n "$mail_domain" ]; then
        # Check mail domain A record
        check_dns_record "$mail_domain" "A" "ANY" "Mail server IP address"
        
        # Check MX record
        check_dns_record "$mail_domain" "MX" "ANY" "Mail server MX record"
        
        # Check SPF record
        check_dns_record "$mail_domain" "TXT" "v=spf1" "SPF record"
        
        # Check DMARC record
        check_dns_record "_dmarc.$mail_domain" "TXT" "v=DMARC1" "DMARC record"
        
        # Check DKIM record if available
        dkim_selector="dkim"
        check_dns_record "${dkim_selector}._domainkey.$mail_domain" "TXT" "v=DKIM1" "DKIM record"
      fi
      
      # Check admin interface
      if [ -n "$admin_domain" ]; then
        check_dns_record "$admin_domain" "A" "ANY" "Admin interface"
      fi
      
      # Check webmail interface
      if [ -n "$webmail_domain" ]; then
        check_dns_record "$webmail_domain" "A" "ANY" "Webmail interface"
      fi
    else
      log "${YELLOW}Mailu config not found, skipping mail DNS checks${NC}"
    fi
  fi
  
  # Check other common subdomains
  for subdomain in "portainer" "drone" "traefik" "dashboard" "api"; do
    check_dns_record "$subdomain.$domain" "A" "ANY" "$subdomain subdomain"
  done
  
  log ""
  log "${GREEN}✅ DNS verification complete!${NC}"
  log "Detailed results saved to: $LOG_FILE"
}

# Run the main function
main "$@"
