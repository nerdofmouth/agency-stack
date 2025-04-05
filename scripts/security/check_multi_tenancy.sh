#!/bin/bash
# check_multi_tenancy.sh - Verify multi-tenancy configuration for AgencyStack
# https://stack.nerdofmouth.com
#
# This script checks multi-tenancy isolation between clients:
# - Network isolation (dedicated Docker networks)
# - Backup separation (client-specific Restic repositories)
# - Log segmentation (per-client log directories)
# - Keycloak realm configuration (per-client realms)
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
SECRETS_DIR="${CONFIG_DIR}/secrets"
LOG_DIR="/var/log/agency_stack"
CLIENT_LOGS_DIR="${LOG_DIR}/clients"
TENANCY_LOG="${LOG_DIR}/multi_tenancy.log"
OUTPUT_JSON="${ROOT_DIR}/multi_tenancy_status.json"
VERBOSE=false
CLIENT_ID=""

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Multi-Tenancy Verification${NC}"
echo -e "=========================================="

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
touch "$TENANCY_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$TENANCY_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  fi
}

# Check if Docker is running
if ! command -v docker &> /dev/null; then
  echo -e "${RED}Error: Docker is not installed. Please install it first.${NC}"
  exit 1
fi

if ! docker info &>/dev/null; then
  echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
  exit 1
fi

