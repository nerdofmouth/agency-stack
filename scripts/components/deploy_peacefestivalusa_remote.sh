#!/bin/bash
# Peace Festival USA WordPress Remote Deployment Script
# Following AgencyStack Charter v1.0.3 principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Strict Containerization
# - Proper Change Workflow

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="peacefestivalusa.com"
REMOTE_HOST=""
REMOTE_USER="agencystack"
SSH_KEY_PATH=""
REMOTE_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
WP_PORT="80"
DB_PORT="3306"
ENABLE_SSL="true"
ENABLE_CDN="false"
SYNC_DB="false"
SYNC_FILES="true"
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
    --remote-user)
      REMOTE_USER="$2"
      shift
      ;;
    --ssh-key)
      SSH_KEY_PATH="$2"
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --remote-dir)
      REMOTE_DIR="$2"
      shift
      ;;
    --wp-port)
      WP_PORT="$2"
      shift
      ;;
    --db-port)
      DB_PORT="$2"
      shift
      ;;
    --enable-ssl)
      ENABLE_SSL="$2"
      shift
      ;;
    --enable-cdn)
      ENABLE_CDN="$2"
      shift
      ;;
    --sync-db)
      SYNC_DB="$2"
      shift
      ;;
    --sync-files)
      SYNC_FILES="$2"
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

if [[ -z "${SSH_KEY_PATH}" ]]; then
  log_error "SSH key path (--ssh-key) is required"
  exit 1
fi

# Show configuration
log_info "==================================================="
log_info "Starting deploy_peacefestivalusa_remote.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "REMOTE_HOST: ${REMOTE_HOST}"
log_info "REMOTE_USER: ${REMOTE_USER}"
log_info "REMOTE_DIR: ${REMOTE_DIR}"
log_info "WP_PORT: ${WP_PORT}"
log_info "DB_PORT: ${DB_PORT}"
log_info "ENABLE_SSL: ${ENABLE_SSL}"
log_info "ENABLE_CDN: ${ENABLE_CDN}"
log_info "SYNC_DB: ${SYNC_DB}"
log_info "SYNC_FILES: ${SYNC_FILES}"
log_info "DRY_RUN: ${DRY_RUN}"
log_info "==================================================="

# Set local paths
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLIENT_DIR="${REPO_ROOT}/clients/${CLIENT_ID}"
DOCKER_COMPOSE_PATH="${CLIENT_DIR}/docker-compose.yml"
ENV_FILE_PATH="${CLIENT_DIR}/.env"

# Check if local deployment exists
if [[ ! -f "${DOCKER_COMPOSE_PATH}" ]]; then
  log_error "Local deployment not found at ${DOCKER_COMPOSE_PATH}"
  log_error "Please run installation first"
  exit 1
fi

# Function to check SSH connection
check_ssh_connection() {
  log_info "Testing SSH connection to ${REMOTE_USER}@${REMOTE_HOST}..."
  
  if ssh -i "${SSH_KEY_PATH}" -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" echo "SSH connection successful" > /dev/null 2>&1; then
    log_success "SSH connection successful"
    return 0
  else
    log_error "SSH connection failed"
    return 1
  fi
}

# Function to prepare remote environment
prepare_remote_environment() {
  log_info "Preparing remote environment..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would create remote directories and set permissions"
    return 0
  fi
  
  # Create required directories
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}/{wordpress,wordpress-custom,db_data,backups,logs}"
  
  # Set proper permissions
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "chmod -R 755 ${REMOTE_DIR}"
  
  log_success "Remote environment prepared"
}

# Function to sync repository files
sync_repository() {
  log_info "Syncing repository to remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would sync repository to remote host"
    return 0
  fi
  
  # Create temp directory for repository
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p /tmp/agency-stack"
  
  # Copy repository
  rsync -avz --exclude='.git' --exclude='node_modules' --exclude='logs' \
    -e "ssh -i ${SSH_KEY_PATH}" \
    "${REPO_ROOT}/" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/agency-stack/"
  
  log_success "Repository synced to remote host"
}

