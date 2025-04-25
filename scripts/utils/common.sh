#!/bin/bash
# common.sh - Core utility functions for AgencyStack installation scripts
# 
# This script provides logging, error handling, and safety functions that should be
# included in all component installation scripts to ensure consistency and reliability.
#
# Usage: source "$(dirname "$0")/../utils/common.sh"

set -euo pipefail

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- BEGIN: AgencyStack Standard Error Trap ---
trap_agencystack_errors() {
    trap 'agencystack_error_handler ${LINENO} $?' ERR
    set -E
}

agencystack_error_handler() {
    local lineno="$1"
    local errcode="$2"
    local scriptname="${BASH_SOURCE[1]:-unknown}"
    local msg="[FAILURE] ${scriptname} failed at line ${lineno} with exit code ${errcode}."
    echo -e "${RED}${msg}${NC}" >&2
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "${msg}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    # Optionally print stack trace for debugging
    if command -v caller &>/dev/null; then
        echo "Stack trace:" >&2
        caller
    fi
    exit ${errcode}
}
# Usage: Add `trap_agencystack_errors` near the top of any install script after sourcing common.sh
# --- END: AgencyStack Standard Error Trap ---

# Set default values
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
VERBOSE="${VERBOSE:-false}"

# Ensure log directory exists
LOG_DIR="/var/log/agency_stack/components"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

# Add a function to detect if running inside a container
is_running_in_container() {
  if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
    return 0  # true
  else
    return 1  # false
  fi
}

# Add a function to ensure log directory is writable 
ensure_log_directory() {
  local log_dir="$1"
  
  # Create the directory if it doesn't exist
  mkdir -p "$log_dir" 2>/dev/null || true
  
  # Check if we can write to it
  if [ ! -w "$log_dir" ]; then
    # Create an alternative in the user's home directory
    local alt_dir="${HOME}/.logs/agency_stack"
    mkdir -p "$alt_dir" 2>/dev/null
    echo "$alt_dir"
  else
    echo "$log_dir"
  fi
}

# Auto-detect if we're running in a Docker container and set a global flag
if is_running_in_container; then
  export CONTAINER_RUNNING=true
  log_info "Detected Docker-in-Docker environment, enabling container compatibility mode"
else
  export CONTAINER_RUNNING=false
fi

# Configure proper DB hostnames for docker-in-docker environments
configure_docker_network_mode() {
  # Auto-detect if we're running inside a Docker container
  if is_running_in_container; then
    log_info "Detected Docker-in-Docker environment, configuring for container networking"
    
    # Use container names instead of service names in docker-compose networks
    USE_CONTAINER_NAMES=true
    export USE_CONTAINER_NAMES
    
    # Ensure /etc/hosts has localhost entries
    if ! grep -q "wordpress.localhost" /etc/hosts 2>/dev/null; then
      echo "127.0.0.1 wordpress.localhost" >> "${HOME}/.dind_hosts"
      log_info "Added wordpress.localhost to ${HOME}/.dind_hosts"
    fi
    
    if ! grep -q "dashboard.localhost" /etc/hosts 2>/dev/null; then
      echo "127.0.0.1 dashboard.localhost" >> "${HOME}/.dind_hosts"
      log_info "Added dashboard.localhost to ${HOME}/.dind_hosts"
    fi
    
    # Return true to indicate we're in a container
    return 0
  fi
  
  # Not in a container
  return 1
}

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [INFO] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[${timestamp}] [INFO] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_success() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${GREEN}SUCCESS${NC}] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [SUCCESS] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_warning() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${YELLOW}WARNING${NC}] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [WARNING] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${RED}ERROR${NC}] ${message}" >&2
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [ERROR] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Safety functions
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        return 1
    fi
    return 0
}

# Ensure scripts are executable
ensure_executable() {
    local script_path="$1"
    if [[ -f "$script_path" && ! -x "$script_path" ]]; then
        log_warning "Script $script_path is not executable, fixing permissions"
        chmod +x "$script_path" || log_error "Failed to set executable permission on $script_path"
    fi
}

ensure_directory() {
    local dir="$1"
    local permissions="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        log_info "Creating directory: $dir"
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
        chmod "$permissions" "$dir" 2>/dev/null || {
            log_warning "Failed to set permissions on: $dir"
        }
    fi
    return 0
}

# Function to safely replace a string in a file
safe_replace() {
    local file="$1"
    local search="$2"
    local replace="$3"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Create backup
    cp "$file" "${file}.bak" || {
        log_error "Failed to create backup of: $file"
        return 1
    }
    
    # Perform replacement
    sed -i "s|${search}|${replace}|g" "$file" || {
        log_error "Failed to perform replacement in: $file"
        # Restore backup
        mv "${file}.bak" "$file"
        return 1
    }
    
    # Remove backup on success
    rm "${file}.bak"
    return 0
}

