#!/bin/bash
# install_multi_tenancy.sh - Multi-tenancy infrastructure setup for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up the multi-tenancy infrastructure:
# - Client directory structure
# - Network isolation
# - Log segmentation
# - Backup separation by client
# - Initial Keycloak realm setup
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
INSTALL_LOG="${LOG_DIR}/multi_tenancy_install.log"
VERBOSE=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Multi-Tenancy Setup${NC}"
  echo -e "=================================="
  echo -e "This script sets up the multi-tenancy infrastructure for AgencyStack:"
  echo -e "  - Client directory structure"
  echo -e "  - Network isolation"
  echo -e "  - Log segmentation"
  echo -e "  - Backup separation by client" 
  echo -e "  - Initial Keycloak realm setup"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--verbose${NC}          Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}             Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --verbose"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  echo -e "  - After installation, use 'make create-client' to create clients"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Multi-Tenancy Setup${NC}"
echo -e "=================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

log "INFO: Starting AgencyStack multi-tenancy setup" "${BLUE}Starting multi-tenancy setup...${NC}"

# Create directory structure
log "INFO: Creating directory structure" "${BLUE}Creating directory structure...${NC}"

# Main directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${CLIENTS_DIR}"
mkdir -p "${SECRETS_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${CLIENT_LOGS_DIR}"

# Set proper permissions
log "INFO: Setting directory permissions" "${CYAN}Setting directory permissions...${NC}"
chmod 750 "${CONFIG_DIR}"
chmod 750 "${CLIENTS_DIR}"
chmod 700 "${SECRETS_DIR}"
chmod 750 "${LOG_DIR}"
chmod 750 "${CLIENT_LOGS_DIR}"

# Create Docker networks
log "INFO: Creating Docker networks" "${BLUE}Creating Docker networks...${NC}"

# Check if Docker is running
if ! command -v docker &> /dev/null; then
  log "ERROR: Docker is not installed" "${RED}Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

# Create agency network if it doesn't exist
if ! docker network inspect agency-network &> /dev/null; then
  docker network create agency-network >> "$INSTALL_LOG" 2>&1
  log "INFO: Created Docker network: agency-network" "${GREEN}✅ Created Docker network: agency-network${NC}"
else
  log "INFO: Docker network agency-network already exists" "${YELLOW}Docker network agency-network already exists${NC}"
fi

# Create create-client script symlink
log "INFO: Setting up client management scripts" "${BLUE}Setting up client management scripts...${NC}"
if [ -f "${ROOT_DIR}/scripts/create-client.sh" ]; then
  log "INFO: create-client.sh script found" "${GREEN}✅ create-client.sh script found${NC}"
  
  # Make sure script is executable
  chmod +x "${ROOT_DIR}/scripts/create-client.sh"
  
  # Create symlink to /usr/local/bin if it doesn't exist
  if [ ! -f "/usr/local/bin/create-client" ]; then
    ln -s "${ROOT_DIR}/scripts/create-client.sh" "/usr/local/bin/create-client"
    log "INFO: Created symlink for create-client.sh" "${GREEN}✅ Created symlink for create-client.sh${NC}"
  fi
else
  log "WARNING: create-client.sh script not found" "${YELLOW}⚠️ create-client.sh script not found in ${ROOT_DIR}/scripts/. Manual client creation will be required.${NC}"
fi

# Setup Keycloak roles script symlink
if [ -f "${ROOT_DIR}/scripts/keycloak/setup_roles.sh" ]; then
  log "INFO: setup_roles.sh script found" "${GREEN}✅ setup_roles.sh script found${NC}"
  
  # Make sure script is executable
  chmod +x "${ROOT_DIR}/scripts/keycloak/setup_roles.sh"
  
  # Create symlink to /usr/local/bin if it doesn't exist
  if [ ! -f "/usr/local/bin/setup-roles" ]; then
    ln -s "${ROOT_DIR}/scripts/keycloak/setup_roles.sh" "/usr/local/bin/setup-roles"
    log "INFO: Created symlink for setup_roles.sh" "${GREEN}✅ Created symlink for setup_roles.sh${NC}"
  fi
else
  log "WARNING: setup_roles.sh script not found" "${YELLOW}⚠️ setup_roles.sh script not found in ${ROOT_DIR}/scripts/keycloak/. Manual role setup will be required.${NC}"
fi

# Setup log segmentation script symlink
if [ -f "${ROOT_DIR}/scripts/security/setup_log_segmentation.sh" ]; then
  log "INFO: setup_log_segmentation.sh script found" "${GREEN}✅ setup_log_segmentation.sh script found${NC}"
  
  # Make sure script is executable
  chmod +x "${ROOT_DIR}/scripts/security/setup_log_segmentation.sh"
  
  # Create symlink to /usr/local/bin if it doesn't exist
  if [ ! -f "/usr/local/bin/setup-log-segmentation" ]; then
    ln -s "${ROOT_DIR}/scripts/security/setup_log_segmentation.sh" "/usr/local/bin/setup-log-segmentation"
    log "INFO: Created symlink for setup_log_segmentation.sh" "${GREEN}✅ Created symlink for setup_log_segmentation.sh${NC}"
  fi
else
  log "WARNING: setup_log_segmentation.sh script not found" "${YELLOW}⚠️ setup_log_segmentation.sh script not found in ${ROOT_DIR}/scripts/security/. Manual log segmentation will be required.${NC}"
fi

# Create multi-tenancy configuration file
log "INFO: Creating multi-tenancy configuration" "${BLUE}Creating multi-tenancy configuration...${NC}"
cat > "${CONFIG_DIR}/multi_tenancy.conf" <<EOF
# AgencyStack Multi-Tenancy Configuration
# Generated on $(date +"%Y-%m-%d %H:%M:%S")