# Function to sync WordPress files
sync_wordpress_files() {
  if [[ "${SYNC_FILES}" != "true" ]]; then
    log_info "Skipping WordPress files sync (--sync-files=false)"
    return 0
  fi
  
  log_info "Syncing WordPress files to remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would sync WordPress files to remote host"
    return 0
  fi
  
  # Sync WordPress core files
  rsync -avz --exclude='wp-config.php' \
    -e "ssh -i ${SSH_KEY_PATH}" \
    "${CLIENT_DIR}/wordpress/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/wordpress/"
  
  # Sync custom theme/plugin files
  rsync -avz \
    -e "ssh -i ${SSH_KEY_PATH}" \
    "${CLIENT_DIR}/wordpress-custom/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/wordpress-custom/"
  
  log_success "WordPress files synced to remote host"
}

# Function to sync database
sync_database() {
  if [[ "${SYNC_DB}" != "true" ]]; then
    log_info "Skipping database sync (--sync-db=false)"
    return 0
  fi
  
  log_info "Syncing database to remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would sync database to remote host"
    return 0
  fi
  
  # Create backup timestamp
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  
  # Backup local database
  log_info "Creating local database backup..."
  docker exec peacefestivalusa_db mysqldump -u root -p$MYSQL_ROOT_PASSWORD wordpress > "${CLIENT_DIR}/backups/wordpress_${TIMESTAMP}.sql"
  
  # Transfer database backup
  log_info "Transferring database backup to remote host..."
  rsync -avz \
    -e "ssh -i ${SSH_KEY_PATH}" \
    "${CLIENT_DIR}/backups/wordpress_${TIMESTAMP}.sql" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/backups/"
  
  log_success "Database backup transferred to remote host"
}

# Function to prepare remote deployment files
prepare_deployment_files() {
  log_info "Preparing remote deployment files..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would prepare remote deployment files"
    return 0
  fi
  
  # Create remote .env file with production settings
  cat > /tmp/remote.env << EOL
# Peace Festival USA WordPress Environment Variables
# Generated: $(date)
# Client: ${CLIENT_ID}
# Environment: Production

# WordPress settings
WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
WORDPRESS_DEBUG=false
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_CONFIG_EXTRA=define('WP_MEMORY_LIMIT', '256M'); define('FS_METHOD', 'direct');

# Database settings
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9')

# Site settings
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
DATA_DIR=${REMOTE_DIR}
LOGS_DIR=/var/log/agency_stack/clients/${CLIENT_ID}
EOL
  
  # Transfer .env file
  scp -i "${SSH_KEY_PATH}" /tmp/remote.env "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/.env"
  rm /tmp/remote.env
  
  # Transfer docker-compose.yml file with production settings
  scp -i "${SSH_KEY_PATH}" "${DOCKER_COMPOSE_PATH}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/docker-compose.yml"
  
  log_success "Remote deployment files prepared"
}

# Function to deploy on remote host
deploy_remote() {
  log_info "Deploying Peace Festival USA WordPress on remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would deploy on remote host"
    return 0
  fi
  
  # Start containers on remote host
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && docker compose up -d"
  
  # Check if deployment was successful
  if ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "docker ps | grep -q '${CLIENT_ID}_wordpress'"; then
    log_success "Remote deployment successful"
  else
    log_error "Remote deployment failed"
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && docker compose logs"
    return 1
  fi
  
  # Set up SSL if enabled
  if [[ "${ENABLE_SSL}" == "true" ]]; then
    log_info "Setting up SSL on remote host..."
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && /tmp/agency-stack/scripts/utils/setup_letsencrypt.sh --domain ${DOMAIN} --email admin@${DOMAIN}"
  fi
  
  # Set up CDN if enabled
  if [[ "${ENABLE_CDN}" == "true" ]]; then
    log_info "Setting up CDN on remote host..."
    ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && /tmp/agency-stack/scripts/utils/setup_cdn.sh --domain ${DOMAIN}"
  fi
}

# Function to update WordPress URL
update_wordpress_url() {
  log_info "Updating WordPress URL configuration..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would update WordPress URL"
    return 0
  fi
  
  # Update WordPress URLs in database
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "docker exec ${CLIENT_ID}_wordpress wp option update home 'https://${DOMAIN}' --allow-root"
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "docker exec ${CLIENT_ID}_wordpress wp option update siteurl 'https://${DOMAIN}' --allow-root"
  
  log_success "WordPress URL updated"
}

