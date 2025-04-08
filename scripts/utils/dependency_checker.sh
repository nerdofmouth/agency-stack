#!/bin/bash
# Utility script to ensure all prerequisites are installed and available
# Part of the AgencyStack Alpha Phase repository integrity approach

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils/common.sh
source "$SCRIPT_DIR/common.sh"

# Log initialization
log "INFO" "Starting dependency_checker.sh"

# Function to check and install required dependencies
check_and_install_dependencies() {
  log "INFO" "Checking required dependencies"
  
  # List of required commands
  local required_commands=("docker" "docker-compose" "jq" "git" "curl" "wget")
  local missing_commands=()
  
  # Check which commands are missing
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      log "WARN" "Command not found: $cmd"
      missing_commands+=("$cmd")
    else
      log "INFO" "Command found: $cmd ($(command -v "$cmd"))"
    fi
  done
  
  # If no commands are missing, we're done
  if [ ${#missing_commands[@]} -eq 0 ]; then
    log "SUCCESS" "All required dependencies are installed"
    return 0
  fi
  
  # Log the missing commands
  log "WARN" "Missing dependencies: ${missing_commands[*]}"
  
  # Detect OS
  local os_type
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    os_type=$ID
  elif [ -f /etc/debian_version ]; then
    os_type="debian"
  elif [ -f /etc/redhat-release ]; then
    os_type="rhel"
  else
    os_type="unknown"
  fi
  
  log "INFO" "Detected OS: $os_type"
  
  # Install missing dependencies based on OS
  case "$os_type" in
    debian|ubuntu)
      log "INFO" "Installing dependencies using apt"
      
      # Set non-interactive mode
      export DEBIAN_FRONTEND=noninteractive
      
      # Update package lists
      log "INFO" "Updating package lists"
      apt-get update -q
      
      # Install each missing dependency
      for cmd in "${missing_commands[@]}"; do
        case "$cmd" in
          docker)
            if ! command -v docker &> /dev/null; then
              log "INFO" "Installing Docker"
              if [ -x "$SCRIPT_DIR/../components/install_docker.sh" ]; then
                bash "$SCRIPT_DIR/../components/install_docker.sh"
              else
                log "WARN" "Docker installation script not found or not executable, falling back to apt"
                apt-get install -y docker.io
              fi
            fi
            ;;
          docker-compose)
            if ! command -v docker-compose &> /dev/null; then
              log "INFO" "Installing Docker Compose"
              apt-get install -y docker-compose
            fi
            ;;
          jq)
            if ! command -v jq &> /dev/null; then
              log "INFO" "Installing jq"
              apt-get install -y jq
            fi
            ;;
          git)
            if ! command -v git &> /dev/null; then
              log "INFO" "Installing git"
              apt-get install -y git
            fi
            ;;
          curl)
            if ! command -v curl &> /dev/null; then
              log "INFO" "Installing curl"
              apt-get install -y curl
            fi
            ;;
          wget)
            if ! command -v wget &> /dev/null; then
              log "INFO" "Installing wget"
              apt-get install -y wget
            fi
            ;;
        esac
      done
      ;;
    
    rhel|centos|fedora)
      log "INFO" "Installing dependencies using yum/dnf"
      
      # Determine package manager
      local pkg_manager
      if command -v dnf &> /dev/null; then
        pkg_manager="dnf"
      else
        pkg_manager="yum"
      fi
      
      # Install each missing dependency
      for cmd in "${missing_commands[@]}"; do
        case "$cmd" in
          docker)
            if ! command -v docker &> /dev/null; then
              log "INFO" "Installing Docker"
              if [ -x "$SCRIPT_DIR/../components/install_docker.sh" ]; then
                bash "$SCRIPT_DIR/../components/install_docker.sh"
              else
                log "WARN" "Docker installation script not found or not executable, falling back to package manager"
                $pkg_manager install -y docker
              fi
            fi
            ;;
          docker-compose)
            if ! command -v docker-compose &> /dev/null; then
              log "INFO" "Installing Docker Compose"
              $pkg_manager install -y docker-compose
            fi
            ;;
          jq)
            if ! command -v jq &> /dev/null; then
              log "INFO" "Installing jq"
              $pkg_manager install -y jq
            fi
            ;;
          git)
            if ! command -v git &> /dev/null; then
              log "INFO" "Installing git"
              $pkg_manager install -y git
            fi
            ;;
          curl)
            if ! command -v curl &> /dev/null; then
              log "INFO" "Installing curl"
              $pkg_manager install -y curl
            fi
            ;;
          wget)
            if ! command -v wget &> /dev/null; then
              log "INFO" "Installing wget"
              $pkg_manager install -y wget
            fi
            ;;
        esac
      done
      ;;
    
    *)
      log "ERROR" "Unsupported OS: $os_type"
      log "ERROR" "Cannot automatically install missing dependencies"
      log "ERROR" "Please install the following dependencies manually: ${missing_commands[*]}"
      return 1
      ;;
  esac
  
  # Verify all dependencies are now installed
  local still_missing=()
  for cmd in "${missing_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      still_missing+=("$cmd")
    fi
  done
  
  if [ ${#still_missing[@]} -eq 0 ]; then
    log "SUCCESS" "All dependencies successfully installed"
    return 0
  else
    log "ERROR" "Failed to install some dependencies: ${still_missing[*]}"
    return 1
  fi
}

# Main execution
check_and_install_dependencies
exit_code=$?

if [ $exit_code -eq 0 ]; then
  log "SUCCESS" "Dependency check completed successfully"
  exit 0
else
  log "ERROR" "Dependency check failed with exit code $exit_code"
  exit $exit_code
fi