# Directory structure
CLIENTS_DIR="${CLIENTS_DIR}"
SECRETS_DIR="${SECRETS_DIR}"
LOG_DIR="${LOG_DIR}"
CLIENT_LOGS_DIR="${CLIENT_LOGS_DIR}"

# Network configuration
# Each client gets isolated networks
NETWORK_ISOLATION=true

# Log segmentation
# Each client gets isolated logs
LOG_SEGMENTATION=true

# Backup separation
# Each client gets isolated backup repositories
BACKUP_SEPARATION=true

# Keycloak realms
# Each client gets isolated Keycloak realm
REALM_ISOLATION=true

# Default roles for each client realm
DEFAULT_ROLES="realm_admin,editor,viewer"
EOF

# Create example client configuration for reference
log "INFO: Creating example client configuration" "${BLUE}Creating example client configuration...${NC}"
mkdir -p "${CLIENTS_DIR}/example"
mkdir -p "${CLIENTS_DIR}/example/keycloak"
mkdir -p "${CLIENTS_DIR}/example/backup"
mkdir -p "${CLIENT_LOGS_DIR}/example"
mkdir -p "${CLIENT_LOGS_DIR}/example/services"
mkdir -p "${SECRETS_DIR}/example"

# Example client environment file
cat > "${CLIENTS_DIR}/example/client.env" <<EOF
# Example client configuration
# This is a template - DO NOT USE DIRECTLY

# Client identification
CLIENT_ID="example"
CLIENT_NAME="Example Client"
CLIENT_DOMAIN="example.com"

# Network configuration
CLIENT_NETWORK="example_network"
CLIENT_FRONTEND_NETWORK="example_frontend"
CLIENT_BACKEND_NETWORK="example_backend"
CLIENT_DATABASE_NETWORK="example_database"

# Keycloak configuration
CLIENT_REALM="example"
CLIENT_ADMIN_USER="admin"
CLIENT_ADMIN_EMAIL="admin@example.com"

# Backup configuration
BACKUP_REPOSITORY="client-example"
BACKUP_SCHEDULE="0 2 * * *"
EOF

# Example client Keycloak realm configuration
cat > "${CLIENTS_DIR}/example/keycloak/realm.json" <<EOF
{
  "realm": "example",
  "enabled": true,
  "displayName": "Example Client",
  "loginTheme": "keycloak",
  "accountTheme": "keycloak",
  "adminTheme": "keycloak",
  "emailTheme": "keycloak",
  "sslRequired": "external"
}
EOF

# Example client backup configuration
cat > "${CLIENTS_DIR}/example/backup/config.sh" <<EOF
#!/bin/bash
# Example backup configuration

# Client identification
CLIENT_ID="example"

# Restic configuration
RESTIC_REPOSITORY="client-example"
RESTIC_PASSWORD="change-this-password"

# Backup directories
BACKUP_DIRS="/opt/agency_stack/clients/example"

# Backup schedule
BACKUP_SCHEDULE="0 2 * * *"
EOF

# Example client secrets file
cat > "${SECRETS_DIR}/example/secrets.env" <<EOF
# Example client secrets
# This is a template - DO NOT USE DIRECTLY

# Database secrets
DB_PASSWORD="change-this-password"
DB_ROOT_PASSWORD="change-this-password"

# API keys
API_KEY="change-this-key"

# Keycloak secrets
KEYCLOAK_ADMIN_PASSWORD="change-this-password"
EOF

# Set proper permissions
chmod 600 "${SECRETS_DIR}/example/secrets.env"
chmod 750 "${CLIENTS_DIR}/example"
chmod 750 "${CLIENT_LOGS_DIR}/example"

# Setup check_multi_tenancy script symlink
if [ -f "${ROOT_DIR}/scripts/security/check_multi_tenancy.sh" ]; then
  log "INFO: check_multi_tenancy.sh script found" "${GREEN}✅ check_multi_tenancy.sh script found${NC}"
  
  # Make sure script is executable
  chmod +x "${ROOT_DIR}/scripts/security/check_multi_tenancy.sh"
  
  # Create symlink to /usr/local/bin if it doesn't exist
  if [ ! -f "/usr/local/bin/check-multi-tenancy" ]; then
    ln -s "${ROOT_DIR}/scripts/security/check_multi_tenancy.sh" "/usr/local/bin/check-multi-tenancy"
    log "INFO: Created symlink for check_multi_tenancy.sh" "${GREEN}✅ Created symlink for check_multi_tenancy.sh${NC}"
  fi
else
  log "WARNING: check_multi_tenancy.sh script not found" "${YELLOW}⚠️ check_multi_tenancy.sh script not found in ${ROOT_DIR}/scripts/security/. Manual multi-tenancy checks will be required.${NC}"
fi

# Create sample log files
touch "${CLIENT_LOGS_DIR}/example/access.log"
touch "${CLIENT_LOGS_DIR}/example/error.log"
touch "${CLIENT_LOGS_DIR}/example/audit.log"
touch "${CLIENT_LOGS_DIR}/example/backup.log"

# Final message
log "INFO: Multi-tenancy setup completed successfully" "${GREEN}${BOLD}✅ AgencyStack multi-tenancy setup completed successfully!${NC}"
echo -e "${CYAN}You can now create clients using:${NC}"
echo -e "${CYAN}  make create-client CLIENT_ID=name CLIENT_NAME=\"Full Name\" CLIENT_DOMAIN=domain.com${NC}"
echo -e ""
echo -e "${CYAN}Verify multi-tenancy status using:${NC}"
echo -e "${CYAN}  make multi-tenancy-status${NC}"
echo -e ""
echo -e "${YELLOW}Note: The example client is for reference only and should be deleted before deployment.${NC}"

exit 0
