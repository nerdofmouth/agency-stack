#!/bin/bash
# install_cryptosync.sh - AgencyStack Encrypted Storage & Remote Sync Integration
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures gocryptfs and rclone for encrypted storage with
# remote sync capabilities
# Part of the AgencyStack Security & Storage suite
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Color definitions
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
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
CRYPTOSYNC_LOG="${COMPONENT_LOG_DIR}/cryptosync.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Cryptosync Configuration
CRYPTOSYNC_VERSION="1.0.0"
CLIENT_ID=""
CLIENT_DIR=""
MOUNT_DIR=""
REMOTE_NAME="default-remote"
CONFIG_NAME="default"
WITH_DEPS=false
FORCE=false
USE_CRYFS=false
INITIAL_SYNC=false
REMOTE_TYPE=""
REMOTE_PATH=""
REMOTE_OPTIONS=""
VAULT_PASSWORD=""
AUTO_MOUNT=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${CRYPTOSYNC_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Cryptosync Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--mount-dir${NC} <dir>          Directory where encrypted volume will be mounted"
  echo -e "  ${CYAN}--remote-name${NC} <name>       Name for the rclone remote configuration"
  echo -e "  ${CYAN}--config-name${NC} <name>       Name for the cryptosync configuration profile"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (gocryptfs, rclone, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--use-cryfs${NC}                Use CryFS instead of gocryptfs (fallback option)"
  echo -e "  ${CYAN}--initial-sync${NC}             Perform initial sync to remote after setup"
  echo -e "  ${CYAN}--remote-type${NC} <type>       Rclone remote type (e.g., s3, gdrive, webdav)"
  echo -e "  ${CYAN}--remote-path${NC} <path>       Path/bucket on the remote"
  echo -e "  ${CYAN}--remote-options${NC} <options> Comma-separated list of remote options (key=value)"
  echo -e "  ${CYAN}--vault-password${NC} <pass>    Password for the encrypted vault (UNSAFE: use only for automation)"
  echo -e "  ${CYAN}--auto-mount${NC}               Automatically mount the encrypted volume after setup"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --client-id client1 --mount-dir /mnt/vault --with-deps"
  echo -e "  $0 --client-id client1 --remote-name s3-backup --remote-type s3 --remote-path mybucket/backups --initial-sync"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}"
  
  # Create persistent data directories
  mkdir -p "${CLIENT_DIR}/vault"
  mkdir -p "${CLIENT_DIR}/vault/encrypted"
  mkdir -p "${CLIENT_DIR}/rclone"
  mkdir -p "${CLIENT_DIR}/cryptosync/config"
  mkdir -p "${CLIENT_DIR}/cryptosync/scripts"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}"
  
  # Save client ID to file if it doesn't exist
  if [ ! -f "${CLIENT_ID_FILE}" ]; then
    echo "${CLIENT_ID}" > "${CLIENT_ID_FILE}"
    log "INFO" "Saved client ID to ${CLIENT_ID_FILE}"
  fi
  
  # If mount directory is not specified, create a default one
  if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="${CLIENT_DIR}/vault/decrypted"
    log "INFO" "No mount directory specified, using ${MOUNT_DIR}"
  fi
  
  # Create mount directory if it doesn't exist
  mkdir -p "$MOUNT_DIR"
}

