#!/bin/bash
# verify_authentication.sh - Verify authentication configuration for AgencyStack
# https://stack.nerdofmouth.com
#
# This script verifies authentication setup for all services in AgencyStack
# It checks for SSO configuration, middleware setup, and security headers
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
AUTH_LOG="${LOG_DIR}/auth_checks.log"
OUTPUT_JSON="${ROOT_DIR}/auth_status.json"
VERBOSE=false
CLIENT_ID=""

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Authentication Verification${NC}"
echo -e "==========================================="

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
touch "$AUTH_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$AUTH_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  fi
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  echo -e "${RED}Error: curl is not installed. Please install it first.${NC}"
  exit 1
fi

# Function to check service authentication
check_service_auth() {
  local service="$1"
  local domain="$2"
  local client_id="$3"
  
  echo -e "${BLUE}Checking authentication for ${CYAN}${service}${NC} (${domain})"
  
  # Default values
  local sso_enabled=false
  local middleware="None"
  local auth_method="None"
  local status="Unsecured"
  
  # Check if domain resolves
  if ! host "$domain" &>/dev/null; then
    echo -e "  ${YELLOW}⚠ Domain does not resolve${NC}"
    status="Not Available"
  else
    # Check for HTTP authentication headers
    local headers
    headers=$(curl -s -I "https://${domain}" 2>/dev/null)
    
    # Check for Keycloak cookie
    if [[ "$headers" == *"Set-Cookie: KEYCLOAK_"* ]]; then
      sso_enabled=true
      middleware="Keycloak Cookie"
      auth_method="Keycloak SSO"
      status="Secured"
      echo -e "  ${GREEN}✓ Keycloak SSO detected${NC}"
    # Check for Traefik forward auth
    elif [[ "$headers" == *"X-Forwarded-User"* ]] || curl -s "https://${domain}" 2>/dev/null | grep -q "keycloak"; then
      sso_enabled=true
      middleware="Forward Auth"
      auth_method="Keycloak SSO"
      status="Secured"
      echo -e "  ${GREEN}✓ Traefik Forward Auth detected${NC}"
    # Check for basic auth
    elif [[ "$headers" == *"WWW-Authenticate: Basic"* ]]; then
      sso_enabled=false
      middleware="Basic Auth"
      auth_method="Basic Authentication"
      status="Partial"
      echo -e "  ${YELLOW}⚠ Basic authentication detected (not SSO)${NC}"
    # Check for other auth headers
    elif [[ "$headers" == *"Authorization"* ]] || [[ "$headers" == *"Auth"* ]]; then
      sso_enabled=false
      middleware="Custom Auth"
      auth_method="Custom Authentication"
      status="Partial"
      echo -e "  ${YELLOW}⚠ Custom authentication detected (not SSO)${NC}"
    else
      echo -e "  ${RED}✗ No authentication detected${NC}"
    fi
    
    # Check for security headers
    if [[ "$headers" == *"Strict-Transport-Security"* ]]; then
      echo -e "  ${GREEN}✓ HSTS header detected${NC}"
    else
      echo -e "  ${YELLOW}⚠ Missing HSTS header${NC}"
      if [ "$status" = "Secured" ]; then
        status="Partial"
      fi
    fi
    
    if [[ "$headers" == *"Content-Security-Policy"* ]]; then
      echo -e "  ${GREEN}✓ CSP header detected${NC}"
    else
      echo -e "  ${YELLOW}⚠ Missing CSP header${NC}"
      if [ "$status" = "Secured" ]; then
        status="Partial"
      fi
    fi
    
    if [[ "$headers" == *"X-Content-Type-Options"* ]]; then
      echo -e "  ${GREEN}✓ X-Content-Type-Options header detected${NC}"
    else
      echo -e "  ${YELLOW}⚠ Missing X-Content-Type-Options header${NC}"
    fi
  fi
  
  # Set global variables for return
  SERVICE_NAME="$service"
  SSO_ENABLED="$sso_enabled"
  MIDDLEWARE="$middleware"
  AUTH_METHOD="$auth_method"
  AUTH_STATUS="$status"
  
  # Log the check
  log "Checked $service ($domain) - SSO: $sso_enabled, Middleware: $middleware, Method: $auth_method, Status: $status"
}

