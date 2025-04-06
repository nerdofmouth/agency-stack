#!/bin/bash
# install_multi_tenancy.sh - AgencyStack Multi-Tenancy Component Installer
# Configures client isolation and multi-tenancy support for AgencyStack
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
MULTI_TENANCY_CONFIG_DIR="${CONFIG_DIR}/multi_tenancy"
UTILS_DIR="${ROOT_DIR}/scripts/utils"

# Source common utilities if available
if [ -f "${UTILS_DIR}/common.sh" ]; then
    source "${UTILS_DIR}/common.sh"
fi

# Log file
LOG_FILE="${LOG_DIR}/multi_tenancy.log"

# Default values
FORCE=false
DEFAULT_CLIENT_ID="default"
CLIENTS=""
ISOLATION_LEVEL="hard"
ROOT_DOMAIN="localhost"
KEY_ROTATION_DAYS=90
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
    echo "  --force                     Force reinstallation even if already configured"
    echo "  --default-client-id <id>    Default client ID (default: default)"
    echo "  --clients <client1,client2> Comma-separated list of additional client IDs to create"
    echo "  --isolation-level <level>   Isolation level: soft, medium, hard (default: hard)"
    echo "  --root-domain <domain>      Root domain for client subdomains (default: localhost)"
    echo "  --key-rotation-days <days>  Days between key rotations (default: 90)"
    echo "  --custom-config <file>      Path to custom configuration file"
    echo "  --help                      Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${MULTI_TENANCY_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${DEFAULT_CLIENT_ID}" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${MULTI_TENANCY_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${DEFAULT_CLIENT_ID}" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_already_configured() {
    if [ -f "${MULTI_TENANCY_CONFIG_DIR}/config.yaml" ] && [ "$FORCE" = false ]; then
        log "Multi-Tenancy is already configured. Use --force to reconfigure."
        echo -e "${GREEN}Multi-Tenancy is already configured.${NC}"
        echo "To force reconfiguration, use the --force flag."
        return 0
    else
        return 1
    fi
}

create_client() {
    local client_id="$1"
    log "Creating client: ${client_id}..."
    echo -e "${CYAN}Creating client: ${client_id}...${NC}"
    
    # Create client directory structure
    mkdir -p "${CONFIG_DIR}/clients/${client_id}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${client_id}/config" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${client_id}/data" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${client_id}/secrets" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${client_id}/logs" 2>/dev/null || true
    
    # Generate client-specific .env file
    cat > "${CONFIG_DIR}/clients/${client_id}/config/.env" << EOF
# AgencyStack Client Configuration
# Client: ${client_id}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

CLIENT_ID=${client_id}
CLIENT_DOMAIN=${client_id}.${ROOT_DOMAIN}
ROOT_DOMAIN=${ROOT_DOMAIN}
ISOLATION_LEVEL=${ISOLATION_LEVEL}
DATA_DIR=${CONFIG_DIR}/clients/${client_id}/data
CONFIG_DIR=${CONFIG_DIR}/clients/${client_id}/config
SECRETS_DIR=${CONFIG_DIR}/clients/${client_id}/secrets
EOF
    
    # Generate client-specific API key if it doesn't exist
    if [ ! -f "${CONFIG_DIR}/clients/${client_id}/secrets/api_key.txt" ]; then
        # Generate a random API key
        API_KEY=$(openssl rand -hex 32)
        echo "${API_KEY}" > "${CONFIG_DIR}/clients/${client_id}/secrets/api_key.txt"
        chmod 600 "${CONFIG_DIR}/clients/${client_id}/secrets/api_key.txt"
    fi
    
    # Create clients.json entry
    local client_json="{\"client_id\":\"${client_id}\",\"domain\":\"${client_id}.${ROOT_DOMAIN}\",\"isolation_level\":\"${ISOLATION_LEVEL}\",\"created_at\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"key_rotation\":\"${KEY_ROTATION_DAYS}\"}"
    
    # Add client to clients.json
    if [ -f "${MULTI_TENANCY_CONFIG_DIR}/clients.json" ]; then
        # Check if the client already exists
        if grep -q "\"client_id\":\"${client_id}\"" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"; then
            # Update existing client
            # This is a simplistic approach; in a real scenario, you might want to use jq
            sed -i "s/\(.*\"client_id\":\"${client_id}\".*\)/${client_json}/" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"
        else
            # Add new client
            sed -i "s/\]/${client_json},\]/" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"
        fi
    else
        # Create new clients.json
        echo "[${client_json}]" > "${MULTI_TENANCY_CONFIG_DIR}/clients.json"
    fi
    
    log "Client ${client_id} created successfully"
}