# Check network isolation for a client
check_network_isolation() {
  local client="$1"
  echo -e "${BLUE}Checking network isolation for ${CYAN}${client}${NC}"
  
  local client_networks=0
  local network_isolation=false
  
  # Check for client-specific networks
  for network in $(docker network ls --format '{{.Name}}'); do
    if [[ "$network" == *"${client}"* ]]; then
      client_networks=$((client_networks + 1))
      echo -e "  ${GREEN}✓ Found network: ${CYAN}${network}${NC}"
    fi
  done
  
  # Check if we have at least the four expected networks
  if [ $client_networks -ge 4 ]; then
    network_isolation=true
    echo -e "  ${GREEN}✓ Client has proper network isolation ($client_networks networks)${NC}"
  elif [ $client_networks -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Client has some networks but not the expected 4+ ($client_networks found)${NC}"
  else
    echo -e "  ${RED}✗ No client-specific networks found${NC}"
  fi
  
  NETWORK_ISOLATION="$network_isolation"
}

# Check backup separation for a client
check_backup_separation() {
  local client="$1"
  echo -e "${BLUE}Checking backup separation for ${CYAN}${client}${NC}"
  
  local backup_separation=false
  
  # Check for client-specific backup config
  if [ -f "${CLIENTS_DIR}/${client}/backup/config.sh" ]; then
    echo -e "  ${GREEN}✓ Found backup configuration${NC}"
    
    # Check if it's properly configured for client isolation
    if grep -q "CLIENT_ID=\"${client}\"" "${CLIENTS_DIR}/${client}/backup/config.sh" && \
       grep -q "RESTIC_REPOSITORY=\"client-${client}\"" "${CLIENTS_DIR}/${client}/backup/config.sh"; then
      backup_separation=true
      echo -e "  ${GREEN}✓ Backup configuration has proper client isolation${NC}"
    else
      echo -e "  ${YELLOW}⚠ Backup configuration exists but may not be properly isolated${NC}"
    fi
  else
    echo -e "  ${RED}✗ No client-specific backup configuration found${NC}"
  fi
  
  # Check for client-specific backup logs
  if [ -f "${CLIENT_LOGS_DIR}/${client}/backup.log" ]; then
    echo -e "  ${GREEN}✓ Found client-specific backup logs${NC}"
  else
    echo -e "  ${YELLOW}⚠ No client-specific backup logs found${NC}"
  fi
  
  BACKUP_SEPARATION="$backup_separation"
}

# Check log segmentation for a client
check_log_segmentation() {
  local client="$1"
  echo -e "${BLUE}Checking log segmentation for ${CYAN}${client}${NC}"
  
  local log_segmentation=false
  
  # Check for client-specific log directory
  if [ -d "${CLIENT_LOGS_DIR}/${client}" ]; then
    echo -e "  ${GREEN}✓ Found client-specific log directory${NC}"
    
    # Check for expected log files
    local log_files_found=0
    for log_file in "access.log" "error.log" "audit.log" "backup.log"; do
      if [ -f "${CLIENT_LOGS_DIR}/${client}/${log_file}" ]; then
        log_files_found=$((log_files_found + 1))
        echo -e "  ${GREEN}✓ Found log file: ${log_file}${NC}"
      else
        echo -e "  ${YELLOW}⚠ Missing log file: ${log_file}${NC}"
      fi
    done
    
    # Check for service-specific logs
    if [ -d "${CLIENT_LOGS_DIR}/${client}/services" ]; then
      echo -e "  ${GREEN}✓ Found service-specific logs directory${NC}"
      log_files_found=$((log_files_found + 1))
    else
      echo -e "  ${YELLOW}⚠ Missing service-specific logs directory${NC}"
    fi
    
    # If we found at least 3 log files, consider log segmentation enabled
    if [ $log_files_found -ge 3 ]; then
      log_segmentation=true
      echo -e "  ${GREEN}✓ Client has proper log segmentation${NC}"
    else
      echo -e "  ${YELLOW}⚠ Client has partial log segmentation${NC}"
    fi
  else
    echo -e "  ${RED}✗ No client-specific log directory found${NC}"
  fi
  
  LOG_SEGMENTATION="$log_segmentation"
}

# Check Keycloak realm for a client
check_keycloak_realm() {
  local client="$1"
  echo -e "${BLUE}Checking Keycloak realm for ${CYAN}${client}${NC}"
  
  local realm_configured=false
  
  # Check for client-specific Keycloak realm configuration
  if [ -f "${CLIENTS_DIR}/${client}/keycloak/realm.json" ]; then
    echo -e "  ${GREEN}✓ Found Keycloak realm configuration${NC}"
    
    # Check if the realm is properly named
    if grep -q "\"realm\": \"${client}\"" "${CLIENTS_DIR}/${client}/keycloak/realm.json"; then
      echo -e "  ${GREEN}✓ Keycloak realm is properly configured for client${NC}"
      realm_configured=true
    else
      echo -e "  ${YELLOW}⚠ Keycloak realm configuration exists but may not be properly named${NC}"
    fi
  else
    echo -e "  ${RED}✗ No client-specific Keycloak realm configuration found${NC}"
  fi
  
  # Check if Keycloak is running and we can verify the realm exists
  if docker ps | grep -q "keycloak"; then
    echo -e "  ${BLUE}ℹ Keycloak is running, checking if realm exists${NC}"
    
    # Source environment to get admin credentials
    if [ -f "${CONFIG_DIR}/config.env" ]; then
      source "${CONFIG_DIR}/config.env"
    fi
    
    KEYCLOAK_URL=${KEYCLOAK_URL:-"http://localhost:8080"}
    KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
    KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}
    
    # Get access token
    ADMIN_TOKEN=$(curl -s \
      -d "client_id=admin-cli" \
      -d "username=${KEYCLOAK_ADMIN}" \
      -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
      -d "grant_type=password" \
      "${KEYCLOAK_URL}/auth/realms/master/protocol/openid-connect/token" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
    
    if [ -n "$ADMIN_TOKEN" ]; then
      # Check if realm exists
      REALM_EXISTS=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        "${KEYCLOAK_URL}/auth/admin/realms/${client}" | grep -o '"realm":"[^"]*' | sed 's/"realm":"//')
      
      if [ "$REALM_EXISTS" = "$client" ]; then
        echo -e "  ${GREEN}✓ Keycloak realm '${client}' exists and is active${NC}"
        realm_configured=true
      else
        echo -e "  ${RED}✗ Keycloak realm '${client}' does not exist${NC}"
      fi
    else
      echo -e "  ${YELLOW}⚠ Could not authenticate with Keycloak to verify realm${NC}"
    fi
  else
    echo -e "  ${YELLOW}⚠ Keycloak is not running, can't verify realm${NC}"
  fi
  
  REALM_CONFIGURED="$realm_configured"
}

# Initialize JSON output
echo "[" > "$OUTPUT_JSON"

# Get list of clients to check
declare -a CLIENTS

if [ -n "$CLIENT_ID" ]; then
  # Check specific client
  if [ -d "${CLIENTS_DIR}/${CLIENT_ID}" ]; then
    CLIENTS+=("$CLIENT_ID")
  else
    echo -e "${RED}Error: Client ${CLIENT_ID} not found${NC}"
    exit 1
  fi
