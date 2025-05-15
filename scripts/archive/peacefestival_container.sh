#!/bin/bash

# PeaceFestivalUSA Container Setup Script
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
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

# Default configuration
CLIENT_ID="peacefestivalusa"
CONTAINER_NAME="${CLIENT_ID}-deploy"
FORCE="false"
ACTION="run"  # run, stop, status

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --force)
      FORCE="true"
      ;;
    --action)
      ACTION="$2"
      shift
      ;;
    *)
      # Unknown option
      log_warning "Unknown option: $key"
      ;;
  esac
  shift
done

# Check if running in WSL
if grep -q Microsoft /proc/version; then
  log_info "Running in WSL environment"
  IS_WSL="true"
else
  IS_WSL="false"
fi

# Show configuration
log_info "==================================================="
log_info "Starting peacefestival_container.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "CONTAINER_NAME: ${CONTAINER_NAME}"
log_info "ACTION: ${ACTION}"
log_info "==================================================="

# Set paths
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOST_LOGS_DIR="/var/log/agency_stack/components"
HOST_DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}"

# Ensure host directories exist
mkdir -p "${HOST_LOGS_DIR}"
mkdir -p "${HOST_DATA_DIR}"

# Function to create and run container
create_and_run_container() {
  log_info "Creating and running container for ${CLIENT_ID}..."
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if [[ "${FORCE}" == "true" ]]; then
      log_warning "Force flag set, removing existing container..."
      docker rm -f "${CONTAINER_NAME}"
    else
      log_info "Container ${CONTAINER_NAME} already exists"
      docker start "${CONTAINER_NAME}"
      docker exec -it "${CONTAINER_NAME}" bash
      return
    fi
  fi
  
  # Create and run container with proper mounts
  log_info "Running new container ${CONTAINER_NAME}..."
  docker run -it --name "${CONTAINER_NAME}" \
    -v "${REPO_ROOT}:/agency_stack:ro" \
    -v "${HOST_LOGS_DIR}:/var/log/agency_stack/components" \
    -v "${HOST_DATA_DIR}:/opt/agency_stack/clients/${CLIENT_ID}" \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    --network host \
    --env CLIENT_ID="${CLIENT_ID}" \
    --env IS_WSL="${IS_WSL}" \
    docker:dind bash -c "
      echo 'Setting up Docker-in-Docker environment for PeaceFestivalUSA deployment...' && 
      mkdir -p /agency_stack_writable &&
      cp -r /agency_stack/* /agency_stack_writable/ &&
      cd /agency_stack_writable &&
      echo 'Ready to deploy PeaceFestivalUSA following AgencyStack Charter principles!' &&
      echo 'Run: bash scripts/components/install_peacefestivalusa_wordpress.sh' &&
      bash
    "
}

# Function to stop container
stop_container() {
  log_info "Stopping container ${CONTAINER_NAME}..."
  docker stop "${CONTAINER_NAME}"
  log_success "Container stopped"
}

# Function to show container status
show_status() {
  log_info "Container status for ${CONTAINER_NAME}:"
  
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_success "Container ${CONTAINER_NAME} is running"
    docker ps -f "name=${CONTAINER_NAME}" --format "ID: {{.ID}}, Status: {{.Status}}, Ports: {{.Ports}}"
  elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warning "Container ${CONTAINER_NAME} exists but is not running"
    docker ps -a -f "name=${CONTAINER_NAME}" --format "ID: {{.ID}}, Status: {{.Status}}"
  else
    log_error "Container ${CONTAINER_NAME} does not exist"
  fi
}

# Main execution based on action
case "${ACTION}" in
  run)
    create_and_run_container
    ;;
  stop)
    stop_container
    ;;
  status)
    show_status
    ;;
  *)
    log_error "Unknown action: ${ACTION}"
    exit 1
    ;;
esac

log_success "Script completed successfully"