configure_multi_tenancy() {
    log "Configuring Multi-Tenancy..."
    echo -e "${CYAN}Configuring Multi-Tenancy...${NC}"
    
    # Create main configuration directory
    mkdir -p "${MULTI_TENANCY_CONFIG_DIR}" 2>/dev/null || true
    
    # Create configuration file
    cat > "${MULTI_TENANCY_CONFIG_DIR}/config.yaml" << EOF
# AgencyStack Multi-Tenancy Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

default_client: ${DEFAULT_CLIENT_ID}
root_domain: ${ROOT_DOMAIN}
isolation_level: ${ISOLATION_LEVEL}
key_rotation_days: ${KEY_ROTATION_DAYS}
clients_file: ${MULTI_TENANCY_CONFIG_DIR}/clients.json

# Storage Configuration
paths:
  clients_root: ${CONFIG_DIR}/clients
  registry: ${CONFIG_DIR}/registry
  logs: ${LOG_DIR}

# Security Configuration
security:
  enforce_isolation: true
  isolation_strategies:
    soft:
      - "shared_databases_with_schemas"
      - "namespace_separation"
    medium:
      - "dedicated_databases"
      - "namespace_separation"
      - "network_segmentation"
    hard:
      - "dedicated_databases"
      - "namespace_separation"
      - "network_segmentation"
      - "resource_quotas"
      - "key_isolation"
EOF
    
    # Copy custom configuration if provided
    if [ -n "$CUSTOM_CONFIG" ] && [ -f "$CUSTOM_CONFIG" ]; then
        cp "$CUSTOM_CONFIG" "${MULTI_TENANCY_CONFIG_DIR}/custom_config.yaml"
        log "Custom configuration applied from $CUSTOM_CONFIG"
    fi
    
    # Create default client if not already exists
    create_client "${DEFAULT_CLIENT_ID}"
    
    # Create additional clients if specified
    if [ -n "$CLIENTS" ]; then
        IFS=',' read -ra CLIENT_ARRAY <<< "$CLIENTS"
        for client in "${CLIENT_ARRAY[@]}"; do
            create_client "$client"
        done
    fi
    
    log "Multi-Tenancy configured successfully"
}

setup_network_isolation() {
    log "Setting up network isolation for multi-tenancy..."
    echo -e "${CYAN}Setting up network isolation for multi-tenancy...${NC}"
    
    # Create Docker network for multi-tenancy if it doesn't exist
    if ! docker network ls | grep -q "agency_stack_default"; then
        docker network create agency_stack_default
        log "Created agency_stack_default Docker network"
    fi
    
    # For each client, create a client-specific network if using hard isolation
    if [ "$ISOLATION_LEVEL" = "hard" ] || [ "$ISOLATION_LEVEL" = "medium" ]; then
        # Create network for default client
        if ! docker network ls | grep -q "agency_stack_${DEFAULT_CLIENT_ID}"; then
            docker network create "agency_stack_${DEFAULT_CLIENT_ID}"
            log "Created agency_stack_${DEFAULT_CLIENT_ID} Docker network"
        fi
        
        # Create networks for additional clients
        if [ -n "$CLIENTS" ]; then
            IFS=',' read -ra CLIENT_ARRAY <<< "$CLIENTS"
            for client in "${CLIENT_ARRAY[@]}"; do
                if ! docker network ls | grep -q "agency_stack_${client}"; then
                    docker network create "agency_stack_${client}"
                    log "Created agency_stack_${client} Docker network"
                fi
            done
        fi
    fi
    
    log "Network isolation setup completed"
}