# Check system requirements
check_requirements() {
  log "INFO" "Checking system requirements..."
  
  # Check if gocryptfs is installed
  if ! command -v gocryptfs &> /dev/null && ! [ "$USE_CRYFS" = true ] && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "gocryptfs is not installed. Please install gocryptfs first or use --with-deps"
    exit 1
  fi
  
  # Check if cryfs is installed (if using cryfs)
  if [ "$USE_CRYFS" = true ] && ! command -v cryfs &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "cryfs is not installed. Please install cryfs first or use --with-deps"
    exit 1
  fi
  
  # Check if rclone is installed
  if ! command -v rclone &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "rclone is not installed. Please install rclone first or use --with-deps"
    exit 1
  fi
  
  # Check if fusermount is installed
  if ! command -v fusermount &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "fusermount is not installed. Please install fuse-utils first or use --with-deps"
    exit 1
  fi
  
  # Check if mount directory is writable
  if [ ! -w "$(dirname "$MOUNT_DIR")" ]; then
    log "ERROR" "Mount directory parent is not writable: $(dirname "$MOUNT_DIR")"
    exit 1
  fi
  
  # All checks passed
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Install system dependencies
  log "INFO" "Installing system packages..."
  apt-get update
  apt-get install -y fuse fuse-utils
  
  # Install gocryptfs or cryfs based on preference
  if [ "$USE_CRYFS" = true ]; then
    log "INFO" "Installing CryFS..."
    apt-get install -y cryfs
  else
    log "INFO" "Installing gocryptfs..."
    apt-get install -y gocryptfs
  fi
  
  # Install rclone
  log "INFO" "Installing rclone..."
  if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | bash
  else
    log "INFO" "rclone is already installed"
  fi
  
  log "INFO" "Dependencies installed successfully"
}

# Initialize encrypted filesystem
initialize_encrypted_fs() {
  log "INFO" "Initializing encrypted filesystem..."
  
  ENCRYPTED_DIR="${CLIENT_DIR}/vault/encrypted"
  
  # Check if already initialized
  if [ -f "${ENCRYPTED_DIR}/gocryptfs.conf" ] && [ "$FORCE" = false ] && [ "$USE_CRYFS" = false ]; then
    log "WARN" "Encrypted filesystem already initialized. Use --force to reinitialize."
    return
  fi
  
  if [ -f "${ENCRYPTED_DIR}/.cryfs.config" ] && [ "$FORCE" = false ] && [ "$USE_CRYFS" = true ]; then
    log "WARN" "Encrypted filesystem already initialized. Use --force to reinitialize."
    return
  fi
  
  # Prepare directories
  if [ "$FORCE" = true ]; then
    # Only remove the encrypted directory if force is specified
    log "WARN" "Force flag set, removing existing encrypted directory..."
    rm -rf "${ENCRYPTED_DIR}"
    mkdir -p "${ENCRYPTED_DIR}"
  fi
  
  # Create mount directory if it doesn't exist
  mkdir -p "$MOUNT_DIR"
  
  # Initialize filesystem based on preference
  if [ "$USE_CRYFS" = true ]; then
    log "INFO" "Initializing CryFS volume..."
    
    # If password provided (not recommended for production), use it
    if [ -n "$VAULT_PASSWORD" ]; then
      echo "$VAULT_PASSWORD" | cryfs --config "${CLIENT_DIR}/cryptosync/config/cryfs.${CONFIG_NAME}.conf" "${ENCRYPTED_DIR}" "${MOUNT_DIR}"
      echo "$VAULT_PASSWORD" > "${CLIENT_DIR}/cryptosync/config/password.${CONFIG_NAME}.txt"
      chmod 600 "${CLIENT_DIR}/cryptosync/config/password.${CONFIG_NAME}.txt"
      log "WARN" "Password saved to file for automation. This is NOT recommended for production use."
    else
      log "INFO" "Please enter a password for your encrypted volume:"
      cryfs --config "${CLIENT_DIR}/cryptosync/config/cryfs.${CONFIG_NAME}.conf" "${ENCRYPTED_DIR}" "${MOUNT_DIR}"
    fi
    
    # Unmount after initialization
    fusermount -u "${MOUNT_DIR}"
    log "INFO" "CryFS volume initialized successfully"
    
  else
    log "INFO" "Initializing gocryptfs volume..."
    
    # If password provided (not recommended for production), use it
    if [ -n "$VAULT_PASSWORD" ]; then
      echo "$VAULT_PASSWORD" | gocryptfs -init -scryptn 16 -info "${ENCRYPTED_DIR}"
      echo "$VAULT_PASSWORD" > "${CLIENT_DIR}/cryptosync/config/password.${CONFIG_NAME}.txt"
      chmod 600 "${CLIENT_DIR}/cryptosync/config/password.${CONFIG_NAME}.txt"
      log "WARN" "Password saved to file for automation. This is NOT recommended for production use."
    else
      log "INFO" "Please enter a password for your encrypted volume:"
      gocryptfs -init -scryptn 16 -info "${ENCRYPTED_DIR}"
    fi
    
    log "INFO" "gocryptfs volume initialized successfully"
  fi
  
  # Save configuration details
  cat > "${CLIENT_DIR}/cryptosync/config/cryptosync.${CONFIG_NAME}.conf" << EOF
# Cryptosync configuration for ${CONFIG_NAME}
ENCRYPTED_DIR=${ENCRYPTED_DIR}
MOUNT_DIR=${MOUNT_DIR}
REMOTE_NAME=${REMOTE_NAME}
FILESYSTEM_TYPE=$([ "$USE_CRYFS" = true ] && echo "cryfs" || echo "gocryptfs")
CREATED_DATE=$(date -Iseconds)
CLIENT_ID=${CLIENT_ID}
EOF

  log "INFO" "Configuration saved to ${CLIENT_DIR}/cryptosync/config/cryptosync.${CONFIG_NAME}.conf"
}

