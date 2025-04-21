#!/bin/bash
# install_backup_strategy.sh - Encrypted offsite incremental backup system using Restic
# https://stack.nerdofmouth.com
#
# This script sets up Restic backups with:
# - Encryption for secure offsite storage
# - Scheduled incremental backups
# - Multiple backend support (S3, SFTP, local)
# - Restore verification
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/common.sh"
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="backup_strategy"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

# Show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Installs and configures Restic backup system for AgencyStack"
  echo
  echo "Options:"
  echo "  --domain DOMAIN        Domain name for the installation"
  echo "  --admin-email EMAIL    Admin email for notifications"
  echo "  --client-id ID         Client ID for multi-tenant setup"
  echo "  --force                Force reinstallation even if already installed"
  echo "  --with-deps            Install dependencies if missing"
  echo "  --verbose              Enable verbose output"
  echo "  --enable-cloud         Enable cloud storage backends"
  echo "  --enable-openai        Enable OpenAI API integration"
  echo "  --use-github           Use GitHub for repository operations"
  echo "  -h, --help             Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
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
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Setup logging
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")"
exec &> >(tee -a "${COMPONENT_LOG_FILE}")

# Log function
log() {
  local level="$1"
  local message="$2"
  local display="$3"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${COMPONENT_LOG_FILE}"
  if [[ -n "${display}" ]]; then
    echo -e "${display}"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  local json_data="$2"
  
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"component\":\"${COMPONENT}\",\"message\":\"${message}\",\"data\":${json_data}}" >> "${AGENCY_LOG_DIR}/integration.log"
}

log "INFO" "Starting backup strategy installation for domain: ${DOMAIN}" "${BLUE}Starting backup strategy installation for domain: ${DOMAIN}...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"
SECRETS_DIR="${AGENCY_ROOT}/secrets/${COMPONENT}/${CLIENT_ID}"

# Check for existing installation
if [[ -f "${COMPONENT_INSTALLED_MARKER}" ]] && [[ "${FORCE}" != "true" ]]; then
  log "INFO" "Backup strategy already installed" "${GREEN}✅ Backup strategy already installed.${NC}"
  log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
  exit 0
fi

# Create necessary directories
log "INFO" "Creating necessary directories" "${CYAN}Creating necessary directories...${NC}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/scripts"
mkdir -p "${INSTALL_DIR}/logs"
mkdir -p "${INSTALL_DIR}/keys"
mkdir -p "${INSTALL_DIR}/env"
mkdir -p "${SECRETS_DIR}"

# Install Restic if not installed
if ! command -v restic &> /dev/null; then
  log "INFO" "Installing Restic backup tool" "${CYAN}Installing Restic backup tool...${NC}"
  apt-get update >> "${INSTALL_LOG}" 2>&1
  apt-get install -y restic >> "${INSTALL_LOG}" 2>&1
fi

# Create environment file template
log "INFO" "Creating environment file template" "${CYAN}Creating environment file template...${NC}"
cat > "${INSTALL_DIR}/env/restic.env.example" <<EOL
# Restic backend configuration
# Uncomment and configure one of the following backends

# Local backend
#RESTIC_REPOSITORY=/path/to/backup/repository

# SFTP backend
#RESTIC_REPOSITORY=sftp:user@host:/path/to/backup/repository

# S3 backend (AWS, MinIO, etc.)
#RESTIC_REPOSITORY=s3:s3.amazonaws.com/bucket_name/path
#AWS_ACCESS_KEY_ID=your_access_key
#AWS_SECRET_ACCESS_KEY=your_secret_key

# B2 backend (Backblaze)
#RESTIC_REPOSITORY=b2:bucket_name:path
#B2_ACCOUNT_ID=your_account_id
#B2_ACCOUNT_KEY=your_account_key

# Encryption password
# IMPORTANT: Save this securely, losing this will make recovery impossible
RESTIC_PASSWORD=change_this_to_a_secure_random_password

# Retention policy
# Keep 7 daily, 4 weekly, and 12 monthly snapshots
RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=12

# Backup paths (comma-separated)
BACKUP_PATHS=/opt/agency_stack/clients/${CLIENT_ID},/var/log/agency_stack/clients/${CLIENT_ID}

# Exclude patterns (comma-separated)
EXCLUDE_PATTERNS=**/.git,**/node_modules,**/tmp,**/temp,**/cache

# Email notification
NOTIFICATION_EMAIL=${ADMIN_EMAIL}
EOL

# Generate a secure password
log "INFO" "Generating secure password for Restic" "${CYAN}Generating secure password for Restic...${NC}"
RESTIC_PASSWORD=$(openssl rand -base64 32)
echo "${RESTIC_PASSWORD}" > "${SECRETS_DIR}/restic_password.txt"
chmod 600 "${SECRETS_DIR}/restic_password.txt"

# Create actual environment file with secure password
sed "s/change_this_to_a_secure_random_password/${RESTIC_PASSWORD}/" "${INSTALL_DIR}/env/restic.env.example" > "${INSTALL_DIR}/env/restic.env"
chmod 600 "${INSTALL_DIR}/env/restic.env"

# Create backup script
log "INFO" "Creating backup script" "${CYAN}Creating backup script...${NC}"
cat > "${INSTALL_DIR}/scripts/backup.sh" <<EOL
#!/bin/bash
# backup.sh - Run Restic backup for AgencyStack
# https://stack.nerdofmouth.com

# Source environment variables
source "${INSTALL_DIR}/env/restic.env"

# Set up logging
LOG_FILE="${INSTALL_DIR}/logs/backup_\$(date +%Y-%m-%d_%H-%M-%S).log"
exec &> >(tee -a "\$LOG_FILE")

echo "Starting backup at \$(date)"

