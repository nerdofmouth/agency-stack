#!/bin/bash

# PeaceFestivalUSA WordPress Deployment Script
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Multi-Tenancy & Security
# - Proper Change Workflow

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="peacefestivalusa.localhost"
WP_PORT="8082"
DB_PORT="33061"
ADMIN_EMAIL="admin@peacefestivalusa.com"
LOCAL_DEPLOY="true"
REMOTE_DEPLOY="false"
REMOTE_HOST=""
REMOTE_USER="agencystack"
SSH_KEY_PATH=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --wordpress-port)
      WP_PORT="$2"
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      ;;
    --remote-deploy)
      REMOTE_DEPLOY="$2"
      shift
      ;;
    --remote-host)
      REMOTE_HOST="$2"
      shift
      ;;
    --remote-user)
      REMOTE_USER="$2"
      shift
      ;;
    --ssh-key)
      SSH_KEY_PATH="$2"
      shift
      ;;
    *)
      # Unknown option
      log_warning "Unknown option: $key"
      ;;
  esac
  shift
done

# Show configuration
log_info "==================================================="
log_info "Starting deploy_peacefestivalusa.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "WP_PORT: ${WP_PORT}"
log_info "LOCAL_DEPLOY: ${LOCAL_DEPLOY}"
log_info "REMOTE_DEPLOY: ${REMOTE_DEPLOY}"
if [[ "${REMOTE_DEPLOY}" == "true" ]]; then
  log_info "REMOTE_HOST: ${REMOTE_HOST}"
  log_info "REMOTE_USER: ${REMOTE_USER}"
fi
log_info "==================================================="

# Ensure directories exist
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOST_LOGS_DIR="/var/log/agency_stack/components"
HOST_DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}"

mkdir -p "${HOST_LOGS_DIR}"
mkdir -p "${HOST_DATA_DIR}"

# Function to perform local deployment
local_deploy() {
  log_info "Starting local deployment for ${CLIENT_ID}..."
  
  # Create Docker network
  NETWORK_NAME="${CLIENT_ID}_network"
  if ! docker network ls | grep -q "${NETWORK_NAME}"; then
    log_info "Creating Docker network ${NETWORK_NAME}..."
    docker network create "${NETWORK_NAME}"
  fi
  
  # Setup MariaDB container
  MARIADB_CONTAINER="${CLIENT_ID}_db"
  DB_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
  
  log_info "Setting up MariaDB container..."
  if docker ps -a | grep -q "${MARIADB_CONTAINER}"; then
    log_info "MariaDB container already exists, starting if needed..."
    docker start "${MARIADB_CONTAINER}" || true
  else
    docker run -d \
      --name "${MARIADB_CONTAINER}" \
      --network "${NETWORK_NAME}" \
      -e MYSQL_DATABASE=wordpress \
      -e MYSQL_USER=wordpress \
      -e MYSQL_PASSWORD="${DB_PASSWORD}" \
      -e MYSQL_ROOT_PASSWORD="${ROOT_PASSWORD}" \
      -v "${HOST_DATA_DIR}/db_data:/var/lib/mysql" \
      -p "${DB_PORT}:3306" \
      mariadb:10.11
  fi
  
  # Wait for MariaDB to be ready
  log_info "Waiting for MariaDB to be ready..."
  sleep 10
  
  # Setup WordPress container
  WP_CONTAINER="${CLIENT_ID}_wordpress"
  
  log_info "Setting up WordPress container..."
  if docker ps -a | grep -q "${WP_CONTAINER}"; then
    log_info "WordPress container already exists, starting if needed..."
    docker start "${WP_CONTAINER}" || true
  else
    docker run -d \
      --name "${WP_CONTAINER}" \
      --network "${NETWORK_NAME}" \
      -e WORDPRESS_DB_HOST="${MARIADB_CONTAINER}" \
      -e WORDPRESS_DB_USER=wordpress \
      -e WORDPRESS_DB_PASSWORD="${DB_PASSWORD}" \
      -e WORDPRESS_DB_NAME=wordpress \
      -e WORDPRESS_DEBUG=1 \
      -v "${HOST_DATA_DIR}/wordpress:/var/www/html" \
      -p "${WP_PORT}:80" \
      wordpress:6.4-php8.2-apache
  fi
  
  # Save environment variables for future reference
  ENV_FILE="${HOST_DATA_DIR}/.env"
  cat > "${ENV_FILE}" << EOL
# PeaceFestivalUSA WordPress Environment Variables
# Generated: $(date)
# Following AgencyStack Charter v1.0.3 principles

# Client identification
CLIENT_ID=${CLIENT_ID}
DOMAIN=${DOMAIN}

# WordPress database configuration
WORDPRESS_DB_HOST=${MARIADB_CONTAINER}
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
MYSQL_ROOT_PASSWORD=${ROOT_PASSWORD}

# Container names
WP_CONTAINER=${WP_CONTAINER}
DB_CONTAINER=${MARIADB_CONTAINER}
NETWORK_NAME=${NETWORK_NAME}

# Ports
WP_PORT=${WP_PORT}
DB_PORT=${DB_PORT}
EOL
  
  log_success "Local deployment completed successfully!"
  log_info "WordPress URL: http://localhost:${WP_PORT}"
  log_info "Environment saved to: ${ENV_FILE}"
}

