#!/bin/bash
# install_fail2ban.sh - AgencyStack Fail2Ban Component Installer
# Installs and configures Fail2Ban for intrusion detection and prevention
# v0.1.0-alpha

# Exit on error
set -e

# Colors for output
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
NC="\033[0m" # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack/components"
FAIL2BAN_CONFIG_DIR="${CONFIG_DIR}/fail2ban"

# Log file
LOG_FILE="${LOG_DIR}/fail2ban.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"
SSH_PROTECTION=true
WEB_PROTECTION=true
BAN_TIME="1h"
FIND_TIME="10m"
MAX_RETRY=5
CUSTOM_CONFIG=""

# -----------------------------------------------------------------------------
# Function Definitions
# -----------------------------------------------------------------------------

log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" | tee -a "${LOG_FILE}"
    if [ -n "$2" ]; then
        echo -e "$2"
    fi
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force                    Force reinstallation even if Fail2Ban is already installed"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --no-ssh-protection        Disable SSH protection"
    echo "  --no-web-protection        Disable web server protection"
    echo "  --ban-time <time>          Ban time duration (default: 1h)"
    echo "  --find-time <time>         Time window for max retry (default: 10m)"
    echo "  --max-retry <count>        Maximum retry count (default: 5)"
    echo "  --custom-config <file>     Path to custom configuration file"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${FAIL2BAN_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${FAIL2BAN_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_fail2ban_installed() {
    if command -v fail2ban-client &>/dev/null && [ "$FORCE" = false ]; then
        log "Fail2Ban is already installed. Use --force to reinstall."
        echo -e "${GREEN}Fail2Ban is already installed.${NC}"
        echo "To force reinstallation, use the --force flag."
        echo "Current Fail2Ban version: $(fail2ban-client --version | head -n 1)"
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    log "Installing dependencies..."
    echo -e "${CYAN}Installing dependencies...${NC}"
    
    apt-get update
    apt-get install -y fail2ban
    
    log "Dependencies installed successfully"
}

configure_fail2ban() {
    log "Configuring Fail2Ban..."
    echo -e "${CYAN}Configuring Fail2Ban...${NC}"
    
    # Create base configuration directory
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d" 2>/dev/null || true
    
    # Create main configuration file
    cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.local" << EOF
[DEFAULT]
# Ban hosts for one hour
bantime  = ${BAN_TIME}
# Find time window
findtime  = ${FIND_TIME}
# Max attempts
maxretry = ${MAX_RETRY}

# Mail notification
#destemail = root@localhost
#sender = root@localhost
#mta = sendmail
#action = %(action_mw)s

# Custom action for notifications
action = %(action_)s

# Use iptables to ban
banaction = iptables-multiport

# Ignore localhost
ignoreip = 127.0.0.1/8 ::1
EOF
    
    # Add SSH protection if enabled
    if [ "$SSH_PROTECTION" = true ]; then
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/sshd.conf" << EOF
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
        log "SSH protection enabled"
    else
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/sshd.conf" << EOF
[sshd]
enabled = false
EOF
        log "SSH protection disabled"
    fi
    
    # Add web server protection if enabled
    if [ "$WEB_PROTECTION" = true ]; then
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/http-auth.conf" << EOF
[apache-auth]
enabled = true
port     = http,https
logpath  = %(apache_error_log)s

[nginx-http-auth]
enabled = true
port     = http,https
logpath  = %(nginx_error_log)s
EOF
        log "Web server protection enabled"
    else
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/http-auth.conf" << EOF
[apache-auth]
enabled = false

[nginx-http-auth]
enabled = false
EOF
        log "Web server protection disabled"
    fi
    
    # Copy custom configuration if provided
    if [ -n "$CUSTOM_CONFIG" ] && [ -f "$CUSTOM_CONFIG" ]; then
        cp "$CUSTOM_CONFIG" "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/custom.conf"
        log "Custom configuration applied from $CUSTOM_CONFIG"
    fi
    
    # Link configuration to system directory
    if [ -d "/etc/fail2ban" ]; then
        # Back up existing configuration
        if [ -f "/etc/fail2ban/jail.local" ]; then
            cp "/etc/fail2ban/jail.local" "/etc/fail2ban/jail.local.bak.$(date +%Y%m%d%H%M%S)"
        fi
        
        # Copy new configuration
        cp "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.local" "/etc/fail2ban/jail.local"
        
        # Create jail.d directory if it doesn't exist
        mkdir -p "/etc/fail2ban/jail.d" 2>/dev/null || true
        
        # Copy jail.d configuration files
        cp -r "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban/jail.d/"* "/etc/fail2ban/jail.d/"
        
        log "Configuration linked to system directory"
    else
        log "ERROR: System Fail2Ban directory not found" "${RED}ERROR: System Fail2Ban directory not found${NC}"
        log "Installation is incomplete. Please check your system."
        exit 1
    fi
    
    log "Fail2Ban configured successfully"
}

start_fail2ban() {
    log "Starting Fail2Ban service..."
    echo -e "${CYAN}Starting Fail2Ban service...${NC}"
    
    # Ensure the service is enabled and started
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    # Check if service is running
    if systemctl is-active --quiet fail2ban; then
        log "Fail2Ban service started successfully"
        echo -e "${GREEN}Fail2Ban service started successfully${NC}"
    else
        log "ERROR: Failed to start Fail2Ban service" "${RED}ERROR: Failed to start Fail2Ban service${NC}"
        echo "Please check logs: journalctl -u fail2ban"
        echo "You can also try manual restart: systemctl restart fail2ban"
    fi
}

register_component() {
    log "Registering Fail2Ban component..."
    echo -e "${CYAN}Registering Fail2Ban component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry" 2>/dev/null || true
    
    # Get version
    FAIL2BAN_VERSION=$(fail2ban-client --version | head -n 1 | awk '{print $2}')
    
    cat > "${CONFIG_DIR}/registry/fail2ban.json" << EOF
{
  "name": "Fail2Ban",
  "component_id": "fail2ban",
  "version": "${FAIL2BAN_VERSION}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${CONFIG_DIR}/clients/${CLIENT_ID}/fail2ban",
  "log_file": "${LOG_FILE}",
  "client_id": "${CLIENT_ID}",
  "domain": "${DOMAIN}",
  "flags": {
    "installed": true,
    "makefile": true,
    "docs": true,
    "hardened": true,
    "monitoring": false,
    "multi_tenant": true,
    "sso": false
  }
}
EOF
    
    log "Fail2Ban component registered"
    echo -e "${GREEN}Fail2Ban component registered${NC}"
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

# Process command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --no-ssh-protection)
            SSH_PROTECTION=false
            shift
            ;;
        --no-web-protection)
            WEB_PROTECTION=false
            shift
            ;;
        --ban-time)
            BAN_TIME="$2"
            shift 2
            ;;
        --find-time)
            FIND_TIME="$2"
            shift 2
            ;;
        --max-retry)
            MAX_RETRY="$2"
            shift 2
            ;;
        --custom-config)
            CUSTOM_CONFIG="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo -e "${MAGENTA}${BOLD}🛡️ Installing Fail2Ban for AgencyStack...${NC}"
log "Starting Fail2Ban installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if Fail2Ban is already installed
if check_fail2ban_installed; then
    # Fail2Ban is already installed and --force is not set
    # Still update the configuration
    configure_fail2ban
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install Fail2Ban
install_dependencies
configure_fail2ban
start_fail2ban
register_component

log "Fail2Ban installation completed successfully"
echo -e "${GREEN}${BOLD}✅ Fail2Ban installation completed successfully${NC}"
echo -e "You can check Fail2Ban status with: ${CYAN}make fail2ban-status${NC}"
echo -e "View active jails with: ${CYAN}fail2ban-client status${NC}"
