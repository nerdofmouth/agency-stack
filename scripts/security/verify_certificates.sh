#!/bin/bash
# verify_certificates.sh - Verify TLS certificates for AgencyStack
# https://stack.nerdofmouth.com
#
# This script verifies TLS certificates for all domains in AgencyStack
# It checks expiration dates, chain validation, and proper configuration
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
CLIENTS_DIR="${CONFIG_DIR}/clients"
LOG_DIR="/var/log/agency_stack"
CERT_LOG="${LOG_DIR}/cert_checks.log"
OUTPUT_JSON="${ROOT_DIR}/cert_status.json"
VERBOSE=false
CLIENT_ID=""

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Certificate Verification${NC}"
echo -e "======================================="

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Usage: $0 [--verbose] [--client-id <client_id>]"
      exit 1
      ;;
  esac
done

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$CERT_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CERT_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  fi
}

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
  echo -e "${RED}Error: openssl is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is not installed. Please install it first.${NC}"
  exit 1
fi

# Function to check SSL certificate status
check_certificate() {
  local domain="$1"
  
  echo -e "${BLUE}Checking certificate for ${CYAN}${domain}${NC}"
  
  # Check if domain resolves
  if ! host "$domain" &>/dev/null; then
    echo -e "  ${RED}✗ Domain does not resolve${NC}"
    CERT_STATUS="Not Found"
    EXPIRATION="N/A"
    DAYS_LEFT=-1
    ISSUER="N/A"
    VALID_CHAIN=false
    return
  fi
  
  # Get certificate data
  local cert_data
  cert_data=$(echo | openssl s_client -servername "$domain" -connect "$domain":443 -showcerts 2>/dev/null)
  
  if [ $? -ne 0 ]; then
    echo -e "  ${RED}✗ Could not connect to $domain:443${NC}"
    CERT_STATUS="Not Available"
    EXPIRATION="N/A"
    DAYS_LEFT=-1
    ISSUER="N/A"
    VALID_CHAIN=false
    return
  fi
  
  # Extract certificate information
  local cert
  cert=$(echo "$cert_data" | openssl x509 -text 2>/dev/null)
  
  if [ -z "$cert" ]; then
    echo -e "  ${RED}✗ No certificate found for $domain${NC}"
    CERT_STATUS="Not Found"
    EXPIRATION="N/A"
    DAYS_LEFT=-1
    ISSUER="N/A"
    VALID_CHAIN=false
    return
  fi
  
  # Get expiration date
  local expiry
  expiry=$(echo "$cert" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  
  # Calculate days left
  local expiry_date
  expiry_date=$(date -d "$expiry" +%s)
  local current_date
  current_date=$(date +%s)
  local seconds_left
  seconds_left=$((expiry_date - current_date))
  local days_left
  days_left=$((seconds_left / 86400))
  
  # Get issuer
  local issuer
  issuer=$(echo "$cert" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//' | sed 's/^[ \t]*//')
  
  # Simplify issuer name
  if [[ "$issuer" == *"Let's Encrypt"* ]]; then
    issuer="Let's Encrypt"
  elif [[ "$issuer" == *"COMODO"* || "$issuer" == *"Sectigo"* ]]; then
    issuer="Sectigo"
  elif [[ "$issuer" == *"Amazon"* ]]; then
    issuer="Amazon"
  elif [[ "$issuer" == *"DigiCert"* ]]; then
    issuer="DigiCert"
  fi
  
  # Validate certificate chain
  local chain_verification
  chain_verification=$(echo "$cert_data" | openssl verify -CApath /etc/ssl/certs 2>&1)
  local valid_chain=false
  
  if [[ "$chain_verification" == *"OK"* ]]; then
    valid_chain=true
  fi
  
  # Determine status
  local status
  if [ $days_left -lt 0 ]; then
    status="Expired"
    echo -e "  ${RED}✗ Certificate expired ${BOLD}$((days_left * -1))${NC}${RED} days ago${NC}"
  elif [ $days_left -lt 7 ]; then
    status="Critical"
    echo -e "  ${RED}⚠ Certificate expires in ${BOLD}$days_left${NC}${RED} days${NC}"
  elif [ $days_left -lt 30 ]; then
    status="Expiring Soon"
    echo -e "  ${YELLOW}⚠ Certificate expires in ${BOLD}$days_left${NC}${YELLOW} days${NC}"
  else
    status="Valid"
    echo -e "  ${GREEN}✓ Certificate valid for ${BOLD}$days_left${NC}${GREEN} more days${NC}"
  fi
  
  if [ "$valid_chain" = true ]; then
    echo -e "  ${GREEN}✓ Certificate chain is valid${NC}"
  else
    echo -e "  ${RED}✗ Certificate chain is invalid${NC}"
    status="Invalid Chain"
  fi
  
  echo -e "  ${BLUE}ℹ Issued by: ${CYAN}$issuer${NC}"
  
  # Format expiration date nicely
  local formatted_expiry
  formatted_expiry=$(date -d "$expiry" "+%Y-%m-%d")
  
  # Set global variables for return
  CERT_STATUS="$status"
  EXPIRATION="$formatted_expiry"
  DAYS_LEFT="$days_left"
  ISSUER="$issuer"
  VALID_CHAIN="$valid_chain"
  
  # Log the check
  log "Checked $domain - Status: $status, Expires: $formatted_expiry, Days left: $days_left, Issuer: $issuer, Valid chain: $valid_chain"
}

# Initialize JSON output
echo "[" > "$OUTPUT_JSON"

# Get list of domains to check
declare -a DOMAINS

if [ -n "$CLIENT_ID" ]; then
  # Get domains for a specific client
  if [ -f "${CLIENTS_DIR}/${CLIENT_ID}/client.env" ]; then
    source "${CLIENTS_DIR}/${CLIENT_ID}/client.env"
    CLIENT_DOMAIN=${CLIENT_DOMAIN:-"example.com"}
    
    # Add common subdomains
    DOMAINS+=("dashboard.${CLIENT_DOMAIN}")
    DOMAINS+=("wordpress.${CLIENT_DOMAIN}")
    DOMAINS+=("erp.${CLIENT_DOMAIN}")
    DOMAINS+=("mail.${CLIENT_DOMAIN}")
    DOMAINS+=("auth.${CLIENT_DOMAIN}")
    DOMAINS+=("monitoring.${CLIENT_DOMAIN}")
    
    echo -e "${BLUE}Checking certificates for client ${CYAN}${CLIENT_ID}${NC} (domain: ${CYAN}${CLIENT_DOMAIN}${NC})"
  else
    echo -e "${RED}Error: Client ${CLIENT_ID} not found${NC}"
    exit 1
  fi
else
  # Get all domains from traefik configuration
  if command -v docker &> /dev/null && docker ps | grep -q "traefik"; then
    echo -e "${BLUE}Retrieving domains from Traefik...${NC}"
    
    TRAEFIK_DOMAINS=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null | grep -o "Host(\`[^)]*" | sed "s/Host(\`//g")
    
    # Add all domains
    for domain in $TRAEFIK_DOMAINS; do
      DOMAINS+=("$domain")
    done
  fi
  
  # If no domains found in Traefik, use default domains
  if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No domains found in Traefik configuration, using default domains${NC}"
    DOMAINS+=("dashboard.example.com")
    DOMAINS+=("wordpress.example.com")
    DOMAINS+=("erp.example.com")
    DOMAINS+=("mail.example.com")
    DOMAINS+=("auth.example.com")
    DOMAINS+=("monitoring.example.com")
  fi
fi

# Check certificates for all domains
TOTAL_DOMAINS=${#DOMAINS[@]}
VALID_CERTS=0
EXPIRING_CERTS=0
INVALID_CERTS=0
FIRST=true

for domain in "${DOMAINS[@]}"; do
  # Check certificate
  check_certificate "$domain"
  
  # Add to JSON (comma for all but first entry)
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$OUTPUT_JSON"
  fi
  
  # Add domain entry to JSON
  cat << EOF >> "$OUTPUT_JSON"
  {
    "domain": "$domain",
    "status": "$CERT_STATUS",
    "expiration": "$EXPIRATION",
    "daysLeft": $DAYS_LEFT,
    "issuer": "$ISSUER",
    "validChain": $VALID_CHAIN
  }
EOF
  
  # Update counts
  if [ "$CERT_STATUS" = "Valid" ]; then
    VALID_CERTS=$((VALID_CERTS + 1))
  elif [ "$CERT_STATUS" = "Expiring Soon" ]; then
    EXPIRING_CERTS=$((EXPIRING_CERTS + 1))
  else
    INVALID_CERTS=$((INVALID_CERTS + 1))
  fi
done

# Close JSON array
echo -e "\n]" >> "$OUTPUT_JSON"

# Print summary
echo -e "\n${BLUE}${BOLD}Certificate Verification Summary:${NC}"
echo -e "  ${GREEN}✓ Valid:${NC} $VALID_CERTS"
echo -e "  ${YELLOW}⚠ Expiring Soon:${NC} $EXPIRING_CERTS"
echo -e "  ${RED}✗ Invalid/Expired:${NC} $INVALID_CERTS"
echo -e "  ${BLUE}ℹ Total Domains:${NC} $TOTAL_DOMAINS"

# Create summary JSON file
cat << EOF > "${ROOT_DIR}/cert_summary.json"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validCerts": $VALID_CERTS,
  "expiringCerts": $EXPIRING_CERTS,
  "invalidCerts": $INVALID_CERTS,
  "totalDomains": $TOTAL_DOMAINS
}
EOF

# Print instructions
echo -e "\n${BLUE}Detailed certificate status has been saved to:${NC}"
echo -e "  ${CYAN}${OUTPUT_JSON}${NC}"
echo -e "${BLUE}Summary has been saved to:${NC}"
echo -e "  ${CYAN}${ROOT_DIR}/cert_summary.json${NC}"
echo -e "${BLUE}Log file:${NC}"
echo -e "  ${CYAN}${CERT_LOG}${NC}"

# Final message
if [ $INVALID_CERTS -gt 0 ]; then
  echo -e "\n${RED}${BOLD}Action Required:${NC} Some certificates are invalid or expired."
  echo -e "Run 'make renew-certificates' to attempt renewal."
elif [ $EXPIRING_CERTS -gt 0 ]; then
  echo -e "\n${YELLOW}${BOLD}Warning:${NC} Some certificates are expiring soon."
  echo -e "Consider running 'make renew-certificates' to renew them."
else
  echo -e "\n${GREEN}${BOLD}All certificates are valid.${NC}"
fi

exit 0