# Check Traefik configuration for middleware
check_traefik_middleware() {
  local service="$1"
  
  # Default values
  local middleware_configured=false
  local middleware_type="None"
  
  # Check if traefik is running
  if ! command -v docker &> /dev/null || ! docker ps | grep -q "traefik"; then
    echo -e "  ${YELLOW}⚠ Traefik not running, cannot check middleware configuration${NC}"
    return
  fi
  
  # Get middleware configuration
  local middleware_config
  middleware_config=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null)
  
  if [ -z "$middleware_config" ]; then
    echo -e "  ${YELLOW}⚠ No Traefik middleware configuration found${NC}"
    return
  fi
  
  # Check for service-specific middleware
  if echo "$middleware_config" | grep -q "${service}.*forwardAuth"; then
    middleware_configured=true
    middleware_type="Forward Auth"
    echo -e "  ${GREEN}✓ ForwardAuth middleware configured for $service${NC}"
  elif echo "$middleware_config" | grep -q "${service}.*basicAuth"; then
    middleware_configured=true
    middleware_type="Basic Auth"
    echo -e "  ${YELLOW}⚠ BasicAuth middleware configured for $service (not SSO)${NC}"
  elif echo "$middleware_config" | grep -q "${service}-auth" || echo "$middleware_config" | grep -q "${service}_auth"; then
    middleware_configured=true
    middleware_type="Custom Auth"
    echo -e "  ${YELLOW}⚠ Custom middleware configured for $service${NC}"
  else
    echo -e "  ${RED}✗ No middleware configured for $service${NC}"
  fi
  
  # Update global middleware variable if found in Traefik config
  if [ "$middleware_configured" = true ]; then
    MIDDLEWARE="$middleware_type (Traefik)"
  fi
}

# Initialize JSON output
echo "[" > "$OUTPUT_JSON"

# Get list of services to check
declare -a SERVICES

# Define the services to check based on CLIENT_ID
if [ -n "$CLIENT_ID" ]; then
  # Get domains for a specific client
  if [ -f "${CLIENTS_DIR}/${CLIENT_ID}/client.env" ]; then
    source "${CLIENTS_DIR}/${CLIENT_ID}/client.env"
    CLIENT_DOMAIN=${CLIENT_DOMAIN:-"example.com"}
    
    # Add common services
    SERVICES+=("WordPress|wordpress.${CLIENT_DOMAIN}|${CLIENT_ID}")
    SERVICES+=("ERPNext|erp.${CLIENT_DOMAIN}|${CLIENT_ID}")
    SERVICES+=("Mailu|mail.${CLIENT_DOMAIN}|${CLIENT_ID}")
    SERVICES+=("Keycloak|auth.${CLIENT_DOMAIN}|${CLIENT_ID}")
    SERVICES+=("Grafana|monitoring.${CLIENT_DOMAIN}|${CLIENT_ID}")
    SERVICES+=("Dashboard|dashboard.${CLIENT_DOMAIN}|${CLIENT_ID}")
    
    echo -e "${BLUE}Checking authentication for client ${CYAN}${CLIENT_ID}${NC} (domain: ${CYAN}${CLIENT_DOMAIN}${NC})"
  else
    echo -e "${RED}Error: Client ${CLIENT_ID} not found${NC}"
    exit 1
  fi
