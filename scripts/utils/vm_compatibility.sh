#!/bin/bash

# VM Compatibility Module for AgencyStack
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as source of truth
# - Strict containerization across environments
# - Multi-tenancy & security

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Function to detect environment type
detect_environment() {
  # Check if running in a VM
  if [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
    echo "vm"
    return
  fi
  
  # Check if running in WSL
  if [ -f /proc/version ] && grep -q "Microsoft" /proc/version; then
    echo "wsl"
    return
  fi
  
  # Check if running in Docker
  if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "docker"
    return
  fi
  
  # Default to unknown
  echo "unknown"
}

# Function to get appropriate installation paths based on environment
get_installation_paths() {
  local client_id=$1
  local env_type=$(detect_environment)
  
  # Define base paths by environment type
  case "$env_type" in
    vm)
      # VM environments follow standard installation paths
      echo "INSTALL_BASE_DIR=/opt/agency_stack"
      echo "LOG_DIR=/var/log/agency_stack/components"
      echo "NETWORK_MODE=bridge"
      ;;
    wsl)
      # WSL environments may need special handling for Docker socket
      echo "INSTALL_BASE_DIR=/opt/agency_stack"
      echo "LOG_DIR=/var/log/agency_stack/components"
      echo "DOCKER_SOCK=/var/run/docker.sock"
      echo "NETWORK_MODE=host"
      ;;
    docker)
      # In Docker-in-Docker, use container paths
      echo "INSTALL_BASE_DIR=${HOME}/.agencystack"
      echo "LOG_DIR=${HOME}/.agencystack/logs"
      echo "DOCKER_SOCK=/var/run/docker.sock"
      echo "NETWORK_MODE=host"
      ;;
    *)
      # Default fallback paths
      echo "INSTALL_BASE_DIR=/opt/agency_stack"
      echo "LOG_DIR=/var/log/agency_stack/components"
      echo "NETWORK_MODE=bridge"
      ;;
  esac
}

# Function to adapt Docker Compose for different environments
adapt_docker_compose() {
  local compose_file=$1
  local env_type=$(detect_environment)
  
  case "$env_type" in
    vm)
      # Ensure ports are properly exposed in VM environment
      log_info "Adapting Docker Compose for VM environment..."
      # No specific changes needed for standard VM
      ;;
    wsl)
      # In WSL, ensure Docker socket mounting and network mode
      log_info "Adapting Docker Compose for WSL environment..."
      # Set network mode to "host" if needed
      if [ -f "$compose_file" ]; then
        sed -i 's/network_mode:.*/network_mode: host/' "$compose_file" || true
      fi
      ;;
    docker)
      # In Docker-in-Docker, ensure proper socket mounting
      log_info "Adapting Docker Compose for Docker-in-Docker environment..."
      # Use container-specific paths
      if [ -f "$compose_file" ]; then
        sed -i 's/network_mode:.*/network_mode: host/' "$compose_file" || true
      fi
      ;;
  esac
}

# Function to check VM requirements
check_vm_requirements() {
  local env_type=$(detect_environment)
  
  # Only perform checks in VM environment
  if [ "$env_type" = "vm" ]; then
    log_info "Checking VM requirements..."
    
    # Check for sufficient disk space
    local free_space=$(df -m /opt | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 1024 ]; then
      log_warning "Low disk space: ${free_space}MB free. Recommended: at least 1GB."
    else
      log_info "Disk space check: ${free_space}MB free. ✓"
    fi
    
    # Check for sufficient memory
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 2048 ]; then
      log_warning "Low memory: ${total_mem}MB available. Recommended: at least 2GB."
    else
      log_info "Memory check: ${total_mem}MB available. ✓"
    fi
    
    # Check for Docker installation
    if ! command -v docker &> /dev/null; then
      log_error "Docker is not installed in this VM. Please install Docker first."
      return 1
    else
      log_info "Docker installation check: ✓"
    fi
    
    # Check for Docker service status
    if ! systemctl is-active --quiet docker; then
      log_warning "Docker service is not running. Attempting to start..."
      systemctl start docker || {
        log_error "Failed to start Docker service. Please start it manually."
        return 1
      }
    else
      log_info "Docker service check: ✓"
    fi
  fi
  
  return 0
}

# Function to prepare environment for component installation
prepare_environment() {
  local client_id=$1
  local env_type=$(detect_environment)
  
  log_info "Preparing environment for ${client_id} in ${env_type} environment..."
  
  # Load paths
  eval "$(get_installation_paths "$client_id")"
  
  # Create required directories
  log_info "Creating required directories..."
  mkdir -p "${INSTALL_BASE_DIR}/clients/${client_id}" || true
  mkdir -p "${LOG_DIR}" || true
  
  # Environment-specific preparation
  case "$env_type" in
    vm)
      # VM-specific preparations
      log_info "Performing VM-specific preparations..."
      # Ensure Docker permissions are correct
      if getent group docker > /dev/null; then
        current_user=$(whoami)
        if ! groups $current_user | grep -q docker; then
          log_warning "Current user is not in the docker group. Some operations may require sudo."
        fi
      fi
      ;;
    wsl)
      # WSL-specific preparations
      log_info "Performing WSL-specific preparations..."
      # Ensure Docker socket is accessible
      if [ ! -S "/var/run/docker.sock" ]; then
        log_warning "Docker socket not found at /var/run/docker.sock"
        log_warning "Please ensure Docker Desktop is running and properly configured with WSL2."
      fi
      ;;
    docker)
      # Docker-in-Docker preparations
      log_info "Performing Docker-in-Docker preparations..."
      # Ensure Docker socket is mounted
      if [ ! -S "/var/run/docker.sock" ]; then
        log_error "Docker socket not found. Container must be started with -v /var/run/docker.sock:/var/run/docker.sock"
        return 1
      fi
      ;;
  esac
  
  return 0
}

# Export functions
export -f detect_environment
export -f get_installation_paths
export -f adapt_docker_compose
export -f check_vm_requirements
export -f prepare_environment
