#!/bin/bash
# install_crowdsec.sh - AgencyStack CrowdSec Component Installer
# Installs and configures CrowdSec collaborative security engine
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
CROWDSEC_CONFIG_DIR="${CONFIG_DIR}/crowdsec"

# Log file
LOG_FILE="${LOG_DIR}/crowdsec.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"
DASHBOARD=true
COLLECTIONS="linux nginx"
DISABLE_ONLINE=false
METRIC_PORT=6060
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
    echo "  --force                    Force reinstallation even if CrowdSec is already installed"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --no-dashboard             Disable CrowdSec dashboard installation"
    echo "  --collections <list>       Space-separated list of collections to install (default: linux nginx)"
    echo "  --disable-online           Disable online features (CAPI connection)"
    echo "  --metric-port <port>       Port for metrics endpoint (default: 6060)"
    echo "  --custom-config <file>     Path to custom configuration file"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CROWDSEC_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CROWDSEC_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_crowdsec_installed() {
    if command -v cscli &>/dev/null && [ "$FORCE" = false ]; then
        log "CrowdSec is already installed. Use --force to reinstall."
        echo -e "${GREEN}CrowdSec is already installed.${NC}"
        echo "To force reinstallation, use the --force flag."
        echo "Current CrowdSec version: $(cscli version | grep 'version:' | awk '{print $2}')"
        return 0
    else
        return 1
    fi
}

install_crowdsec() {
    log "Installing CrowdSec..."
    echo -e "${CYAN}Installing CrowdSec...${NC}"
    
    # Check if we need to use the offline installer
    if [ "$DISABLE_ONLINE" = true ]; then
        log "Using offline installation method"
        
        # Download the installer to a temporary file
        curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh > /tmp/crowdsec_install.sh
        
        # Modify the script to work offline
        sed -i 's/apt-get update -qq/echo "Skipping apt-get update"/g' /tmp/crowdsec_install.sh
        
        # Run the modified installer
        chmod +x /tmp/crowdsec_install.sh
        bash /tmp/crowdsec_install.sh
        
        # Install CrowdSec packages
        apt-get install -y crowdsec
    else
        # Standard online installation
        curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
        apt-get install -y crowdsec
    fi
    
    # Install dashboard if requested
    if [ "$DASHBOARD" = true ]; then
        log "Installing CrowdSec dashboard..."
        echo -e "${CYAN}Installing CrowdSec dashboard...${NC}"
        
        apt-get install -y crowdsec-dashboard
    fi
    
    log "CrowdSec installed successfully"
}

configure_crowdsec() {
    log "Configuring CrowdSec..."
    echo -e "${CYAN}Configuring CrowdSec...${NC}"
    
    # Create main configuration directory
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config" 2>/dev/null || true
    
    # If there's a system-wide config, copy it
    if [ -f "/etc/crowdsec/config.yaml" ]; then
        cp "/etc/crowdsec/config.yaml" "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/"
    fi
    
    # Modify configuration for metrics
    if [ -f "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml" ]; then
        # Configure metrics endpoint
        if grep -q "metrics:" "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml"; then
            # Update existing metrics configuration
            sed -i "s/metrics_listen:.*/metrics_listen: 0.0.0.0:${METRIC_PORT}/" "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml"
        else
            # Add metrics configuration
            cat >> "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml" << EOF

metrics:
  enabled: true
  level: full
  metrics_listen: 0.0.0.0:${METRIC_PORT}
EOF
        fi
        
        # Disable online API if requested
        if [ "$DISABLE_ONLINE" = true ]; then
            sed -i 's/enable_online_api:.*/enable_online_api: false/' "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml"
        fi
        
        # Update configuration
        if [ -f "/etc/crowdsec/config.yaml" ]; then
            # Make a backup
            cp "/etc/crowdsec/config.yaml" "/etc/crowdsec/config.yaml.bak.$(date +%Y%m%d%H%M%S)"
            
            # Copy our configuration
            cp "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/config.yaml" "/etc/crowdsec/config.yaml"
        fi
    else
        log "WARNING: Could not find CrowdSec configuration file" "${YELLOW}WARNING: Could not find CrowdSec configuration file${NC}"
    fi
    
    # Install collections
    for collection in ${COLLECTIONS}; do
        log "Installing ${collection} collection..."
        echo -e "${CYAN}Installing ${collection} collection...${NC}"
        
        cscli collections install "${collection}" || log "WARNING: Failed to install ${collection} collection" "${YELLOW}WARNING: Failed to install ${collection} collection${NC}"
    done
    
    # Copy custom configuration if provided
    if [ -n "$CUSTOM_CONFIG" ] && [ -f "$CUSTOM_CONFIG" ]; then
        cp "$CUSTOM_CONFIG" "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/custom_config.yaml"
        log "Custom configuration applied from $CUSTOM_CONFIG"
        
        # Link custom configuration
        cp "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/config/custom_config.yaml" "/etc/crowdsec/custom_config.yaml"
    fi
    
    # Configure dashboard if installed
    if [ "$DASHBOARD" = true ] && command -v crowdsec-dashboard &>/dev/null; then
        log "Configuring CrowdSec dashboard..."
        echo -e "${CYAN}Configuring CrowdSec dashboard...${NC}"
        
        # Create dashboard configuration directory
        mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/dashboard" 2>/dev/null || true
        
        # Generate API key for dashboard
        DASHBOARD_API_KEY=$(cscli bouncers add crowdsec-dashboard)
        
        # Extract the key from the output
        API_KEY=$(echo "$DASHBOARD_API_KEY" | grep "API key" | cut -d':' -f2 | tr -d ' ')
        
        # Configure dashboard with API key
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/dashboard/dashboard.yaml" << EOF
# Dashboard configuration
listen_uri: 127.0.0.1:8080
crowdsec:
  lapi_url: http://localhost:8080/
  lapi_key: ${API_KEY}
  timeout: 10s
EOF
        
        # Link dashboard configuration
        if [ -d "/etc/crowdsec-dashboard" ]; then
            cp "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec/dashboard/dashboard.yaml" "/etc/crowdsec-dashboard/config.yaml"
        fi
    fi
    
    log "CrowdSec configured successfully"
}

