#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Verification: peacefestivalusa_wordpress
# Path: /scripts/components/verify_peacefestivalusa_wordpress.sh
#
# Basic health check script following TDD Protocol
# This script performs essential verification of the PeaceFestivalUSA WordPress implementation.

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="${DOMAIN:-peacefestivalusa.nerdofmouth.com}"
DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}/wordpress"
LOG_DIR="/var/log/agency_stack/clients/${CLIENT_ID}"
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_db"
ADMINER_CONTAINER_NAME="${CLIENT_ID}_adminer"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift ;;
    --client-id) CLIENT_ID="$2"; shift ;;
    --help) 
      echo "Usage: $0 [--domain example.com] [--client-id peacefestivalusa]"
      exit 0 
      ;;
    *) log_error "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

log_info "Running basic verification for PeaceFestivalUSA WordPress..."

# Check if component is installed
if [[ ! -d "$DATA_DIR" ]]; then
  log_error "PeaceFestivalUSA WordPress not installed at $DATA_DIR"
  exit 1
fi

# Check if containers are running
wp_running=false
db_running=false
adminer_running=false

if docker ps --format "{{.Names}}" | grep -q "$WORDPRESS_CONTAINER_NAME"; then
  wp_running=true
  log_success "WordPress container is running"
else
  log_error "WordPress container is not running"
fi

if docker ps --format "{{.Names}}" | grep -q "$MARIADB_CONTAINER_NAME"; then
  db_running=true
  log_success "MariaDB container is running"
else
  log_error "MariaDB container is not running"
fi

if docker ps --format "{{.Names}}" | grep -q "$ADMINER_CONTAINER_NAME"; then
  adminer_running=true
  log_success "Adminer container is running"
else
  log_warning "Adminer container is not running (optional)"
fi

# Check WordPress health via curl
if $wp_running; then
  log_info "Checking WordPress health via HTTP..."
  
  # Docker network inspection for internal testing
  if docker exec "$WORDPRESS_CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
    log_success "WordPress is responding to internal HTTP requests"
  else
    log_error "WordPress is not responding to internal HTTP requests"
  fi
  
  # External domain check (if domain is configured)
  if [[ "$DOMAIN" != "peacefestivalusa.nerdofmouth.com" ]]; then
    if curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" | grep -q -E "200|301|302"; then
      log_success "WordPress is responding at https://${DOMAIN}"
    else
      log_warning "WordPress is not responding at https://${DOMAIN}"
    fi
  else
    log_info "Skipping external domain check (using default domain)"
  fi
fi

# Check database connection
if $wp_running && $db_running; then
  log_info "Checking WordPress database connection..."
  
  if docker exec "$WORDPRESS_CONTAINER_NAME" php -r 'if(file_exists("/var/www/html/wp-config.php")) { include("/var/www/html/wp-config.php"); try { $conn = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME); echo $conn->server_info; $conn->close(); exit(0); } catch(Exception $e) { exit(1); } } else { exit(1); }'; then
    log_success "WordPress database connection successful"
  else
    log_error "WordPress cannot connect to database"
  fi
fi

# Summary
log_info "==== PeaceFestivalUSA WordPress Status ===="
log_info "Client: $CLIENT_ID"
log_info "Domain: $DOMAIN"
log_info "WordPress container: $([ "$wp_running" = true ] && echo "Running" || echo "Not running")"
log_info "Database container: $([ "$db_running" = true ] && echo "Running" || echo "Not running")"
log_info "Adminer container: $([ "$adminer_running" = true ] && echo "Running" || echo "Not running")"

if $wp_running && $db_running; then
  log_success "Basic verification completed successfully"
  exit 0
else
  log_error "Basic verification failed"
  exit 1
fi