# Function to mark a component as installed
mark_installed() {
    local component="$1"
    local install_dir="${2:-/opt/agency_stack/clients/${CLIENT_ID}/${component}}"
    
    ensure_directory "$install_dir"
    touch "${install_dir}/.installed_ok"
    log_info "Marked ${component} as installed"
    
    # Update component registry if available
    if command -v update_component_registry.sh &> /dev/null; then
        "$(dirname "$0")/../utils/update_component_registry.sh" \
            --component="$component" \
            --flag="installed" \
            --value="true" || log_warning "Failed to update component registry"
    fi
}

# Function to check if a component is already installed
is_component_installed() {
    local component="$1"
    local install_dir="${2:-/opt/agency_stack/clients/${CLIENT_ID}/${component}}"
    
    if [[ -d "$install_dir" && -f "${install_dir}/.installed_ok" ]]; then
        return 0  # Already installed
    fi
    return 1  # Not installed
}

# Function to handle script cleanup on exit
cleanup() {
    # Perform any necessary cleanup here
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
    
    # Log completion
    if [[ "${SCRIPT_SUCCESS:-}" == "false" ]]; then
        # Only log error if script explicitly set SCRIPT_SUCCESS=false
        log_error "Script did not complete successfully"
    else
        # Default to success if not explicitly marked as failed
        log_success "Script completed successfully"
    fi
}

# Function to run pre-installation checks
run_pre_installation_checks() {
  local component="$1"
  local skip_checks="${2:-false}"
  
  if [ "$skip_checks" = "true" ]; then
    log_info "Skipping pre-installation checks due to skip_checks=true"
    return 0
  fi
  
  log_info "Running pre-installation checks for $component"
  
  # Check if preflight script exists
  local preflight_script="${SCRIPT_DIR:-$(dirname "$0")/..}/../components/preflight_check.sh"
  if [ -f "$preflight_script" ]; then
    log_info "Found preflight check script, running verification"
    
    # Run with reduced checks for component installation
    bash "$preflight_script" --domain "$DOMAIN" --skip-ssh --skip-ports
    local preflight_status=$?
    
    if [ $preflight_status -ne 0 ]; then
      log_warning "Pre-installation checks detected issues that may affect $component"
      if [ "${FORCE:-false}" != "true" ]; then
        log_error "Installation aborted due to failed pre-installation checks"
        log_info "You can bypass this with --force flag or by running 'make preflight-check' to see details"
        return 1
      else
        log_warning "Continuing installation despite pre-installation check warnings (--force)"
      fi
    fi
  else
    log_info "No preflight check script found, continuing with installation"
  fi
  
  return 0
}

# --- BEGIN: Preflight/Prerequisite Checks (Unified) ---
# This section consolidates all system, network, and environment validation logic
# previously found in preflight_check.sh, install_prerequisites.sh, and install.sh
# into a single, idempotent, reusable function for all installers.