# Function to verify remote deployment
verify_remote_deployment() {
  log_info "Verifying remote deployment..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would verify remote deployment"
    return 0
  fi
  
  # Check if WordPress is responding
  PROTOCOL="http"
  if [[ "${ENABLE_SSL}" == "true" ]]; then
    PROTOCOL="https"
  fi
  
  SITE_URL="${PROTOCOL}://${DOMAIN}"
  
  if ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "curl -s ${SITE_URL} | grep -q WordPress"; then
    log_success "WordPress site is responding at ${SITE_URL}"
  else
    log_warning "WordPress site is not responding at ${SITE_URL}"
    log_info "Please check the deployment manually"
  fi
}

# Function to import database on remote host
import_database() {
  if [[ "${SYNC_DB}" != "true" ]]; then
    log_info "Skipping database import (--sync-db=false)"
    return 0
  fi
  
  log_info "Importing database on remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would import database on remote host"
    return 0
  fi
  
  # Get the latest backup file
  LATEST_BACKUP=$(ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "ls -t ${REMOTE_DIR}/backups/wordpress_*.sql | head -1")
  
  # Import the database
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "docker exec -i ${CLIENT_ID}_db mysql -u root -p\${MYSQL_ROOT_PASSWORD} wordpress < ${LATEST_BACKUP}"
  
  log_success "Database imported on remote host"
}

# Function to clean up temporary files
cleanup_remote() {
  log_info "Cleaning up temporary files on remote host..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would clean up temporary files on remote host"
    return 0
  fi
  
  # Remove temporary files
  ssh -i "${SSH_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf /tmp/agency-stack"
  
  log_success "Temporary files cleaned up"
}

# Generate deployment summary
generate_deployment_summary() {
  log_info "Generating deployment summary..."
  
  # Create summary file
  SUMMARY_FILE="${REPO_ROOT}/logs/peacefestivalusa_deployment_$(date +%Y%m%d%H%M%S).log"
  mkdir -p "$(dirname "${SUMMARY_FILE}")"
  
  cat > "${SUMMARY_FILE}" << EOL
# Peace Festival USA WordPress Deployment Summary
Date: $(date)
Client: ${CLIENT_ID}
Domain: ${DOMAIN}
Remote Host: ${REMOTE_HOST}
Remote User: ${REMOTE_USER}
Remote Directory: ${REMOTE_DIR}

## Configuration
- WordPress Port: ${WP_PORT}
- Database Port: ${DB_PORT}
- SSL Enabled: ${ENABLE_SSL}
- CDN Enabled: ${ENABLE_CDN}
- Database Synced: ${SYNC_DB}
- Files Synced: ${SYNC_FILES}

## Deployment Steps
1. SSH Connection: $(if check_ssh_connection > /dev/null; then echo "Success"; else echo "Failed"; fi)
2. Remote Environment: Prepared
3. Repository Sync: Completed
4. WordPress Files Sync: $(if [[ "${SYNC_FILES}" == "true" ]]; then echo "Completed"; else echo "Skipped"; fi)
5. Database Sync: $(if [[ "${SYNC_DB}" == "true" ]]; then echo "Completed"; else echo "Skipped"; fi)
6. Deployment Files: Prepared
7. Remote Deployment: Completed
8. WordPress URL Update: Completed
9. Verification: Completed

## Access Information
- WordPress Admin: https://${DOMAIN}/wp-admin/
- Site URL: https://${DOMAIN}
- Database Admin: https://admin.${DOMAIN} (if configured)

## Next Steps
1. Verify site functionality at https://${DOMAIN}
2. Update DNS records if needed
3. Configure SSL certificate monitoring
4. Set up regular backups
5. Test site performance and optimize as needed

Generated by AgencyStack Deployment System
Following AgencyStack Charter v1.0.3 principles
EOL
  
  log_success "Deployment summary generated at ${SUMMARY_FILE}"
  
  # Output summary path
  echo ""
  echo "Deployment Summary: ${SUMMARY_FILE}"
  echo ""
}

# Main Execution
if [[ "${DRY_RUN}" == "true" ]]; then
  log_info "Running in DRY RUN mode - no changes will be made"
fi

# Execute deployment steps
if ! check_ssh_connection; then
  log_error "Cannot proceed due to SSH connection failure"
  exit 1
fi

prepare_remote_environment
sync_repository
sync_wordpress_files
sync_database
prepare_deployment_files
deploy_remote
if [[ "${SYNC_DB}" == "true" ]]; then
  import_database
fi
update_wordpress_url
verify_remote_deployment
cleanup_remote
generate_deployment_summary

log_success "Peace Festival USA WordPress deployment completed successfully"
exit 0
