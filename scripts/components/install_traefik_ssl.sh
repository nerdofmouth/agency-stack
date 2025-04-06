#!/bin/bash
# install_traefik_ssl.sh - AgencyStack Traefik SSL Component Installer
# Installs and configures SSL/TLS for Traefik with Let's Encrypt integration
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
TRAEFIK_SSL_DIR="${CONFIG_DIR}/traefik_ssl"
TRAEFIK_CONFIG_DIR="${CONFIG_DIR}/traefik"

# Log file
LOG_FILE="${LOG_DIR}/traefik_ssl.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"
EMAIL="admin@example.com"
STAGING=false
WILDCARD=false
DNS_CHALLENGE=false
DNS_PROVIDER=""

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
    echo "  --force                    Force reinstallation even if already configured"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --email <email>            Email for Let's Encrypt (default: admin@example.com)"
    echo "  --staging                  Use Let's Encrypt staging environment"
    echo "  --wildcard                 Setup wildcard certificates (requires DNS challenge)"
    echo "  --dns-challenge            Use DNS challenge for validation"
    echo "  --dns-provider <provider>  DNS provider for DNS challenge validation"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${TRAEFIK_SSL_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${TRAEFIK_SSL_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_traefik_installed() {
    # Check if traefik config directory exists
    if [ ! -d "${TRAEFIK_CONFIG_DIR}" ]; then
        log "ERROR: Traefik is not installed. Please install Traefik first." "${RED}ERROR: Traefik is not installed. Please install Traefik first.${NC}"
        echo "Run: make traefik"
        exit 1
    fi
}

check_ssl_configured() {
    # Check if traefik SSL is already configured
    if [ -f "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/acme.json" ] && [ "$FORCE" = false ]; then
        log "Traefik SSL is already configured. Use --force to reconfigure."
        echo -e "${GREEN}Traefik SSL is already configured.${NC}"
        echo "To force reconfiguration, use the --force flag."
        return 0
    else
        return 1
    fi
}

validate_domain() {
    if [ "$DOMAIN" = "localhost" ]; then
        log "WARNING: Using 'localhost' as domain. SSL will use self-signed certificates." "${YELLOW}WARNING: Using 'localhost' as domain. SSL will use self-signed certificates.${NC}"
    fi
    
    # Basic domain validation
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log "ERROR: Invalid domain format: $DOMAIN" "${RED}ERROR: Invalid domain format: $DOMAIN${NC}"
        exit 1
    fi
}

create_selfsigned_cert() {
    log "Creating self-signed certificate for development..."
    echo -e "${CYAN}Creating self-signed certificate for development...${NC}"
    
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs" 2>/dev/null || true
    
    # Generate private key
    openssl genrsa -out "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.key" 2048
    
    # Generate CSR
    openssl req -new -key "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.key" \
        -out "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.csr" \
        -subj "/CN=${DOMAIN}/O=AgencyStack/C=US"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.csr" \
        -signkey "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.key" \
        -out "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/certs/server.crt"
    
    # Create empty acme.json file for consistency
    touch "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/acme.json"
    chmod 600 "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/acme.json"
    
    log "Self-signed certificate created successfully"
    echo -e "${GREEN}Self-signed certificate created successfully${NC}"
}

configure_letsencrypt() {
    log "Configuring Let's Encrypt for automatic SSL..."
    echo -e "${CYAN}Configuring Let's Encrypt for automatic SSL...${NC}"
    
    # Create acme.json file for Let's Encrypt
    touch "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/acme.json"
    chmod 600 "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl/acme.json"
    
    # Create Let's Encrypt configuration
    ACME_SERVER="https://acme-v02.api.letsencrypt.org/directory"
    if [ "$STAGING" = true ]; then
        ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
        log "Using Let's Encrypt staging environment"
        echo -e "${YELLOW}Using Let's Encrypt staging environment${NC}"
    fi
    
    # Create dynamic configuration for Traefik
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config" 2>/dev/null || true
    
    cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config/tls.toml" << EOF
[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    sniStrict = true
    cipherSuites = [
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
      "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
    ]

[tls.stores]
  [tls.stores.default]

[certificatesResolvers.letsencrypt.acme]
  email = "${EMAIL}"
  storage = "/etc/traefik/ssl/acme.json"
  caServer = "${ACME_SERVER}"
EOF
    
    # Add HTTP challenge if not using DNS challenge
    if [ "$DNS_CHALLENGE" = false ]; then
        cat >> "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config/tls.toml" << EOF
  [certificatesResolvers.letsencrypt.acme.httpChallenge]
    entryPoint = "web"
EOF
    else
        # Add DNS challenge configuration
        cat >> "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config/tls.toml" << EOF
  [certificatesResolvers.letsencrypt.acme.dnsChallenge]
    provider = "${DNS_PROVIDER}"
    resolvers = ["1.1.1.1:53", "8.8.8.8:53"]
EOF
    fi
    
    log "Let's Encrypt configured successfully"
    echo -e "${GREEN}Let's Encrypt configured successfully${NC}"
}

update_traefik_config() {
    log "Updating Traefik configuration to use SSL..."
    echo -e "${CYAN}Updating Traefik configuration to use SSL...${NC}"
    
    # Check if main traefik configuration exists
    if [ ! -f "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config/traefik.toml" ]; then
        log "WARNING: Traefik main configuration not found. Creating a default one." "${YELLOW}WARNING: Traefik main configuration not found. Creating a default one.${NC}"
        
        # Create basic traefik.toml
        mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config" 2>/dev/null || true
        cat > "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config/traefik.toml" << EOF
[global]
  checkNewVersion = false
  sendAnonymousUsage = false

[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.http.tls]
      certResolver = "letsencrypt"

[api]
  dashboard = true
  insecure = false

[providers.file]
  directory = "/etc/traefik/config"
  watch = true

[log]
  level = "INFO"

[accessLog]
  filePath = "/var/log/traefik/access.log"
  bufferingSize = 100

[pilots]
  [pilots.token]
    # Turnoff Traefik Pilot
    value = ""
EOF
    fi
    
    # Update docker-compose if it exists
    if [ -f "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/docker-compose.yml" ]; then
        log "Updating docker-compose.yml for Traefik SSL..."
        
        # Check if docker-compose has volumes for SSL
        if ! grep -q "ssl/acme.json" "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/docker-compose.yml"; then
            # Make a backup
            cp "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/docker-compose.yml" "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/docker-compose.yml.bak"
            
            # Add SSL volumes if they don't exist
            sed -i '/volumes:/a \      - ${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl:/etc/traefik/ssl:rw\n      - ${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/config:/etc/traefik/config:ro' "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/docker-compose.yml"
        fi
    fi
    
    log "Traefik configuration updated for SSL"
    echo -e "${GREEN}Traefik configuration updated for SSL${NC}"
}

register_component() {
    log "Registering Traefik SSL component..."
    echo -e "${CYAN}Registering Traefik SSL component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry" 2>/dev/null || true
    cat > "${CONFIG_DIR}/registry/traefik_ssl.json" << EOF
{
  "name": "Traefik SSL",
  "component_id": "traefik_ssl",
  "version": "1.0.0",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${CONFIG_DIR}/clients/${CLIENT_ID}/traefik/ssl",
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
    
    log "Traefik SSL component registered"
    echo -e "${GREEN}Traefik SSL component registered${NC}"
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
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --staging)
            STAGING=true
            shift
            ;;
        --wildcard)
            WILDCARD=true
            shift
            ;;
        --dns-challenge)
            DNS_CHALLENGE=true
            shift
            ;;
        --dns-provider)
            DNS_PROVIDER="$2"
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

# If wildcard is requested, ensure DNS challenge is enabled
if [ "$WILDCARD" = true ] && [ "$DNS_CHALLENGE" = false ]; then
    log "ERROR: Wildcard certificates require DNS challenge" "${RED}ERROR: Wildcard certificates require DNS challenge${NC}"
    echo "Please use --dns-challenge and --dns-provider options"
    exit 1
fi

# If DNS challenge is enabled, ensure provider is specified
if [ "$DNS_CHALLENGE" = true ] && [ -z "$DNS_PROVIDER" ]; then
    log "ERROR: DNS challenge requires a DNS provider" "${RED}ERROR: DNS challenge requires a DNS provider${NC}"
    echo "Please use --dns-provider option"
    exit 1
fi

echo -e "${MAGENTA}${BOLD}🔒 Installing Traefik SSL for AgencyStack...${NC}"
log "Starting Traefik SSL installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if Traefik is installed
check_traefik_installed

# Check if SSL is already configured
if check_ssl_configured; then
    # Already configured and --force is not set
    register_component
    exit 0
fi

# Validate domain
validate_domain

# Install SSL based on domain
if [ "$DOMAIN" = "localhost" ] || [ "$DOMAIN" = "127.0.0.1" ]; then
    create_selfsigned_cert
else
    configure_letsencrypt
fi

# Update Traefik configuration to use SSL
update_traefik_config

# Register the component
register_component

log "Traefik SSL installation completed successfully"
echo -e "${GREEN}${BOLD}✅ Traefik SSL installation completed successfully${NC}"
echo -e "You can check Traefik SSL status with: ${CYAN}make traefik_ssl-status${NC}"
echo -e "To apply changes, restart Traefik with: ${CYAN}make traefik-restart${NC}"
