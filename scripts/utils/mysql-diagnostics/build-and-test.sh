#!/bin/bash
# AgencyStack MySQL Diagnostics Container Builder & Tester
# Following AgencyStack Charter principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Proper Change Workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agencystack-mysql-diagnostics"
CONTAINER_NAME="agencystack-mysql-diag"

# Source common utilities if available
if [ -f "${SCRIPT_DIR}/../../utils/common.sh" ]; then
  source "${SCRIPT_DIR}/../../utils/common.sh"
else
  # Minimal logging functions if common.sh is not found
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

log_info "Building ${IMAGE_NAME} container from Dockerfile"
docker build -t ${IMAGE_NAME} ${SCRIPT_DIR}

log_success "Successfully built ${IMAGE_NAME} container with diagnostic tools"
log_info "Container includes: mariadb-client, ping, netcat, dig, curl"
log_info ""
log_info "To run diagnostics:"
log_info "  docker run --rm -it --network=wordpress_wordpress_network ${IMAGE_NAME} bash"
log_info ""
log_info "Inside the container, test database connectivity:"
log_info "  mysql -h peacefestivalusa_mariadb -u <username> -p<password>"
log_info ""
log_info "Or ping services:"
log_info "  ping peacefestivalusa_mariadb"

# Automatically run the container if requested
if [ "${1:-}" = "--run" ]; then
  log_info "Starting diagnostic container..."
  docker run --rm -it --network=wordpress_wordpress_network ${IMAGE_NAME} bash
fi
