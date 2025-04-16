#!/bin/bash
# setup_ssh_keys.sh - Configure SSH key-based authentication for deployment
#
# This script creates and deploys SSH keys for passwordless access to deployment targets
# Following the AgencyStack Alpha Phase Repository Integrity Policy

set -e

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Fallback logging functions if common.sh is not available
if ! command -v log_info &> /dev/null; then
  log_info() { echo "[INFO] $1"; }
  log_error() { echo "[ERROR] $1" >&2; }
  log_success() { echo "[SUCCESS] $1"; }
fi

# Default settings
TARGET_HOST=""
SSH_KEY_FILE="${HOME}/.ssh/id_rsa_agencystack"
FORCE_NEW_KEY=false
SSH_PORT=22
SSH_USER="root"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_HOST="$2"
      shift 2
      ;;
    --key-file)
      SSH_KEY_FILE="$2"
      shift 2
      ;;
    --force-new-key)
      FORCE_NEW_KEY=true
      shift
      ;;
    --port)
      SSH_PORT="$2"
      shift 2
      ;;
    --user)
      SSH_USER="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --target TARGET       Target host to set up SSH keys for"
      echo "  --key-file FILE       Path to SSH key file (default: ~/.ssh/id_rsa_agencystack)"
      echo "  --force-new-key       Force creation of a new key even if one exists"
      echo "  --port PORT           SSH port (default: 22)"
      echo "  --user USER           SSH user (default: root)"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if target host is provided
if [[ -z "$TARGET_HOST" ]]; then
  log_error "No target host specified. Use --target option."
  exit 1
fi

# Create SSH key if it doesn't exist or if forced
if [[ ! -f "$SSH_KEY_FILE" ]] || [[ "$FORCE_NEW_KEY" == "true" ]]; then
  log_info "Generating new SSH key at: $SSH_KEY_FILE"
  
  # Create .ssh directory if needed
  mkdir -p "$(dirname "$SSH_KEY_FILE")"
  
  # Generate key with empty passphrase
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_FILE" -N "" -C "agencystack-deployment-$(date +%Y%m%d)"
  
  log_success "SSH key generated successfully"
else
  log_info "Using existing SSH key: $SSH_KEY_FILE"
fi

# Get or create default SSH config
SSH_CONFIG_FILE="${HOME}/.ssh/config"
if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
  log_info "Creating SSH config file"
  mkdir -p "$(dirname "$SSH_CONFIG_FILE")"
  touch "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
fi

# Check if host already exists in config
if grep -q "Host $TARGET_HOST" "$SSH_CONFIG_FILE"; then
  log_info "Updating existing host entry for $TARGET_HOST"
  # Remove existing host entry
  sed -i "/Host $TARGET_HOST/,/^$/d" "$SSH_CONFIG_FILE"
fi

# Add host to SSH config
log_info "Adding host configuration to SSH config"
cat >> "$SSH_CONFIG_FILE" <<EOT

Host $TARGET_HOST
    HostName $TARGET_HOST
    User $SSH_USER
    Port $SSH_PORT
    IdentityFile $SSH_KEY_FILE
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOT

log_success "SSH config updated for $TARGET_HOST"

# Deploy the public key to the target host
log_info "Deploying SSH public key to $TARGET_HOST..."
log_info "You will be prompted for the password ONE LAST TIME:"

SSH_PUBKEY=$(cat "${SSH_KEY_FILE}.pub")

# Try using ssh-copy-id first (more reliable)
if command -v ssh-copy-id &> /dev/null; then
  ssh-copy-id -i "${SSH_KEY_FILE}.pub" -p "$SSH_PORT" "${SSH_USER}@${TARGET_HOST}"
else
  # Fallback to manual approach
  ssh -p "$SSH_PORT" "${SSH_USER}@${TARGET_HOST}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$SSH_PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

# Verify key-based access
log_info "Verifying SSH key-based authentication..."
if ssh -i "$SSH_KEY_FILE" -o "BatchMode=yes" -p "$SSH_PORT" "${SSH_USER}@${TARGET_HOST}" "echo 'SSH key authentication successful'"; then
  log_success "SSH key-based authentication is working!"
  log_info "You can now access $TARGET_HOST without a password"
else
  log_error "SSH key authentication failed. Please check the target server configuration."
  exit 1
fi

log_success "Setup complete for passwordless access to $TARGET_HOST"