# Configure rclone remote
configure_rclone() {
  log "INFO" "Configuring rclone remote: ${REMOTE_NAME}..."
  
  # Check if rclone config for this client exists and create it if not
  RCLONE_CONFIG="${CLIENT_DIR}/rclone/rclone.conf"
  
  # Create rclone config directory if it doesn't exist
  mkdir -p "$(dirname "$RCLONE_CONFIG")"
  
  # Check if a remote with the same name already exists
  if grep -q "^\[${REMOTE_NAME}\]$" "$RCLONE_CONFIG" 2>/dev/null && [ "$FORCE" = false ]; then
    log "WARN" "Remote '${REMOTE_NAME}' already exists in rclone config. Use --force to recreate."
    return
  fi
  
  # If remote type is not specified, just create an empty rclone config
  if [ -z "$REMOTE_TYPE" ]; then
    if [ ! -f "$RCLONE_CONFIG" ]; then
      touch "$RCLONE_CONFIG"
      log "INFO" "Created empty rclone config at ${RCLONE_CONFIG}"
      log "INFO" "You can configure remotes manually using 'rclone config --config ${RCLONE_CONFIG}'"
    fi
    return
  fi
  
  # Validate remote type
  case "$REMOTE_TYPE" in
    s3|gdrive|dropbox|onedrive|webdav|b2|sftp|box|mega|swift)
      log "INFO" "Configuring ${REMOTE_TYPE} remote..."
      ;;
    *)
      log "WARN" "Unsupported remote type: ${REMOTE_TYPE}. Creating empty config."
      touch "$RCLONE_CONFIG"
      return
      ;;
  esac
  
  # Parse remote options into an array
  IFS=',' read -ra REMOTE_OPTS <<< "$REMOTE_OPTIONS"
  
  # Generate rclone config example based on the remote type
  case "$REMOTE_TYPE" in
    s3)
      # Example S3 configuration
      cat > "$RCLONE_CONFIG" << EOF
[${REMOTE_NAME}]
type = s3
provider = AWS
access_key_id = YOUR_ACCESS_KEY
secret_access_key = YOUR_SECRET_KEY
region = us-east-1
acl = private
storage_class = STANDARD
EOF
      ;;
    
    gdrive)
      # Example Google Drive configuration
      cat > "$RCLONE_CONFIG" << EOF
[${REMOTE_NAME}]
type = drive
client_id = YOUR_CLIENT_ID
client_secret = YOUR_CLIENT_SECRET
scope = drive
root_folder_id = 
EOF
      ;;
    
    webdav)
      # Example WebDAV configuration
      cat > "$RCLONE_CONFIG" << EOF
[${REMOTE_NAME}]
type = webdav
url = https://example.com/webdav
vendor = other
user = username
pass = password
EOF
      ;;
    
    dropbox)
      # Example Dropbox configuration
      cat > "$RCLONE_CONFIG" << EOF
[${REMOTE_NAME}]
type = dropbox
client_id = YOUR_CLIENT_ID
client_secret = YOUR_CLIENT_SECRET
EOF
      ;;
    
    *)
      # Default empty configuration
      cat > "$RCLONE_CONFIG" << EOF