preflight_check_agencystack() {
    # Ensure required base packages are installed (idempotent, supports Alpine/Debian/Ubuntu)
    local REQUIRED_CMDS=(jq git bash make curl sudo ss)
    local MISSING_CMDS=()
    for CMD in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$CMD" > /dev/null 2>&1; then
            MISSING_CMDS+=("$CMD")
        fi
    done
    if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
        echo "[INFO] Installing missing base packages: ${MISSING_CMDS[*]}"
        if [ -f /etc/alpine-release ]; then
            apk update && apk add --no-cache jq git bash make curl sudo iproute2
        elif [ -f /etc/debian_version ] || grep -qi ubuntu /etc/os-release; then
            apt-get update && apt-get install -y jq git bash make curl sudo iproute2
        else
            echo "[ERROR] Unsupported OS. Please install: ${MISSING_CMDS[*]} manually."
            exit 1
        fi
    fi

    log_info "[Preflight] Starting AgencyStack preflight checks..."
    local errors=0
    local warnings=0

    # 1. System Requirements
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 8 ]; then
        log_error "[Preflight] Insufficient RAM: ${total_ram}GB (minimum 8GB required)"; errors=$((errors+1));
    else
        log_success "[Preflight] RAM: ${total_ram}GB - OK"
    fi
    local disk_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_space" -lt 40 ]; then
        log_error "[Preflight] Insufficient disk space: ${disk_space}GB (minimum 40GB required)"; errors=$((errors+1));
    else
        log_success "[Preflight] Disk space: ${disk_space}GB - OK"
    fi
    # Check for public static IP
    local public_ip=$(curl -s https://ipinfo.io/ip)
    if [ -z "$public_ip" ]; then
        log_warning "[Preflight] Could not detect public IP address"; warnings=$((warnings+1));
    else
        log_success "[Preflight] Public IP: $public_ip"
    fi
    # 2. Network Requirements
    if ! ping -c1 8.8.8.8 >/dev/null 2>&1; then
        log_error "[Preflight] Network unreachable (cannot ping 8.8.8.8)"; errors=$((errors+1));
    else
        log_success "[Preflight] Network connectivity OK"
    fi
    # 3. Required Commands
    local required_cmds=(docker docker-compose jq git curl wget)
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "[Preflight] Required command missing: $cmd"; errors=$((errors+1));
        else
            log_success "[Preflight] Command present: $cmd"
        fi
    done
    # 4. Root Check
    if [ "$(id -u)" -ne 0 ]; then
        log_error "[Preflight] Script must be run as root"; errors=$((errors+1));
    else
        log_success "[Preflight] Running as root"
    fi
    # 5. Directory Structure
    local required_dirs=(/opt/agency_stack /var/log/agency_stack /opt/agency_stack/clients/default)
    for d in "${required_dirs[@]}"; do
        if [ ! -d "$d" ]; then
            log_warning "[Preflight] Missing directory: $d (will attempt to create)"; mkdir -p "$d" || errors=$((errors+1));
        else
            log_success "[Preflight] Directory exists: $d"
        fi
    done
    # 6. Firewall/Ports (basic check)
    local ports=(80 443 3001)
    for p in "${ports[@]}"; do
        if ! ss -ltn | grep -q ":$p "; then
            log_warning "[Preflight] Port $p is not open/listening (may be opened by installer)"; warnings=$((warnings+1));
        else
            log_success "[Preflight] Port $p is open/listening"
        fi
    done
    # 7. SSH Check
    if ! ss -ltn | grep -q ':22 '; then
        log_warning "[Preflight] SSH port 22 is not open (remote management may fail)"; warnings=$((warnings+1));
    else
        log_success "[Preflight] SSH port 22 is open"
    fi
    # 8. DNS/Hostname
    local fqdn=$(hostname -f)
    if [ -z "$fqdn" ]; then
        log_warning "[Preflight] Could not determine FQDN"; warnings=$((warnings+1));
    else
        log_success "[Preflight] Host FQDN: $fqdn"
    fi
    # 9. Log Summary
    if [ "$errors" -gt 0 ]; then
        log_error "[Preflight] $errors critical issue(s) detected. Please resolve before proceeding."
        return 1
    elif [ "$warnings" -gt 0 ]; then
        log_warning "[Preflight] $warnings warning(s) detected. Review before proceeding."
        return 0
    else
        log_success "[Preflight] All checks passed. System is ready for AgencyStack installation."
        return 0
    fi

    # --- BEGIN: ENVIRONMENT FILE CREATION (from fix_remote_paths.sh) ---
    local ENV_FILE="/opt/agency_stack/scripts/env.sh"
    if [ ! -f "$ENV_FILE" ]; then
        mkdir -p /opt/agency_stack/scripts
        cat > "$ENV_FILE" << EOF
#!/bin/bash
# Environment for AgencyStack scripts
export SCRIPT_DIR="/opt/agency_stack/scripts"
export UTILS_DIR="/opt/agency_stack/scripts/utils"
export COMPONENTS_DIR="/opt/agency_stack/scripts/components"
export DASHBOARD_DIR="/opt/agency_stack/scripts/dashboard"
export CONFIG_DIR="/opt/agency_stack/config"
export LOGS_DIR="/opt/agency_stack/logs"
export COMPONENT_LOGS_DIR="/var/log/agency_stack/components"
EOF
        chmod +x "$ENV_FILE"
    fi
    # --- END: ENVIRONMENT FILE CREATION ---

    # --- BEGIN: FQDN/DNS CHECKS (from fix_fqdn_access.sh) ---
    # Basic DNS check for DOMAIN
    if ! getent hosts "$DOMAIN" >/dev/null; then
        echo "[WARNING] DNS lookup for $DOMAIN failed. Attempting fallback."
        # Fallback: add to /etc/hosts if not present
        if ! grep -q "$DOMAIN" /etc/hosts; then
            echo "127.0.0.1 $DOMAIN" >> /etc/hosts
            echo "[INFO] Added $DOMAIN to /etc/hosts for local resolution."
        fi
    fi
    # --- END: FQDN/DNS CHECKS ---

    # --- BEGIN: TRAEFIK PORT/FIREWALL CHECKS (from fix_traefik_ports.sh) ---
    local PORTS=(80 443)
    for PORT in "${PORTS[@]}"; do
        if ! ss -tuln | grep -q ":$PORT "; then
            echo "[WARNING] Port $PORT not open. Attempting to open via firewall-cmd (if available)."
            if command -v firewall-cmd >/dev/null 2>&1; then
                firewall-cmd --permanent --add-port=${PORT}/tcp || true
                firewall-cmd --reload || true
            elif command -v ufw >/dev/null 2>&1; then
                ufw allow $PORT/tcp || true
            fi
        fi
    done
    # --- END: TRAEFIK PORT/FIREWALL CHECKS ---

    return 0
}
# --- END: Preflight/Prerequisite Checks (Unified) ---

# Set trap for cleanup
trap cleanup EXIT

# Display script start banner
log_info "==========================================="
log_info "Starting $(basename "$0")"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="