start_crowdsec() {
    log "Starting CrowdSec service..."
    echo -e "${CYAN}Starting CrowdSec service...${NC}"
    
    # Ensure the service is enabled and started
    systemctl enable crowdsec
    systemctl restart crowdsec
    
    # Start dashboard if installed
    if [ "$DASHBOARD" = true ] && command -v crowdsec-dashboard &>/dev/null; then
        systemctl enable crowdsec-dashboard
        systemctl restart crowdsec-dashboard
    fi
    
    # Check if service is running
    if systemctl is-active --quiet crowdsec; then
        log "CrowdSec service started successfully"
        echo -e "${GREEN}CrowdSec service started successfully${NC}"
    else
        log "ERROR: Failed to start CrowdSec service" "${RED}ERROR: Failed to start CrowdSec service${NC}"
        echo "Please check logs: journalctl -u crowdsec"
        echo "You can also try manual restart: systemctl restart crowdsec"
    fi
}

register_component() {
    log "Registering CrowdSec component..."
    echo -e "${CYAN}Registering CrowdSec component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry" 2>/dev/null || true
    
    # Get version
    CROWDSEC_VERSION=$(cscli version | grep 'version:' | awk '{print $2}')
    
    cat > "${CONFIG_DIR}/registry/crowdsec.json" << EOF
{
  "name": "CrowdSec",
  "component_id": "crowdsec",
  "version": "${CROWDSEC_VERSION}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${CONFIG_DIR}/clients/${CLIENT_ID}/crowdsec",
  "log_file": "${LOG_FILE}",
  "client_id": "${CLIENT_ID}",
  "domain": "${DOMAIN}",
  "metrics_port": "${METRIC_PORT}",
  "dashboard_enabled": ${DASHBOARD},
  "flags": {
    "installed": true,
    "makefile": true,
    "docs": true,
    "hardened": true,
    "monitoring": true,
    "multi_tenant": true,
    "sso": false
  }
}
EOF
    
    log "CrowdSec component registered"
    echo -e "${GREEN}CrowdSec component registered${NC}"
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
        --no-dashboard)
            DASHBOARD=false
            shift
            ;;
        --collections)
            COLLECTIONS="$2"
            shift 2
            ;;
        --disable-online)
            DISABLE_ONLINE=true
            shift
            ;;
        --metric-port)
            METRIC_PORT="$2"
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

echo -e "${MAGENTA}${BOLD}🛡️ Installing CrowdSec for AgencyStack...${NC}"
log "Starting CrowdSec installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if CrowdSec is already installed
if check_crowdsec_installed; then
    # CrowdSec is already installed and --force is not set
    # Still update the configuration
    configure_crowdsec
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install CrowdSec
install_crowdsec
configure_crowdsec
start_crowdsec
register_component

log "CrowdSec installation completed successfully"
echo -e "${GREEN}${BOLD}✅ CrowdSec installation completed successfully${NC}"
echo -e "You can check CrowdSec status with: ${CYAN}make crowdsec-status${NC}"
echo -e "View CrowdSec metrics: ${CYAN}http://localhost:${METRIC_PORT}/metrics${NC}"
if [ "$DASHBOARD" = true ]; then
    echo -e "Access CrowdSec dashboard: ${CYAN}http://localhost:8080${NC}"
fi