[${REMOTE_NAME}]
type = ${REMOTE_TYPE}
# Please configure this remote manually using:
# rclone config --config ${RCLONE_CONFIG}
EOF
      ;;
  esac
  
  # Apply any provided options
  for opt in "${REMOTE_OPTS[@]}"; do
    key="${opt%%=*}"
    value="${opt#*=}"
    
    if [ -n "$key" ] && [ -n "$value" ]; then
      # Check if key already exists in the config
      if grep -q "^${key} =" "$RCLONE_CONFIG"; then
        # Replace the existing value
        sed -i "s|^${key} =.*|${key} = ${value}|" "$RCLONE_CONFIG"
      else
        # Add the new option before the section end
        sed -i "/^\[${REMOTE_NAME}\]/a ${key} = ${value}" "$RCLONE_CONFIG"
      fi
    fi
  done
  
  log "INFO" "Created rclone config at ${RCLONE_CONFIG}"
  log "INFO" "⚠️  Please edit the configuration file to set your actual credentials"
  log "INFO" "   or use 'rclone config --config ${RCLONE_CONFIG}' to configure interactively"
}

# Create helper scripts
create_helper_scripts() {
  log "INFO" "Creating helper scripts..."
  
  # Create scripts directory if it doesn't exist
  SCRIPTS_DIR="${CLIENT_DIR}/cryptosync/scripts"
  mkdir -p "$SCRIPTS_DIR"
  
  # Mount script
  cat > "${SCRIPTS_DIR}/mount_${CONFIG_NAME}.sh" << 'EOF'
#!/bin/bash
# Mount the encrypted filesystem

# Load configuration
CONFIG_FILE=$(dirname "$(dirname "$0")")/config/cryptosync.${CONFIG_NAME}.conf
source "$CONFIG_FILE"

# Check if already mounted
if mountpoint -q "$MOUNT_DIR"; then
    echo "Already mounted at $MOUNT_DIR"
    exit 0
fi

# Create mount directory if it doesn't exist
mkdir -p "$MOUNT_DIR"

# Get password
PASSWORD_FILE=$(dirname "$CONFIG_FILE")/password.${CONFIG_NAME}.txt

if [ -f "$PASSWORD_FILE" ]; then
    # Automatic mounting with password file
    PASSWORD=$(cat "$PASSWORD_FILE")
    
    if [ "$FILESYSTEM_TYPE" = "cryfs" ]; then
        echo "$PASSWORD" | cryfs --config "$(dirname "$CONFIG_FILE")/cryfs.${CONFIG_NAME}.conf" "$ENCRYPTED_DIR" "$MOUNT_DIR"
    else
        echo "$PASSWORD" | gocryptfs "$ENCRYPTED_DIR" "$MOUNT_DIR"
    fi
else
    # Interactive mounting
    if [ "$FILESYSTEM_TYPE" = "cryfs" ]; then
        cryfs --config "$(dirname "$CONFIG_FILE")/cryfs.${CONFIG_NAME}.conf" "$ENCRYPTED_DIR" "$MOUNT_DIR"
    else
        gocryptfs "$ENCRYPTED_DIR" "$MOUNT_DIR"
    fi
fi

echo "Mounted $ENCRYPTED_DIR at $MOUNT_DIR"
EOF
  
  # Unmount script
  cat > "${SCRIPTS_DIR}/unmount_${CONFIG_NAME}.sh" << 'EOF'
#!/bin/bash
# Unmount the encrypted filesystem

# Load configuration
CONFIG_FILE=$(dirname "$(dirname "$0")")/config/cryptosync.${CONFIG_NAME}.conf
source "$CONFIG_FILE"

# Check if mounted
if ! mountpoint -q "$MOUNT_DIR"; then
    echo "Not mounted at $MOUNT_DIR"
    exit 0
fi

# Unmount
fusermount -u "$MOUNT_DIR"
echo "Unmounted $MOUNT_DIR"
EOF
  
  # Sync script
  cat > "${SCRIPTS_DIR}/sync_${CONFIG_NAME}.sh" << 'EOF'
#!/bin/bash
# Sync encrypted data to remote

# Load configuration
CONFIG_FILE=$(dirname "$(dirname "$0")")/config/cryptosync.${CONFIG_NAME}.conf
source "$CONFIG_FILE"

# Rclone config
RCLONE_CONFIG="${CLIENT_DIR}/rclone/rclone.conf"

# Check if remote is configured
if ! grep -q "^\[${REMOTE_NAME}\]$" "$RCLONE_CONFIG" 2>/dev/null; then
    echo "Remote '${REMOTE_NAME}' not configured in rclone config"
    echo "Please configure it first using 'rclone config --config $RCLONE_CONFIG'"
    exit 1
fi

# Sync encrypted data to remote
REMOTE_PATH="${REMOTE_NAME}:${1:-backup}"

echo "Syncing encrypted data to $REMOTE_PATH..."
rclone sync --progress --config "$RCLONE_CONFIG" "$ENCRYPTED_DIR" "$REMOTE_PATH"

echo "Sync completed"
EOF
  
  # Make scripts executable
  chmod +x "${SCRIPTS_DIR}/mount_${CONFIG_NAME}.sh"
  chmod +x "${SCRIPTS_DIR}/unmount_${CONFIG_NAME}.sh"
  chmod +x "${SCRIPTS_DIR}/sync_${CONFIG_NAME}.sh"
  
  # Create symlinks to scripts in /usr/local/bin if not already there
  if [ ! -f "/usr/local/bin/cryptosync-mount-${CLIENT_ID}-${CONFIG_NAME}" ]; then
    ln -s "${SCRIPTS_DIR}/mount_${CONFIG_NAME}.sh" "/usr/local/bin/cryptosync-mount-${CLIENT_ID}-${CONFIG_NAME}"
  fi
  
  if [ ! -f "/usr/local/bin/cryptosync-unmount-${CLIENT_ID}-${CONFIG_NAME}" ]; then
    ln -s "${SCRIPTS_DIR}/unmount_${CONFIG_NAME}.sh" "/usr/local/bin/cryptosync-unmount-${CLIENT_ID}-${CONFIG_NAME}"
  fi
  
  if [ ! -f "/usr/local/bin/cryptosync-sync-${CLIENT_ID}-${CONFIG_NAME}" ]; then
    ln -s "${SCRIPTS_DIR}/sync_${CONFIG_NAME}.sh" "/usr/local/bin/cryptosync-sync-${CLIENT_ID}-${CONFIG_NAME}"
  fi
  
  log "INFO" "Helper scripts created and symlinked"
}