create_management_scripts() {
    log "Creating multi-tenancy management scripts..."
    echo -e "${CYAN}Creating multi-tenancy management scripts...${NC}"
    
    # Create client management script
    cat > "${MULTI_TENANCY_CONFIG_DIR}/manage_client.sh" << 'EOF'
#!/bin/bash
# manage_client.sh - AgencyStack Client Management Script

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/opt/agency_stack"
MULTI_TENANCY_CONFIG_DIR="${CONFIG_DIR}/multi_tenancy"

# Default values
ACTION=""
CLIENT_ID=""
ROOT_DOMAIN=""
ISOLATION_LEVEL="hard"

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] ACTION"
    echo ""
    echo "Actions:"
    echo "  create <client_id>     Create a new client"
    echo "  delete <client_id>     Delete a client"
    echo "  list                   List all clients"
    echo "  status <client_id>     Show client status"
    echo ""
    echo "Options:"
    echo "  --root-domain <domain> Root domain for client subdomain"
    echo "  --isolation <level>    Isolation level: soft, medium, hard (default: hard)"
    echo "  --help                 Show this help message"
    exit 1
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --root-domain)
        ROOT_DOMAIN="$2"
        shift 2
        ;;
        --isolation)
        ISOLATION_LEVEL="$2"
        shift 2
        ;;
        --help)
        show_usage
        ;;
        create|delete|list|status)
        ACTION="$1"
        shift
        if [ "$ACTION" != "list" ]; then
            CLIENT_ID="$1"
            shift
        fi
        ;;
        *)
        echo "Unknown option: $1"
        show_usage
        ;;
    esac
done

# Check if action is provided
if [ -z "$ACTION" ]; then
    echo "ERROR: No action specified"
    show_usage
fi

# If root domain is not provided, try to get it from config
if [ -z "$ROOT_DOMAIN" ] && [ -f "${MULTI_TENANCY_CONFIG_DIR}/config.yaml" ]; then
    ROOT_DOMAIN=$(grep "root_domain:" "${MULTI_TENANCY_CONFIG_DIR}/config.yaml" | cut -d':' -f2 | tr -d ' ')
fi

# Validate required parameters
if [ "$ACTION" != "list" ] && [ -z "$CLIENT_ID" ]; then
    echo "ERROR: Client ID is required for action: $ACTION"
    show_usage
fi

# Perform the requested action
case $ACTION in
    create)
        echo "Creating client: $CLIENT_ID"
        "${MULTI_TENANCY_CONFIG_DIR}/../scripts/components/install_multi_tenancy.sh" \
            --default-client-id "$CLIENT_ID" \
            $([ -n "$ROOT_DOMAIN" ] && echo "--root-domain $ROOT_DOMAIN") \
            --isolation-level "$ISOLATION_LEVEL" \
            --force
        ;;
    delete)
        echo "Deleting client: $CLIENT_ID"
        # Check if client exists in clients.json
        if [ -f "${MULTI_TENANCY_CONFIG_DIR}/clients.json" ] && grep -q "\"client_id\":\"${CLIENT_ID}\"" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"; then
            # Remove client from clients.json
            # This is a simplistic approach; in a real scenario, you might want to use jq
            sed -i "/\"client_id\":\"${CLIENT_ID}\"/d" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"
            
            # Stop all containers for this client
            echo "Stopping containers for client: $CLIENT_ID"
            docker ps --filter "label=agency_stack.client_id=$CLIENT_ID" -q | xargs -r docker stop
            
            # Remove client directory (prompt for confirmation)
            read -p "Do you want to remove all data for client $CLIENT_ID? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                rm -rf "${CONFIG_DIR}/clients/${CLIENT_ID}"
                echo "Client data removed"
            else
                echo "Client data preserved"
            fi
            
            # Remove client network if it exists
            if docker network ls | grep -q "agency_stack_${CLIENT_ID}"; then
                docker network rm "agency_stack_${CLIENT_ID}" || echo "Could not remove network (might be in use)"
            fi
            
            echo "Client $CLIENT_ID deleted successfully"
        else
            echo "ERROR: Client $CLIENT_ID not found"
            exit 1
        fi
        ;;
    list)
        echo "Listing all clients:"
        if [ -f "${MULTI_TENANCY_CONFIG_DIR}/clients.json" ]; then
            grep -o "\"client_id\":\"[^\"]*\"" "${MULTI_TENANCY_CONFIG_DIR}/clients.json" | cut -d':' -f2 | tr -d '"' | while read -r client; do
                echo "- $client"
            done
        else
            echo "No clients found"
        fi
        ;;
    status)
        echo "Status for client: $CLIENT_ID"
        if [ -f "${MULTI_TENANCY_CONFIG_DIR}/clients.json" ] && grep -q "\"client_id\":\"${CLIENT_ID}\"" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"; then
            echo "Client configuration:"
            grep -A 5 "\"client_id\":\"${CLIENT_ID}\"" "${MULTI_TENANCY_CONFIG_DIR}/clients.json"
            
            echo ""
            echo "Client directories:"
            ls -la "${CONFIG_DIR}/clients/${CLIENT_ID}" 2>/dev/null || echo "No directories found"
            
            echo ""
            echo "Running containers:"
            docker ps --filter "label=agency_stack.client_id=$CLIENT_ID" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "ERROR: Client $CLIENT_ID not found"
            exit 1
        fi
        ;;
    *)
        echo "ERROR: Unknown action: $ACTION"
        show_usage
        ;;