# Function to verify local deployment
verify_local_deployment() {
  log_info "Verifying local deployment..."
  
  # Check if containers are running
  WP_CONTAINER="${CLIENT_ID}_wordpress"
  DB_CONTAINER="${CLIENT_ID}_db"
  
  if docker ps | grep -q "${WP_CONTAINER}"; then
    log_success "WordPress container is running"
  else
    log_error "WordPress container is not running"
  fi
  
  if docker ps | grep -q "${DB_CONTAINER}"; then
    log_success "MariaDB container is running"
  else
    log_error "MariaDB container is not running"
  fi
  
  # Check if WordPress is responding
  log_info "Checking WordPress response..."
  if curl -s "http://localhost:${WP_PORT}" | grep -q "WordPress"; then
    log_success "WordPress is responding correctly"
  else
    log_warning "WordPress may not be fully initialized yet"
  fi
}

# Function to setup remote user
setup_remote_user() {
  if [[ -z "${REMOTE_HOST}" ]] || [[ -z "${SSH_KEY_PATH}" ]]; then
    log_error "Remote host and SSH key path are required for remote deployment"
    return 1
  fi
  
  log_info "Setting up remote user ${REMOTE_USER} on ${REMOTE_HOST}..."
  
  # Check SSH connection as root
  if ! ssh -i "${SSH_KEY_PATH}" -o BatchMode=yes -o ConnectTimeout=5 "root@${REMOTE_HOST}" echo "SSH connection successful" > /dev/null 2>&1; then
    log_error "Cannot connect to remote host as root"
    log_info "Please ensure your SSH key is added to the remote server's root account"
    return 1
  fi
  
  # Create agencystack user if it doesn't exist
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "id ${REMOTE_USER} &>/dev/null || useradd -m -s /bin/bash ${REMOTE_USER}"
  
  # Setup sudo access
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "usermod -aG sudo ${REMOTE_USER}"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "echo '${REMOTE_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${REMOTE_USER}"
  
  # Create required directories
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "mkdir -p /var/log/agency_stack/components"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "mkdir -p /opt/agency_stack/clients/${CLIENT_ID}"
  
  # Set ownership
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "chown -R ${REMOTE_USER}:${REMOTE_USER} /var/log/agency_stack"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "chown -R ${REMOTE_USER}:${REMOTE_USER} /opt/agency_stack"
  
  # Setup SSH key for agencystack user
  local_key="${HOME}/.ssh/${REMOTE_USER}_key"
  if [[ ! -f "${local_key}" ]]; then
    ssh-keygen -t rsa -b 4096 -f "${local_key}" -N "" -C "${REMOTE_USER}@${REMOTE_HOST}"
  fi
  
  # Add SSH key to remote user
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "mkdir -p /home/${REMOTE_USER}/.ssh"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "cat > /home/${REMOTE_USER}/.ssh/authorized_keys" < "${local_key}.pub"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "chmod 700 /home/${REMOTE_USER}/.ssh"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "chmod 600 /home/${REMOTE_USER}/.ssh/authorized_keys"
  ssh -i "${SSH_KEY_PATH}" "root@${REMOTE_HOST}" "chown -R ${REMOTE_USER}:${REMOTE_USER} /home/${REMOTE_USER}/.ssh"
  
  # Test connection as agencystack
  if ssh -i "${local_key}" -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" echo "SSH connection successful" > /dev/null 2>&1; then
    log_success "Remote user setup completed successfully"
    return 0
  else
    log_error "Failed to connect as ${REMOTE_USER}"
    return 1
  fi
}

# Function to perform remote deployment
remote_deploy() {
  if [[ -z "${REMOTE_HOST}" ]] || [[ -z "${SSH_KEY_PATH}" ]]; then
    log_error "Remote host and SSH key path are required for remote deployment"
    return 1
  fi
  
  local_key="${HOME}/.ssh/${REMOTE_USER}_key"
  if [[ ! -f "${local_key}" ]]; then
    log_error "SSH key for ${REMOTE_USER} not found at ${local_key}"
    return 1
  fi
  
  log_info "Starting remote deployment for ${CLIENT_ID}..."
  
  # Copy repository to remote host
  log_info "Copying repository to remote host..."
  rsync -avz --exclude='.git' \
    -e "ssh -i ${local_key}" \
    "${REPO_ROOT}/" \
    "${REMOTE_USER}@${REMOTE_HOST}:/opt/agency_stack/"
  
  # Execute deployment script on remote host
  log_info "Executing deployment script on remote host..."
  ssh -i "${local_key}" "${REMOTE_USER}@${REMOTE_HOST}" "cd /opt/agency_stack && bash scripts/components/deploy_peacefestivalusa.sh --domain ${DOMAIN}"
  
  log_success "Remote deployment initiated successfully"
}

# Main execution
if [[ "${LOCAL_DEPLOY}" == "true" ]]; then
  local_deploy
  verify_local_deployment
fi

if [[ "${REMOTE_DEPLOY}" == "true" ]]; then
  setup_remote_user
  if [[ $? -eq 0 ]]; then
    remote_deploy
  else
    log_error "Remote user setup failed, skipping remote deployment"
  fi
fi

log_success "Deployment script completed successfully"