# Perform initial sync if requested
perform_initial_sync() {
  if [ "$INITIAL_SYNC" = false ]; then
    log "INFO" "Skipping initial sync (--initial-sync not specified)"
    return
  fi
  
  if [ -z "$REMOTE_TYPE" ]; then
    log "WARN" "No remote type specified, cannot perform initial sync"
    return
  fi
  
  log "INFO" "Performing initial sync to remote: ${REMOTE_NAME}..."
  
  # Check if remote path is specified
  if [ -z "$REMOTE_PATH" ]; then
    REMOTE_PATH="backup"
    log "INFO" "No remote path specified, using '${REMOTE_PATH}'"
  fi
  
  # Run the sync script
  SYNC_SCRIPT="${CLIENT_DIR}/cryptosync/scripts/sync_${CONFIG_NAME}.sh"
  if [ -f "$SYNC_SCRIPT" ]; then
    log "INFO" "Running sync script: $SYNC_SCRIPT ${REMOTE_PATH}"
    bash "$SYNC_SCRIPT" "$REMOTE_PATH"
    log "INFO" "Initial sync completed"
  else
    log "ERROR" "Sync script not found: $SYNC_SCRIPT"
  fi
}

# Auto-mount encrypted filesystem if requested
auto_mount() {
  if [ "$AUTO_MOUNT" = false ]; then
    log "INFO" "Skipping auto-mount (--auto-mount not specified)"
    return
  fi
  
  log "INFO" "Auto-mounting encrypted filesystem..."
  
  # Run the mount script
  MOUNT_SCRIPT="${CLIENT_DIR}/cryptosync/scripts/mount_${CONFIG_NAME}.sh"
  if [ -f "$MOUNT_SCRIPT" ]; then
    log "INFO" "Running mount script: $MOUNT_SCRIPT"
    bash "$MOUNT_SCRIPT"
    log "INFO" "Auto-mount completed"
  else
    log "ERROR" "Mount script not found: $MOUNT_SCRIPT"
  fi
}

