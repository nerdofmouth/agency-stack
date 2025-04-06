#!/bin/bash
# install_taskwarrior_calcure.sh - AgencyStack TaskWarrior & Calcurse Component Installer
# Installs and configures TaskWarrior and Calcurse for task management and calendar
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
TASKWARRIOR_CONFIG_DIR="${CONFIG_DIR}/taskwarrior_calcure"

# Log file
LOG_FILE="${LOG_DIR}/taskwarrior_calcure.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"
ENABLE_WEB_UI=true
WEB_PORT=8080
SYNC_ENABLED=false
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
    echo "  --force                    Force reinstallation even if already installed"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --no-web-ui                Disable Taskwarrior web UI"
    echo "  --web-port <port>          Web UI port (default: 8080)"
    echo "  --sync-enabled             Enable Taskwarrior synchronization"
    echo "  --custom-config <file>     Path to custom configuration file"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${TASKWARRIOR_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/data" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${TASKWARRIOR_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_already_installed() {
    if (command -v task &>/dev/null && command -v calcurse &>/dev/null) && [ "$FORCE" = false ]; then
        log "TaskWarrior and Calcurse are already installed. Use --force to reinstall."
        echo -e "${GREEN}TaskWarrior and Calcurse are already installed.${NC}"
        echo "To force reinstallation, use the --force flag."
        echo "TaskWarrior version: $(task --version)"
        echo "Calcurse version: $(calcurse --version | head -n 1)"
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    log "Installing dependencies..."
    echo -e "${CYAN}Installing dependencies...${NC}"
    
    apt-get update
    apt-get install -y taskwarrior calcurse
    
    # Additional dependencies for web UI if enabled
    if [ "$ENABLE_WEB_UI" = true ]; then
        apt-get install -y npm nodejs
        npm install -g taskwarrior-web
    fi
    
    log "Dependencies installed successfully"
}

