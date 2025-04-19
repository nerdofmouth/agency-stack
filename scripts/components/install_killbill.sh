#!/bin/bash
# install_killbill.sh - Installation script for Kill Bill
#
# This script installs and configures Kill Bill subscription and billing platform
# for AgencyStack following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-12

set -eo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
KILLBILL_VERSION="0.24.0"
KAUI_VERSION="2.0.11"
KILLBILL_PORT="8080"
KAUI_PORT="9090"
MARIADB_VERSION="10.6"
MARIADB_ROOT_PASSWORD="$(openssl rand -base64 16)"
KILLBILL_DB_PASSWORD="$(openssl rand -base64 16)"
KAUI_DB_PASSWORD="$(openssl rand -base64 16)"
KILLBILL_ADMIN_PASSWORD="$(openssl rand -base64 12)"
WITH_DEPS=false
FORCE=false
SMTP_HOST=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASSWORD=""
ENABLE_METRICS=true
TRAEFIK_NETWORK="traefik_network"
CONTAINER_MEMORY_LIMIT="1024m"
CONTAINER_CPU_LIMIT="1.0"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/killbill"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/killbill.log"
SECRETS_DIR="/opt/agency_stack/secrets/killbill/${CLIENT_ID}"

# Help function
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN         Domain name for Kill Bill (required)"
    echo "  --admin-email EMAIL     Admin email address (default: admin@example.com)"
    echo "  --client-id ID          Client ID for multi-tenant setup (default: default)"
    echo "  --with-deps             Install dependencies automatically"
    echo "  --force                 Force reinstallation"
    echo "  --smtp-host HOST        SMTP server hostname for email notifications"
    echo "  --smtp-port PORT        SMTP server port (default: 587)"
    echo "  --smtp-user USER        SMTP username"
    echo "  --smtp-password PASS    SMTP password"
    echo "  --mailu-domain DOMAIN   Mailu server domain for SMTP integration"
    echo "  --disable-metrics       Disable Prometheus metrics"
    echo "  --help                  Show this help message"
    exit 0
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --with-deps)
            WITH_DEPS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --smtp-host)
            SMTP_HOST="$2"
            shift 2
            ;;
        --smtp-port)
            SMTP_PORT="$2"
            shift 2
            ;;
        --smtp-user)
            SMTP_USER="$2"
            shift 2
            ;;
        --smtp-password)
            SMTP_PASSWORD="$2"
            shift 2
            ;;
        --mailu-domain)
            MAILU_DOMAIN="$2"
            SMTP_HOST="mail.${MAILU_DOMAIN}"
            SMTP_USER="killbill@${MAILU_DOMAIN}"
            shift 2
            ;;
        --disable-metrics)
            ENABLE_METRICS=false
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Update installation paths with client ID
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/killbill"
SECRETS_DIR="/opt/agency_stack/secrets/killbill/${CLIENT_ID}"

log_info "Starting Kill Bill installation for domain: ${DOMAIN}"

# Check if domain is provided
if [[ -z "${DOMAIN}" || "${DOMAIN}" == "localhost" ]]; then
    log_error "Domain name is required. Please specify with --domain"
    exit 1
fi

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${SECRETS_DIR}"
mkdir -p "${INSTALL_DIR}/config"
mkdir -p "${INSTALL_DIR}/data/mariadb"

# Check if killbill is already installed
if [[ -f "${INSTALL_DIR}/.installed" ]] && [[ "${FORCE}" != "true" ]]; then
    log_info "Kill Bill is already installed at ${INSTALL_DIR}"
    log_info "Use --force to reinstall"
    exit 0
fi