# Update component registry
update_registry() {
  log "INFO" "Updating component registry..."
  
  # Update installed components list
  if ! grep -q "cryptosync" "$INSTALLED_COMPONENTS" 2>/dev/null; then
    echo "cryptosync" >> "$INSTALLED_COMPONENTS"
    log "INFO" "Added cryptosync to installed components list"
  fi
  
  # Check if registry file exists
  REGISTRY_JSON="${CONFIG_DIR}/config/registry/component_registry.json"
  
  if [ ! -f "$REGISTRY_JSON" ]; then
    log "WARN" "Component registry file not found: $REGISTRY_JSON"
    log "WARN" "Skipping registry update"
    return
  fi
  
  # Check if cryptosync entry already exists in registry
  if grep -q '"cryptosync"' "$REGISTRY_JSON" 2>/dev/null; then
    log "INFO" "cryptosync already exists in component registry"
    return
  fi
  
  # Create temporary file for JSON manipulation
  TEMP_FILE=$(mktemp)
  
  # Add cryptosync to registry
  jq '.components.security_storage.cryptosync = {
    "name": "Cryptosync",
    "category": "Security & Storage",
    "version": "1.0.0",
    "integration_status": {
      "installed": true,
      "hardened": true,
      "makefile": true,
      "sso": false,
      "dashboard": false,
      "logs": true,
      "docs": true,
      "auditable": true,
      "traefik_tls": false,
      "multi_tenant": true
    },
    "description": "Encrypted local vaults + remote cloud sync via gocryptfs and rclone",
    "ports": {}
  }' "$REGISTRY_JSON" > "$TEMP_FILE"
  
  # Check if jq command was successful
  if [ $? -eq 0 ]; then
    # Replace original file with updated one
    mv "$TEMP_FILE" "$REGISTRY_JSON"
    log "INFO" "Updated component registry with cryptosync entry"
  else
    rm "$TEMP_FILE"
    log "ERROR" "Failed to update component registry"
  fi
  
  # Create summary file
  SUMMARY_FILE="${CLIENT_DIR}/cryptosync/summary.json"
  cat > "$SUMMARY_FILE" << EOF
{
  "component": "cryptosync",
  "version": "1.0.0",
  "client_id": "${CLIENT_ID}",
  "config_name": "${CONFIG_NAME}",
  "mount_dir": "${MOUNT_DIR}",
  "encrypted_dir": "${CLIENT_DIR}/vault/encrypted",
  "remote_name": "${REMOTE_NAME}",
  "filesystem_type": "$([ "$USE_CRYFS" = true ] && echo "cryfs" || echo "gocryptfs")",
  "installation_date": "$(date -Iseconds)",
  "scripts": {
    "mount": "/usr/local/bin/cryptosync-mount-${CLIENT_ID}-${CONFIG_NAME}",
    "unmount": "/usr/local/bin/cryptosync-unmount-${CLIENT_ID}-${CONFIG_NAME}",
    "sync": "/usr/local/bin/cryptosync-sync-${CLIENT_ID}-${CONFIG_NAME}"
  }
}
EOF
  
  log "INFO" "Created summary file at ${SUMMARY_FILE}"
}