configure_taskwarrior() {
    log "Configuring TaskWarrior..."
    echo -e "${CYAN}Configuring TaskWarrior...${NC}"
    
    # Create TaskWarrior configuration directory
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior" 2>/dev/null || true
    
    # Create basic TaskWarrior configuration
    cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc" << EOF
# TaskWarrior configuration for AgencyStack
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Data location
data.location=${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/data

# Basic UI configuration
verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait

# Color theme
include /usr/share/taskwarrior/dark-16.theme

# Defaults
default.command=next
default.project=inbox

# Reports
report.next.columns=id,start.age,entry.age,depends,priority,project,tags,recur,scheduled.countdown,due.relative,until.remaining,description,urgency
report.next.labels=ID,Active,Age,Deps,P,Project,Tags,Recur,S,Due,Until,Description,Urg
report.next.filter=status:pending limit:page
report.next.sort=urgency-

# Urgency coefficients
urgency.user.tag.next.coefficient=15.0
urgency.due.coefficient=12.0
urgency.blocking.coefficient=8.0
urgency.priority.coefficient=6.0
EOF
    
    # Configure sync if enabled
    if [ "$SYNC_ENABLED" = true ]; then
        cat >> "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc" << EOF

# Sync configuration
taskd.server=localhost:53589
taskd.credentials=public/user/${CLIENT_ID}
taskd.certificate=${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/user.cert.pem
taskd.key=${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/user.key.pem
taskd.ca=${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/ca.cert.pem
EOF
    fi
    
    # Copy configuration files to system locations
    if [ ! -d "/etc/taskwarrior" ]; then
        mkdir -p "/etc/taskwarrior" 2>/dev/null || true
    fi
    
    # Create a symbolic link for the configuration
    ln -sf "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc" "/etc/taskwarrior/taskrc.${CLIENT_ID}"
    
    # Create a system-wide accessible taskrc
    if [ ! -f "/etc/taskwarrior/taskrc" ]; then
        ln -sf "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc" "/etc/taskwarrior/taskrc"
    fi
    
    log "TaskWarrior configured successfully"
}

configure_calcurse() {
    log "Configuring Calcurse..."
    echo -e "${CYAN}Configuring Calcurse...${NC}"
    
    # Create Calcurse configuration directory
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/calcurse" 2>/dev/null || true
    
    # Create basic Calcurse configuration
    cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/calcurse/conf" << EOF
# Calcurse configuration for AgencyStack
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

appearance.calendarview=monthly
appearance.compactpanels=no
appearance.defaultpanel=calendar
appearance.layout=5
appearance.notifybar=yes
appearance.sidebarwidth=0
appearance.theme=green on default
appearance.todoview=show-completed
daemon.enable=no
daemon.log=no
format.inputdate=1
format.notifydate=%a %F
format.notifytime=%T
format.outputdate=%D
general.autogc=no
general.autosave=yes
general.confirmdelete=yes
general.confirmquit=yes
general.firstdayofweek=sunday
general.periodicsave=0
general.progressbar=yes
general.systemdialogs=yes
notification.command=printf '\a'
notification.notifyall=flagged-only
notification.warning=300
EOF
    
    # Create apts directory for appointments
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/calcurse/apts" 2>/dev/null || true
    
    # Create symbolic links for easy access
    if [ ! -d "/etc/calcurse" ]; then
        mkdir -p "/etc/calcurse" 2>/dev/null || true
    fi
    
    ln -sf "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/calcurse" "/etc/calcurse/${CLIENT_ID}"
    
    log "Calcurse configured successfully"
}

setup_web_ui() {
    if [ "$ENABLE_WEB_UI" = true ]; then
        log "Setting up TaskWarrior Web UI..."
        echo -e "${CYAN}Setting up TaskWarrior Web UI...${NC}"
        
        # Create web UI configuration directory
        mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/web" 2>/dev/null || true
        
        # Create configuration for TaskWarrior Web
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/web/config.json" << EOF
{
  "taskwarrior": {
    "taskrc": "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc"
  },
  "server": {
    "port": ${WEB_PORT},
    "host": "0.0.0.0"
  },
  "dashboard": {
    "enabled": true,
    "credentials": {
      "username": "admin",
      "password": "$(openssl rand -hex 8)"
    }
  }
}
EOF
        
        # Create a systemd service for the web UI
        cat > "/etc/systemd/system/taskwarrior-web-${CLIENT_ID}.service" << EOF
[Unit]
Description=TaskWarrior Web UI for ${CLIENT_ID}
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/taskwarrior-web --config ${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/web/config.json
Restart=on-failure
Environment=HOME=/root
Environment=TASKRC=${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior/taskrc

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd and enable the service
        systemctl daemon-reload
        systemctl enable "taskwarrior-web-${CLIENT_ID}.service"
        systemctl start "taskwarrior-web-${CLIENT_ID}.service"
        
        log "TaskWarrior Web UI configured successfully on port ${WEB_PORT}"
    else
        log "TaskWarrior Web UI is disabled. Skipping setup."
    fi
}

create_docker_compose() {
    log "Creating Docker Compose configuration..."
    echo -e "${CYAN}Creating Docker Compose configuration...${NC}"
    
    # Create Docker Compose directory
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/docker" 2>/dev/null || true
    
    # Create Docker Compose file for TaskWarrior and Calcurse services
    cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/docker/docker-compose.yml" << EOF
version: '3.8'

services:
  taskwarrior-web:
    image: andir/taskwarrior-web:latest
    container_name: taskwarrior-web-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/taskwarrior:/root/.taskwarrior
      - ${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure/data:/data
    environment:
      - TASKRC=/root/.taskwarrior/taskrc
    ports:
      - "${WEB_PORT}:${WEB_PORT}"
    networks:
      - agency_stack_${CLIENT_ID}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.taskwarrior-${CLIENT_ID}.rule=Host(\`taskwarrior.${CLIENT_ID}.${DOMAIN}\`)"
      - "traefik.http.services.taskwarrior-${CLIENT_ID}.loadbalancer.server.port=${WEB_PORT}"
      - "agency_stack.client_id=${CLIENT_ID}"
      - "agency_stack.component=taskwarrior_calcure"

networks:
  agency_stack_${CLIENT_ID}:
    external: true
EOF
    
    log "Docker Compose configuration created"
}

register_component() {
    log "Registering TaskWarrior & Calcurse component..."
    echo -e "${CYAN}Registering TaskWarrior & Calcurse component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry" 2>/dev/null || true
    
    # Get versions
    TASKWARRIOR_VERSION=$(task --version 2>/dev/null || echo "unknown")
    CALCURSE_VERSION=$(calcurse --version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "unknown")
    
    cat > "${CONFIG_DIR}/registry/taskwarrior_calcure.json" << EOF
{
  "name": "TaskWarrior & Calcurse",
  "component_id": "taskwarrior_calcure",
  "version": "${TASKWARRIOR_VERSION}/${CALCURSE_VERSION}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${CONFIG_DIR}/clients/${CLIENT_ID}/taskwarrior_calcure",
  "log_file": "${LOG_FILE}",
  "client_id": "${CLIENT_ID}",
  "domain": "${DOMAIN}",
  "web_enabled": ${ENABLE_WEB_UI},
  "web_port": ${WEB_PORT},
  "sync_enabled": ${SYNC_ENABLED},
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
    
    log "TaskWarrior & Calcurse component registered"
    echo -e "${GREEN}TaskWarrior & Calcurse component registered${NC}"
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
        --no-web-ui)
            ENABLE_WEB_UI=false
            shift
            ;;
        --web-port)
            WEB_PORT="$2"
            shift 2
            ;;
        --sync-enabled)
            SYNC_ENABLED=true
            shift
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

echo -e "${MAGENTA}${BOLD}📅 Installing TaskWarrior & Calcurse for AgencyStack...${NC}"
log "Starting TaskWarrior & Calcurse installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if already installed
if check_already_installed; then
    # TaskWarrior and Calcurse are already installed and --force is not set
    # Still update the configuration
    configure_taskwarrior
    configure_calcurse
    if [ "$ENABLE_WEB_UI" = true ]; then
        setup_web_ui
    fi
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install and configure
install_dependencies
configure_taskwarrior
configure_calcurse
if [ "$ENABLE_WEB_UI" = true ]; then
    setup_web_ui
fi

# Create Docker Compose configuration for containerized deployment
create_docker_compose

# Register the component
register_component

log "TaskWarrior & Calcurse installation completed successfully"
echo -e "${GREEN}${BOLD}✅ TaskWarrior & Calcurse installation completed successfully${NC}"
echo -e "You can check status with: ${CYAN}make taskwarrior_calcure-status${NC}"
if [ "$ENABLE_WEB_UI" = true ]; then
    echo -e "Access TaskWarrior Web UI: ${CYAN}http://localhost:${WEB_PORT}${NC}"
    echo -e "Or with domain: ${CYAN}http://taskwarrior.${CLIENT_ID}.${DOMAIN}${NC}"
fi