# Install dependencies if required
if [[ "${WITH_DEPS}" == "true" ]]; then
    log_info "Installing dependencies..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        usermod -aG docker "${USER}"
        rm -f get-docker.sh
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.17.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create docker-compose.yml
log_cmd "Creating docker-compose configuration..."
cat > "${INSTALL_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  mariadb:
    image: mariadb:${MARIADB_VERSION}
    container_name: killbill_mariadb_${CLIENT_ID}
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
      - MYSQL_DATABASE=killbill
      - MYSQL_USER=killbill
      - MYSQL_PASSWORD=${KILLBILL_DB_PASSWORD}
    volumes:
      - ${INSTALL_DIR}/data/mariadb:/var/lib/mysql
      - ${INSTALL_DIR}/config/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - killbill_network
    deploy:
      resources:
        limits:
          memory: ${CONTAINER_MEMORY_LIMIT}
          cpus: ${CONTAINER_CPU_LIMIT}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "killbill", "-p\${MYSQL_PASSWORD}"]
      interval: 30s
      timeout: 10s
      retries: 5

  killbill:
    image: killbill/killbill:${KILLBILL_VERSION}
    container_name: killbill_app_${CLIENT_ID}
    depends_on:
      - mariadb
    environment:
      - KILLBILL_DAO_URL=jdbc:mysql://mariadb:3306/killbill
      - KILLBILL_DAO_USER=killbill
      - KILLBILL_DAO_PASSWORD=${KILLBILL_DB_PASSWORD}
      - KILLBILL_SERVER_TEST_MODE=true
      - KILLBILL_SECURITY_SHIRO_NB_HASH_ITERATIONS=100000
      - KILLBILL_SERVER_BASE_URL=https://${DOMAIN}
      - KILLBILL_SMTP_HOST=${SMTP_HOST}
      - KILLBILL_SMTP_PORT=${SMTP_PORT}
      - KILLBILL_SMTP_USER=${SMTP_USER}
      - KILLBILL_SMTP_PASSWORD=${SMTP_PASSWORD}
      - KILLBILL_SMTP_FROM_ADDRESS=billing@${DOMAIN}
      - KILLBILL_METRICS_GRAPHITE=false
      - KILLBILL_METRICS_INFLUXDB=false
      - KILLBILL_METRICS_PROMETHEUS=${ENABLE_METRICS}
    expose:
      - "${KILLBILL_PORT}"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.killbill-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/api\`)"
      - "traefik.http.routers.killbill-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.killbill-${CLIENT_ID}.tls=true"
      - "traefik.http.services.killbill-${CLIENT_ID}.loadbalancer.server.port=${KILLBILL_PORT}"
    volumes:
      - ${INSTALL_DIR}/config/killbill.properties:/var/lib/killbill/config/killbill.properties
    networks:
      - killbill_network
      - ${TRAEFIK_NETWORK}
    restart: always
    deploy:
      resources:
        limits:
          memory: ${CONTAINER_MEMORY_LIMIT}
          cpus: ${CONTAINER_CPU_LIMIT}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${KILLBILL_PORT}/api/1.0/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 5

  kaui:
    image: killbill/kaui:${KAUI_VERSION}
    container_name: killbill_kaui_${CLIENT_ID}
    depends_on:
      - killbill
      - mariadb
    environment:
      - KAUI_CONFIG_DAO_URL=jdbc:mysql://mariadb:3306/kaui
      - KAUI_CONFIG_DAO_USER=kaui
      - KAUI_CONFIG_DAO_PASSWORD=${KAUI_DB_PASSWORD}
      - KAUI_KILLBILL_URL=http://killbill:${KILLBILL_PORT}
      - KAUI_ALLOW_ROOT_USER_ACCESS=true
    expose:
      - "${KAUI_PORT}"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.kaui-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.kaui-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.kaui-${CLIENT_ID}.tls=true"
      - "traefik.http.services.kaui-${CLIENT_ID}.loadbalancer.server.port=${KAUI_PORT}"
    volumes:
      - ${INSTALL_DIR}/config/kaui.yml:/var/lib/kaui/config/kaui.yml
    networks:
      - killbill_network
      - ${TRAEFIK_NETWORK}
    restart: always
    deploy:
      resources:
        limits:
          memory: ${CONTAINER_MEMORY_LIMIT}
          cpus: ${CONTAINER_CPU_LIMIT}

networks:
  killbill_network:
    driver: bridge
  ${TRAEFIK_NETWORK}:
    external: true
EOF

# Create database initialization script
log_cmd "Creating database initialization script..."
cat > "${INSTALL_DIR}/config/init.sql" << EOF
CREATE DATABASE IF NOT EXISTS kaui;
GRANT ALL PRIVILEGES ON kaui.* TO 'killbill'@'%';

-- Kill Bill specific permissions
GRANT ALL PRIVILEGES ON killbill.* TO 'killbill'@'%';
FLUSH PRIVILEGES;

-- Create kaui user
CREATE USER IF NOT EXISTS 'kaui'@'%' IDENTIFIED BY '${KAUI_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON kaui.* TO 'kaui'@'%';
FLUSH PRIVILEGES;
EOF

# Create Kill Bill properties file
log_cmd "Creating Kill Bill configuration..."
cat > "${INSTALL_DIR}/config/killbill.properties" << EOF
# Kill Bill Properties
org.killbill.server.multitenant=true
org.killbill.security.shiroResourcePath=classpath:shiro.ini
org.killbill.tenant.broadcast.rate=5000

# Email notifications
org.killbill.mail.smtp.host=${SMTP_HOST}
org.killbill.mail.smtp.port=${SMTP_PORT}
org.killbill.mail.smtp.auth=true
org.killbill.mail.smtp.user=${SMTP_USER}
org.killbill.mail.smtp.password=${SMTP_PASSWORD}
org.killbill.mail.from.address=billing@${DOMAIN}
org.killbill.mail.from.name=Kill Bill Billing System

# Metrics
org.killbill.metrics.graphite=false
org.killbill.metrics.influxdb=false
org.killbill.metrics.prometheus.enabled=${ENABLE_METRICS}
org.killbill.metrics.prometheus.hotspot.enabled=${ENABLE_METRICS}
org.killbill.metrics.prometheus.port=9092

# Security
org.killbill.security.shiroNbHashIterations=100000
EOF

# Create Kaui configuration
log_cmd "Creating Kaui configuration..."
cat > "${INSTALL_DIR}/config/kaui.yml" << EOF
production:
  kaui:
    url: http://killbill:${KILLBILL_PORT}
    db_adapter: mysql2
    db_encoding: utf8
    db_user: kaui
    db_password: ${KAUI_DB_PASSWORD}
    db_host: mariadb
    db_port: 3306
    db_name: kaui
    allow_root_user_access: true
    demo_mode: false
EOF

# Store secrets
log_cmd "Storing credentials securely..."
mkdir -p "${SECRETS_DIR}"
cat > "${SECRETS_DIR}/${DOMAIN}.env" << EOF
# Kill Bill credentials for ${DOMAIN} (Client ID: ${CLIENT_ID})
# Generated on $(date)
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
KILLBILL_DB_PASSWORD=${KILLBILL_DB_PASSWORD}
KAUI_DB_PASSWORD=${KAUI_DB_PASSWORD}
KILLBILL_ADMIN_PASSWORD=${KILLBILL_ADMIN_PASSWORD}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASSWORD=${SMTP_PASSWORD}
EOF

# Secure the secrets file
chmod 600 "${SECRETS_DIR}/${DOMAIN}.env"

# Start the services
log_cmd "Starting Kill Bill services..."
cd "${INSTALL_DIR}"
docker-compose up -d

# Wait for services to be up
log_info "Waiting for Kill Bill services to start..."
attempt=0
max_attempts=30
until $(curl --output /dev/null --silent --fail http://localhost:${KILLBILL_PORT}/api/1.0/healthcheck) || [ $attempt -eq $max_attempts ]; do
    attempt=$((attempt+1))
    log_info "Waiting for Kill Bill to start (attempt $attempt/$max_attempts)..."
    sleep 10
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Kill Bill failed to start within the expected time"
    exit 1
fi

# Create admin user
log_cmd "Creating admin user..."
curl -v \
    -X POST \
    -u admin:password \
    -H "X-Killbill-CreatedBy: install_script" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "admin",
        "password": "'${KILLBILL_ADMIN_PASSWORD}'",
        "roles": ["admin"]
    }' \
    http://localhost:${KILLBILL_PORT}/api/1.0/security/users

# Register component with AgencyStack
log_cmd "Registering Kill Bill component..."
if [[ -f "${SCRIPT_DIR}/../utils/register_component.sh" ]]; then
    bash "${SCRIPT_DIR}/../utils/register_component.sh" "killbill" "${DOMAIN}" "${CLIENT_ID}"
fi

# Mark as installed
echo "Installation completed on $(date)" > "${INSTALL_DIR}/.installed"
echo "DOMAIN=${DOMAIN}" >> "${INSTALL_DIR}/.installed" 
echo "CLIENT_ID=${CLIENT_ID}" >> "${INSTALL_DIR}/.installed"

# Success message
log_success "Kill Bill installation completed successfully!"
log_info "Kill Bill UI is available at: https://${DOMAIN}/api"
log_info "Kaui Admin UI is available at: https://${DOMAIN}"
log_info "Admin username: admin"
log_info "Admin password: ${KILLBILL_ADMIN_PASSWORD}"
log_info "Credentials stored in: ${SECRETS_DIR}/${DOMAIN}.env"

exit 0