# Print summary and usage instructions
print_summary() {
  echo
  echo -e "${BOLD}${GREEN}=== Cryptosync Installation Complete ===${NC}"
  echo
  echo -e "${BOLD}Configuration Details:${NC}"
  echo -e "  ${CYAN}Client ID:${NC}        ${CLIENT_ID}"
  echo -e "  ${CYAN}Config Name:${NC}      ${CONFIG_NAME}"
  echo -e "  ${CYAN}Encrypted Dir:${NC}    ${CLIENT_DIR}/vault/encrypted"
  echo -e "  ${CYAN}Mount Dir:${NC}        ${MOUNT_DIR}"
  echo -e "  ${CYAN}Rclone Config:${NC}    ${CLIENT_DIR}/rclone/rclone.conf"
  echo -e "  ${CYAN}Remote Name:${NC}      ${REMOTE_NAME}"
  echo -e "  ${CYAN}Filesystem:${NC}       $([ "$USE_CRYFS" = true ] && echo "CryFS" || echo "gocryptfs")"
  echo
  echo -e "${BOLD}Helper Scripts:${NC}"
  echo -e "  ${CYAN}Mount:${NC}            /usr/local/bin/cryptosync-mount-${CLIENT_ID}-${CONFIG_NAME}"
  echo -e "  ${CYAN}Unmount:${NC}          /usr/local/bin/cryptosync-unmount-${CLIENT_ID}-${CONFIG_NAME}"
  echo -e "  ${CYAN}Sync:${NC}             /usr/local/bin/cryptosync-sync-${CLIENT_ID}-${CONFIG_NAME}"
  echo
  echo -e "${BOLD}Quick Start:${NC}"
  echo -e "  1. ${CYAN}Mount the encrypted filesystem:${NC}"
  echo -e "     ${GREEN}$ cryptosync-mount-${CLIENT_ID}-${CONFIG_NAME}${NC}"
  echo
  echo -e "  2. ${CYAN}Use the mounted directory to store your files:${NC}"
  echo -e "     ${GREEN}$ cp yourfiles ${MOUNT_DIR}/${NC}"
  echo
  echo -e "  3. ${CYAN}Unmount when done:${NC}"
  echo -e "     ${GREEN}$ cryptosync-unmount-${CLIENT_ID}-${CONFIG_NAME}${NC}"
  echo
  echo -e "  4. ${CYAN}Sync encrypted data to remote:${NC}"
  echo -e "     ${GREEN}$ cryptosync-sync-${CLIENT_ID}-${CONFIG_NAME} [remote-path]${NC}"
  echo
  echo -e "${BOLD}${YELLOW}Note:${NC} Before syncing, make sure to configure your rclone remote properly"
  echo -e "      You can use: ${GREEN}rclone config --config ${CLIENT_DIR}/rclone/rclone.conf${NC}"
  echo
  echo -e "${BOLD}${GREEN}For more information, see the documentation at:${NC}"
  echo -e "  ${CYAN}https://stack.nerdofmouth.com/docs/components/cryptosync.html${NC}"
  echo
}

# Main function
main() {
  # Process command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client-id)
        CLIENT_ID="$2"
        shift 2
        ;;
      --mount-dir)
        MOUNT_DIR="$2"
        shift 2
        ;;
      --remote-name)
        REMOTE_NAME="$2"
        shift 2
        ;;
      --config-name)
        CONFIG_NAME="$2"
        shift 2
        ;;
      --with-deps)
        WITH_DEPS=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --use-cryfs)
        USE_CRYFS=true
        shift
        ;;
      --initial-sync)
        INITIAL_SYNC=true
        shift
        ;;
      --remote-type)
        REMOTE_TYPE="$2"
        shift 2
        ;;
      --remote-path)
        REMOTE_PATH="$2"
        shift 2
        ;;
      --remote-options)
        REMOTE_OPTIONS="$2"
        shift 2
        ;;
      --vault-password)
        VAULT_PASSWORD="$2"
        shift 2
        ;;
      --auto-mount)
        AUTO_MOUNT=true
        shift
        ;;
      --help)
        show_help
        ;;
      *)
        log "ERROR" "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Log the start of installation
  log "INFO" "Starting Cryptosync installation..."
  
  # Run installation steps
  setup_client_dir
  check_requirements
  install_dependencies
  initialize_encrypted_fs
  configure_rclone
  create_helper_scripts
  perform_initial_sync
  auto_mount
  update_registry
  
  # Print summary
  print_summary
  
  # Log completion
  log "INFO" "Cryptosync installation completed successfully"
}

# Execute main function
main "$@"
