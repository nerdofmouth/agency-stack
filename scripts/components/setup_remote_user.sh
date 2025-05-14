#!/bin/bash

# Remote User Setup Script for AgencyStack Deployments
# Follows AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Idempotency & Automation
# - Auditability & Documentation

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Default configuration
REMOTE_HOST=""
SSH_USER="root"
SSH_KEY_PATH=""
NEW_USER="agencystack"
SUDO_ACCESS="true"
FORCE="false"
DRY_RUN="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --remote-host)
      REMOTE_HOST="$2"
      shift
      ;;
    --ssh-user)
      SSH_USER="$2"
      shift
      ;;
    --ssh-key)
      SSH_KEY_PATH="$2"
      shift
      ;;
    --new-user)
      NEW_USER="$2"
      shift
      ;;
    --sudo-access)
      SUDO_ACCESS="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --dry-run)
      DRY_RUN="true"
      ;;
    *)
      # Unknown option
      log_warning "Unknown option: $key"
      ;;
  esac
  shift
done

# Validate required parameters
if [[ -z "${REMOTE_HOST}" ]]; then
  log_error "Remote host (--remote-host) is required"
  exit 1
fi

if [[ -z "${SSH_KEY_PATH}" ]] && [[ -z "${SSH_KEY_FILE}" ]]; then
  SSH_KEY_PATH="${HOME}/.ssh/id_rsa"
  log_warning "No SSH key specified, using default: ${SSH_KEY_PATH}"
fi

# Show configuration
log_info "==================================================="
log_info "Starting setup_remote_user.sh"
log_info "REMOTE_HOST: ${REMOTE_HOST}"
log_info "SSH_USER: ${SSH_USER}"
log_info "NEW_USER: ${NEW_USER}"
log_info "SUDO_ACCESS: ${SUDO_ACCESS}"
log_info "DRY_RUN: ${DRY_RUN}"
log_info "==================================================="

# Function to check SSH connection
check_ssh_connection() {
  log_info "Testing SSH connection to ${SSH_USER}@${REMOTE_HOST}..."
  
  if ssh -i "${SSH_KEY_PATH}" -o BatchMode=yes -o ConnectTimeout=5 "${SSH_USER}@${REMOTE_HOST}" echo "SSH connection successful" > /dev/null 2>&1; then
    log_success "SSH connection successful"
    return 0
  else
    log_error "SSH connection failed"
    return 1
  fi
}

# Function to create user on remote host
create_remote_user() {
  log_info "Checking if user ${NEW_USER} already exists on remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would check if user exists"
    return 0
  fi
  
  # Check if user exists
  if ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "id ${NEW_USER} &>/dev/null"; then
    log_info "User ${NEW_USER} already exists on remote host"
    
    if [[ "${FORCE}" == "true" ]]; then
      log_warning "Force flag is set, recreating user ${NEW_USER}"
      ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "userdel -r ${NEW_USER}"
      user_exists="false"
    else
      user_exists="true"
    fi
  else
    user_exists="false"
  fi
  
  # Create user if it doesn't exist or was forcefully removed
  if [[ "${user_exists}" == "false" ]]; then
    log_info "Creating user ${NEW_USER} on remote host..."
    ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "useradd -m -s /bin/bash ${NEW_USER}"
    
    if [[ "${SUDO_ACCESS}" == "true" ]]; then
      log_info "Granting sudo access to user ${NEW_USER}..."
      ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "usermod -aG sudo ${NEW_USER}"
      ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "echo '${NEW_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${NEW_USER}"
    fi
    
    log_success "User ${NEW_USER} created successfully"
  fi
}

# Function to setup SSH key for the new user
setup_ssh_key() {
  log_info "Setting up SSH key for user ${NEW_USER} on remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would set up SSH key for user"
    return 0
  fi
  
  # Create .ssh directory
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "mkdir -p /home/${NEW_USER}/.ssh"
  
  # Generate SSH key pair if it doesn't exist
  local_deploy_key="${HOME}/.ssh/${NEW_USER}_key"
  if [[ ! -f "${local_deploy_key}" ]]; then
    log_info "Generating new SSH key pair for user ${NEW_USER}..."
    ssh-keygen -t rsa -b 4096 -f "${local_deploy_key}" -N "" -C "${NEW_USER}@${REMOTE_HOST}"
    log_success "SSH key pair generated at ${local_deploy_key}"
  fi
  
  # Copy public key to remote host
  log_info "Copying public key to remote host..."
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "cat > /home/${NEW_USER}/.ssh/authorized_keys" < "${local_deploy_key}.pub"
  
  # Set proper permissions
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "chmod 700 /home/${NEW_USER}/.ssh"
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "chmod 600 /home/${NEW_USER}/.ssh/authorized_keys"
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/.ssh"
  
  log_success "SSH key setup completed for user ${NEW_USER}"
  log_info "Use the following key for deployment: ${local_deploy_key}"
}

# Function to create required directories
create_directories() {
  log_info "Creating required directories for AgencyStack deployment..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would create required directories"
    return 0
  fi
  
  # Create directories following AgencyStack Charter directory structure
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "mkdir -p /opt/agency_stack/clients"
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "mkdir -p /var/log/agency_stack/components"
  
  # Set permissions for the new user
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "chown -R ${NEW_USER}:${NEW_USER} /opt/agency_stack"
  ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "chown -R ${NEW_USER}:${NEW_USER} /var/log/agency_stack"
  
  log_success "Required directories created and permissions set"
}

# Function to verify setup
verify_setup() {
  log_info "Verifying user setup..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would verify user setup"
    return 0
  }
  
  # Verify user exists
  if ! ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "id ${NEW_USER} &>/dev/null"; then
    log_error "User ${NEW_USER} does not exist on remote host"
    return 1
  fi
  
  # Verify sudo access if applicable
  if [[ "${SUDO_ACCESS}" == "true" ]]; then
    if ! ssh -i "${SSH_KEY_PATH}" "${SSH_USER}@${REMOTE_HOST}" "groups ${NEW_USER} | grep -q sudo"; then
      log_warning "User ${NEW_USER} does not have sudo group membership"
      return 1
    fi
  fi
  
  # Verify SSH key setup
  local_deploy_key="${HOME}/.ssh/${NEW_USER}_key"
  if ssh -i "${local_deploy_key}" -o BatchMode=yes -o ConnectTimeout=5 "${NEW_USER}@${REMOTE_HOST}" echo "SSH connection successful" > /dev/null 2>&1; then
    log_success "SSH key authentication successful"
  else
    log_error "SSH key authentication failed"
    return 1
  fi
  
  # Verify directory permissions
  if ssh -i "${local_deploy_key}" "${NEW_USER}@${REMOTE_HOST}" "test -w /opt/agency_stack && test -w /var/log/agency_stack"; then
    log_success "Directory permissions verified"
  else
    log_error "Directory permissions check failed"
    return 1
  fi
  
  log_success "User setup verification completed successfully"
  return 0
}

# Main execution
if ! check_ssh_connection; then
  log_error "Cannot connect to remote host, exiting..."
  exit 1
fi

create_remote_user
setup_ssh_key
create_directories

if verify_setup; then
  log_success "Remote user setup completed successfully"
  log_info "You can now deploy using the following SSH key: ${HOME}/.ssh/${NEW_USER}_key"
else
  log_error "Remote user setup verification failed"
  exit 1
fi