else
  # Get all services from traefik configuration
  if command -v docker &> /dev/null && docker ps | grep -q "traefik"; then
    echo -e "${BLUE}Retrieving services from Traefik...${NC}"
    
    TRAEFIK_ROUTES=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null | grep -B 1 "Host(\`" | grep -v "Host(\`" | grep -o "[a-zA-Z0-9_-]*@")
    TRAEFIK_DOMAINS=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null | grep -o "Host(\`[^)]*" | sed "s/Host(\`//g")
    
    # Combine service names with domains
    i=0
    for route in $TRAEFIK_ROUTES; do
      service_name=${route%@}
      
      # Convert to friendly names
      if [[ "$service_name" == *"wordpress"* ]]; then
        service_name="WordPress"
      elif [[ "$service_name" == *"erpnext"* ]]; then
        service_name="ERPNext"
      elif [[ "$service_name" == *"keycloak"* ]]; then
        service_name="Keycloak"
      elif [[ "$service_name" == *"mailu"* ]]; then
        service_name="Mailu"
      elif [[ "$service_name" == *"grafana"* ]]; then
        service_name="Grafana"
      elif [[ "$service_name" == *"dashboard"* ]]; then
        service_name="Dashboard"
      elif [[ "$service_name" == *"traefik"* ]]; then
        service_name="Traefik Dashboard"
      fi
      
      # Get domain from index
      domain=$(echo "$TRAEFIK_DOMAINS" | sed -n "$((i+1))p")
      if [ -n "$domain" ]; then
        # Try to extract client_id from the domain
        client_id=""
        for cid in $(ls "${CLIENTS_DIR}" 2>/dev/null); do
          if [ -f "${CLIENTS_DIR}/${cid}/client.env" ]; then
            source "${CLIENTS_DIR}/${cid}/client.env"
            if [[ "$domain" == *"${CLIENT_DOMAIN}"* ]]; then
              client_id="$cid"
              break
            fi
          fi
        done
        
        SERVICES+=("${service_name}|${domain}|${client_id}")
      fi
      
      i=$((i+1))
    done
  fi
  
  # If no services found in Traefik, use default services
  if [ ${#SERVICES[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No services found in Traefik configuration, using default services${NC}"
    SERVICES+=("WordPress|wordpress.example.com|")
    SERVICES+=("ERPNext|erp.example.com|")
    SERVICES+=("Mailu|mail.example.com|")
    SERVICES+=("Keycloak|auth.example.com|")
    SERVICES+=("Grafana|monitoring.example.com|")
    SERVICES+=("Dashboard|dashboard.example.com|")
  fi
fi

# Check authentication for all services
TOTAL_SERVICES=${#SERVICES[@]}
SSO_SERVICES=0
PARTIAL_SERVICES=0
UNSECURED_SERVICES=0
FIRST=true

for service_info in "${SERVICES[@]}"; do
  # Split service info
  IFS='|' read -ra parts <<< "$service_info"
  service="${parts[0]}"
  domain="${parts[1]}"
  client_id="${parts[2]}"
  
  # Check service authentication
  check_service_auth "$service" "$domain" "$client_id"
  
  # Check Traefik middleware configuration
  check_traefik_middleware "$service"
  
  # Add to JSON (comma for all but first entry)
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$OUTPUT_JSON"
  fi
  
  # Add service entry to JSON
  cat << EOF >> "$OUTPUT_JSON"
  {
    "service": "$SERVICE_NAME",
    "domain": "$domain",
    "clientId": "$client_id",
    "ssoEnabled": $SSO_ENABLED,
    "middleware": "$MIDDLEWARE",
    "authMethod": "$AUTH_METHOD",
    "status": "$AUTH_STATUS"
  }
EOF
  
  # Update counts
  if [ "$AUTH_STATUS" = "Secured" ]; then
    SSO_SERVICES=$((SSO_SERVICES + 1))
  elif [ "$AUTH_STATUS" = "Partial" ]; then
    PARTIAL_SERVICES=$((PARTIAL_SERVICES + 1))
  elif [ "$AUTH_STATUS" = "Unsecured" ]; then
    UNSECURED_SERVICES=$((UNSECURED_SERVICES + 1))
  fi
done

# Close JSON array
echo -e "\n]" >> "$OUTPUT_JSON"

# Print summary
echo -e "\n${BLUE}${BOLD}Authentication Verification Summary:${NC}"
echo -e "  ${GREEN}✓ SSO Secured:${NC} $SSO_SERVICES"
echo -e "  ${YELLOW}⚠ Partially Secured:${NC} $PARTIAL_SERVICES"
echo -e "  ${RED}✗ Unsecured:${NC} $UNSECURED_SERVICES"
echo -e "  ${BLUE}ℹ Total Services:${NC} $TOTAL_SERVICES"

# Create summary JSON file
cat << EOF > "${ROOT_DIR}/auth_summary.json"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "ssoServices": $SSO_SERVICES,
  "partialServices": $PARTIAL_SERVICES,
  "unsecuredServices": $UNSECURED_SERVICES,
  "totalServices": $TOTAL_SERVICES
}
EOF

# Print instructions
echo -e "\n${BLUE}Detailed authentication status has been saved to:${NC}"
echo -e "  ${CYAN}${OUTPUT_JSON}${NC}"
echo -e "${BLUE}Summary has been saved to:${NC}"
echo -e "  ${CYAN}${ROOT_DIR}/auth_summary.json${NC}"
echo -e "${BLUE}Log file:${NC}"
echo -e "  ${CYAN}${AUTH_LOG}${NC}"

# Final message
if [ $UNSECURED_SERVICES -gt 0 ]; then
  echo -e "\n${RED}${BOLD}Action Required:${NC} Some services are unsecured."
  echo -e "Run 'make verify-auth --fix' to attempt to secure them."
elif [ $PARTIAL_SERVICES -gt 0 ]; then
  echo -e "\n${YELLOW}${BOLD}Warning:${NC} Some services are only partially secured."
  echo -e "Consider configuring SSO for all services."
else
  echo -e "\n${GREEN}${BOLD}All services are properly secured with SSO.${NC}"
fi

exit 0