# Check if repository is initialized
if ! restic snapshots &> /dev/null; then
  echo "Initializing repository..."
  restic init
fi

# Run backup
echo "Running backup..."
restic backup --verbose \$(echo \$BACKUP_PATHS | sed 's/,/ /g') --exclude=\$(echo \$EXCLUDE_PATTERNS | sed 's/,/ --exclude=/g')

# Apply retention policy
if [ -n "\$RETENTION_DAYS" ] || [ -n "\$RETENTION_WEEKS" ] || [ -n "\$RETENTION_MONTHS" ]; then
  echo "Applying retention policy..."
  restic forget --prune \\
    \$([ -n "\$RETENTION_DAYS" ] && echo "--keep-daily \$RETENTION_DAYS") \\
    \$([ -n "\$RETENTION_WEEKS" ] && echo "--keep-weekly \$RETENTION_WEEKS") \\
    \$([ -n "\$RETENTION_MONTHS" ] && echo "--keep-monthly \$RETENTION_MONTHS")
fi

# Check repository integrity
echo "Checking repository integrity..."
restic check
CHECK_EXIT_CODE=\$?

echo "Backup completed at \$(date)"

# Send notification email if configured
if [ -n "\$NOTIFICATION_EMAIL" ]; then
  SUBJECT="Backup \$([ \$CHECK_EXIT_CODE -eq 0 ] && echo "successful" || echo "failed") for ${DOMAIN}"
  BODY=\$(cat "\$LOG_FILE")
  echo -e "Subject: \$SUBJECT\n\n\$BODY" | sendmail -t "\$NOTIFICATION_EMAIL"
fi

if [ \$CHECK_EXIT_CODE -eq 0 ]; then
  echo "✅ Repository check passed!"
  exit 0
else
  echo "❌ Repository check failed with exit code \$CHECK_EXIT_CODE"
  exit \$CHECK_EXIT_CODE
fi
EOL

# Create restore script
log "INFO" "Creating restore script" "${CYAN}Creating restore script...${NC}"
cat > "${INSTALL_DIR}/scripts/restore.sh" <<EOL
#!/bin/bash
# restore.sh - Restore data from Restic backup
# https://stack.nerdofmouth.com

# Source environment variables
source "${INSTALL_DIR}/env/restic.env"

# Set up logging
LOG_FILE="${INSTALL_DIR}/logs/restore_\$(date +%Y-%m-%d_%H-%M-%S).log"
exec &> >(tee -a "\$LOG_FILE")

# Parse arguments
SNAPSHOT="latest"
TARGET_DIR=""

print_usage() {
  echo "Usage: \$0 [options]"
  echo "Options:"
  echo "  --snapshot ID    Snapshot ID to restore (default: latest)"
  echo "  --target DIR     Target directory for restoration"
  echo "  --help           Show this help message"
}

while [[ \$# -gt 0 ]]; do
  key="\$1"
  case \$key in
    --snapshot)
      SNAPSHOT="\$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="\$2"
      shift 2
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: \$1"
      print_usage
      exit 1
      ;;
  esac
done

if [ -z "\$TARGET_DIR" ]; then
  echo "Error: Target directory is required"
  print_usage
  exit 1
fi

mkdir -p "\$TARGET_DIR"

echo "Starting restoration at \$(date)"
echo "Snapshot: \$SNAPSHOT"
echo "Target directory: \$TARGET_DIR"

# List files in snapshot
echo "Files in snapshot:"
restic ls \$SNAPSHOT

# Perform restoration
echo "Restoring files..."
restic restore \$SNAPSHOT --target "\$TARGET_DIR"
RESTORE_EXIT_CODE=\$?

echo "Restoration completed at \$(date) with exit code \$RESTORE_EXIT_CODE"

if [ \$RESTORE_EXIT_CODE -eq 0 ]; then
  echo "✅ Restoration successful!"
  exit 0
else
  echo "❌ Restoration failed with exit code \$RESTORE_EXIT_CODE"
  exit \$RESTORE_EXIT_CODE
fi
EOL

# Make scripts executable
chmod +x "${INSTALL_DIR}/scripts/backup.sh"
chmod +x "${INSTALL_DIR}/scripts/restore.sh"

# Create cron job for daily backups
log "INFO" "Setting up daily backup cron job" "${CYAN}Setting up daily backup cron job...${NC}"
CRON_FILE="/etc/cron.d/agency-stack-backup-${CLIENT_ID}"
echo "0 2 * * * root ${INSTALL_DIR}/scripts/backup.sh > /dev/null 2>&1" > "${CRON_FILE}"
chmod 644 "${CRON_FILE}"

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Backup strategy installed" "{\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\"}"

log "SUCCESS" "Backup strategy installation completed" "${GREEN}✅ Backup strategy installation completed!${NC}"
echo
log "INFO" "Manual configuration required" "${YELLOW}⚠️ IMPORTANT: Manual configuration required${NC}"
echo
echo -e "${CYAN}Backup environment file: ${INSTALL_DIR}/env/restic.env${NC}"
echo -e "${CYAN}Edit this file to configure your preferred backup repository.${NC}"
echo
echo -e "${CYAN}Run a manual backup: ${INSTALL_DIR}/scripts/backup.sh${NC}"
echo -e "${CYAN}Restore data: ${INSTALL_DIR}/scripts/restore.sh --target /path/to/restore${NC}"
echo
echo -e "${YELLOW}Backup password saved to: ${SECRETS_DIR}/restic_password.txt${NC}"
echo -e "${RED}KEEP THIS PASSWORD SAFE! Without it, backups cannot be restored.${NC}"
echo
log "INFO" "Daily backups scheduled at 2:00 AM" "${CYAN}Daily backups scheduled at 2:00 AM via cron.${NC}"

exit 0