esac
EOF
    
    # Make script executable
    chmod +x "${MULTI_TENANCY_CONFIG_DIR}/manage_client.sh"
    
    # Create symbolic link in /usr/local/bin for easier access
    ln -sf "${MULTI_TENANCY_CONFIG_DIR}/manage_client.sh" "/usr/local/bin/agencystack-client"
    
    log "Management scripts created successfully"
}

register_component() {
    log "Registering Multi-Tenancy component..."
    echo -e "${CYAN}Registering Multi-Tenancy component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry" 2>/dev/null || true
    
    cat > "${CONFIG_DIR}/registry/multi_tenancy.json" << EOF
{
  "name": "Multi-Tenancy",
  "component_id": "multi_tenancy",
  "version": "1.0.0",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${MULTI_TENANCY_CONFIG_DIR}",
  "log_file": "${LOG_FILE}",
  "default_client_id": "${DEFAULT_CLIENT_ID}",
  "isolation_level": "${ISOLATION_LEVEL}",
  "root_domain": "${ROOT_DOMAIN}",
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
    
    log "Multi-Tenancy component registered"
    echo -e "${GREEN}Multi-Tenancy component registered${NC}"
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
        --default-client-id)
            DEFAULT_CLIENT_ID="$2"
            shift 2
            ;;
        --clients)
            CLIENTS="$2"
            shift 2
            ;;
        --isolation-level)
            ISOLATION_LEVEL="$2"
            shift 2
            ;;
        --root-domain)
            ROOT_DOMAIN="$2"
            shift 2
            ;;
        --key-rotation-days)
            KEY_ROTATION_DAYS="$2"
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

echo -e "${MAGENTA}${BOLD}🏢 Installing Multi-Tenancy for AgencyStack...${NC}"
log "Starting Multi-Tenancy installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if Multi-Tenancy is already configured
if check_already_configured; then
    # Multi-Tenancy is already configured and --force is not set
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install and configure Multi-Tenancy
configure_multi_tenancy

# Setup network isolation if docker is available
if command -v docker &>/dev/null; then
    setup_network_isolation
else
    log "WARNING: Docker not found, skipping network isolation setup" "${YELLOW}WARNING: Docker not found, skipping network isolation setup${NC}"
fi

# Create management scripts
create_management_scripts

# Register the component
register_component

log "Multi-Tenancy installation completed successfully"
echo -e "${GREEN}${BOLD}✅ Multi-Tenancy installation completed successfully${NC}"
echo -e "You can check Multi-Tenancy status with: ${CYAN}make multi_tenancy-status${NC}"
echo -e "Manage clients with: ${CYAN}agencystack-client [create|delete|list|status] <client_id>${NC}"