else
  # Get all clients
  for client_dir in "${CLIENTS_DIR}"/*; do
    if [ -d "$client_dir" ]; then
      client=$(basename "$client_dir")
      CLIENTS+=("$client")
    fi
  done
  
  if [ ${#CLIENTS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No clients found in ${CLIENTS_DIR}${NC}"
    exit 1
  fi
fi

# Check multi-tenancy for all clients
TOTAL_CLIENTS=${#CLIENTS[@]}
FULLY_ISOLATED=0
PARTIALLY_ISOLATED=0
NOT_ISOLATED=0
FIRST=true

for client in "${CLIENTS[@]}"; do
  # Check multi-tenancy aspects
  check_network_isolation "$client"
  check_backup_separation "$client"
  check_log_segmentation "$client"
  check_keycloak_realm "$client"
  
  # Add to JSON (comma for all but first entry)
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$OUTPUT_JSON"
  fi
  
  # Add client entry to JSON
  cat << EOF >> "$OUTPUT_JSON"
  {
    "id": "$client",
    "networkIsolation": $NETWORK_ISOLATION,
    "backupSeparation": $BACKUP_SEPARATION,
    "logSegmentation": $LOG_SEGMENTATION,
    "realmConfigured": $REALM_CONFIGURED
  }
EOF
  
  # Calculate isolation score (0-4)
  local isolation_score=0
  if [ "$NETWORK_ISOLATION" = true ]; then isolation_score=$((isolation_score + 1)); fi
  if [ "$BACKUP_SEPARATION" = true ]; then isolation_score=$((isolation_score + 1)); fi
  if [ "$LOG_SEGMENTATION" = true ]; then isolation_score=$((isolation_score + 1)); fi
  if [ "$REALM_CONFIGURED" = true ]; then isolation_score=$((isolation_score + 1)); fi
  
  # Determine isolation status
  if [ $isolation_score -eq 4 ]; then
    FULLY_ISOLATED=$((FULLY_ISOLATED + 1))
    echo -e "  ${GREEN}✓ Client ${client} is fully isolated (4/4)${NC}"
  elif [ $isolation_score -ge 2 ]; then
    PARTIALLY_ISOLATED=$((PARTIALLY_ISOLATED + 1))
    echo -e "  ${YELLOW}⚠ Client ${client} is partially isolated (${isolation_score}/4)${NC}"
  else
    NOT_ISOLATED=$((NOT_ISOLATED + 1))
    echo -e "  ${RED}✗ Client ${client} is not properly isolated (${isolation_score}/4)${NC}"
  fi
  
  # Log the check
  log "Checked $client - Network: $NETWORK_ISOLATION, Backup: $BACKUP_SEPARATION, Log: $LOG_SEGMENTATION, Realm: $REALM_CONFIGURED, Score: $isolation_score/4"
done

# Close JSON array
echo -e "\n]" >> "$OUTPUT_JSON"

# Print summary
echo -e "\n${BLUE}${BOLD}Multi-Tenancy Verification Summary:${NC}"
echo -e "  ${GREEN}✓ Fully Isolated:${NC} $FULLY_ISOLATED"
echo -e "  ${YELLOW}⚠ Partially Isolated:${NC} $PARTIALLY_ISOLATED"
echo -e "  ${RED}✗ Not Isolated:${NC} $NOT_ISOLATED"
echo -e "  ${BLUE}ℹ Total Clients:${NC} $TOTAL_CLIENTS"

# Create summary JSON file
cat << EOF > "${ROOT_DIR}/multi_tenancy_summary.json"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "fullyIsolated": $FULLY_ISOLATED,
  "partiallyIsolated": $PARTIALLY_ISOLATED,
  "notIsolated": $NOT_ISOLATED,
  "totalClients": $TOTAL_CLIENTS
}
EOF

# Print instructions
echo -e "\n${BLUE}Detailed multi-tenancy status has been saved to:${NC}"
echo -e "  ${CYAN}${OUTPUT_JSON}${NC}"
echo -e "${BLUE}Summary has been saved to:${NC}"
echo -e "  ${CYAN}${ROOT_DIR}/multi_tenancy_summary.json${NC}"
echo -e "${BLUE}Log file:${NC}"
echo -e "  ${CYAN}${TENANCY_LOG}${NC}"

# Final message
if [ $NOT_ISOLATED -gt 0 ]; then
  echo -e "\n${RED}${BOLD}Action Required:${NC} Some clients are not properly isolated."
  echo -e "Run the following commands to fix isolation issues:"
  echo -e "  - ${CYAN}make create-client${NC} (to recreate missing client configuration)"
  echo -e "  - ${CYAN}make setup-roles${NC} (to set up Keycloak realms)"
  echo -e "  - ${CYAN}make setup-log-segmentation${NC} (to configure client log segmentation)"
elif [ $PARTIALLY_ISOLATED -gt 0 ]; then
  echo -e "\n${YELLOW}${BOLD}Warning:${NC} Some clients are only partially isolated."
  echo -e "Consider running the appropriate commands to complete isolation:"
  echo -e "  - ${CYAN}make setup-roles${NC} (for Keycloak realms)"
  echo -e "  - ${CYAN}make setup-log-segmentation${NC} (for log segmentation)"
else
  echo -e "\n${GREEN}${BOLD}All clients are properly isolated.${NC}"
fi

exit 0
