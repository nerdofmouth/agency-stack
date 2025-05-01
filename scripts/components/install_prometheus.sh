#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: prometheus.sh
# Path: /scripts/components/install_prometheus.sh
#
        
# install_prometheus.sh - Install and configure Prometheus monitoring for AgencyStack
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# This script sets up Prometheus with:
# - Core Prometheus server (port 9090)
# - Node Exporter for system metrics (port 9100)
# - AlertManager for alerting (port 9093)
# - Optional Pushgateway for batch job metrics (port 9091)
# - Integration with Grafana datasource
# - Secure Traefik integration with TLS and labels
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
PROMETHEUS_DIR="${CONFIG_DIR}/prometheus"
PROMETHEUS_DATA_DIR="${PROMETHEUS_DIR}/data"
PROMETHEUS_CONFIG_DIR="${PROMETHEUS_DIR}/config"
NODE_EXPORTER_DIR="${CONFIG_DIR}/node_exporter"
ALERTMANAGER_DIR="${CONFIG_DIR}/alertmanager"
ALERTMANAGER_DATA_DIR="${ALERTMANAGER_DIR}/data"
ALERTMANAGER_CONFIG_DIR="${ALERTMANAGER_DIR}/config"
PUSHGATEWAY_DIR="${CONFIG_DIR}/pushgateway"
COMPOSE_DIR="${CONFIG_DIR}/docker-compose"

LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/prometheus.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/prometheus.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"

VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
STACK_DOMAIN=""
TRAEFIK_NETWORK="agency_stack_traefik"
PROMETHEUS_VERSION="v2.46.0"
NODE_EXPORTER_VERSION="v1.6.1"
ALERTMANAGER_VERSION="v0.26.0"
PUSHGATEWAY_VERSION="v1.6.2"
INCLUDE_PUSHGATEWAY=false
GRAFANA_DOMAIN=""
RETENTION_DAYS=15
RETENTION_SIZE="30GB"
TRAEFIK_DASHBOARD_RULE="Host(\`{{ DOMAIN }}\`) && (PathPrefix(\`/api/v1/query\`) || PathPrefix(\`/graph\`) || Path(\`/\`))"
INSTALL_GRAFANA=false
ADMIN_EMAIL=""
PROMETHEUS_USERNAME="prometheus"
PROMETHEUS_PASSWORD=$(openssl rand -hex 16)
GENERATED_PASSWORD=true
SECURE_MODE=true
CONFIG_ONLY=false
RESTART_SERVICES=false
TRAEFIK_DISABLE=false
TRAEFIK_INSTALLED=false
COMPOSE_PROJECT_NAME="prometheus"
METRICS_ENDPOINT="metrics"
CUSTOM_SCRAPE_CONFIGS=""
EMAIL_ALERTS=false
WEBHOOK_ALERTS=false
WEBHOOK_URL=""
TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Prometheus Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures Prometheus monitoring stack."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>           Domain for Prometheus (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>     Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--stack-domain${NC} <domain>     Main stack domain for auto-discovery (optional)"
  echo -e "  ${BOLD}--grafana-domain${NC} <domain>   Grafana domain for integration (optional)"
  echo -e "  ${BOLD}--install-grafana${NC}           Install and configure Grafana automatically"
  echo -e "  ${BOLD}--admin-email${NC} <email>       Admin email for alerts (optional)"
  echo -e "  ${BOLD}--retention-days${NC} <days>     Metrics retention in days (default: 15)"
  echo -e "  ${BOLD}--retention-size${NC} <size>     Metrics retention size (default: 30GB)"
  echo -e "  ${BOLD}--prometheus-version${NC} <ver>  Prometheus version (default: ${PROMETHEUS_VERSION})"
  echo -e "  ${BOLD}--with-pushgateway${NC}          Include Pushgateway for batch jobs"
  echo -e "  ${BOLD}--username${NC} <username>       Custom username for auth (default: prometheus)"
  echo -e "  ${BOLD}--password${NC} <password>       Custom password for auth (auto-generated if not provided)"
  echo -e "  ${BOLD}--no-secure${NC}                 Disable security features (not recommended)"
  echo -e "  ${BOLD}--config-only${NC}               Generate configuration only, do not start services"
  echo -e "  ${BOLD}--restart${NC}                   Restart services if already running"
  echo -e "  ${BOLD}--no-traefik${NC}                Skip Traefik integration"
  echo -e "  ${BOLD}--email-alerts${NC}              Enable email-based alerting"
  echo -e "  ${BOLD}--webhook-alerts${NC}            Enable webhook-based alerting"
  echo -e "  ${BOLD}--webhook-url${NC} <url>         Webhook URL for alerts (required if --webhook-alerts)"
  echo -e "  ${BOLD}--custom-scrape${NC} <file>      Path to custom scrape config to include"
  echo -e "  ${BOLD}--force${NC}                     Force reinstallation even if already installed"
  echo -e "  ${BOLD}--with-deps${NC}                 Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                   Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                      Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain metrics.example.com --grafana-domain grafana.example.com --retention-days 30"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --stack-domain)
      STACK_DOMAIN="$2"
      shift
      shift
      ;;
    --grafana-domain)
      GRAFANA_DOMAIN="$2"
      shift
      shift
      ;;
    --install-grafana)
      INSTALL_GRAFANA=true
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      shift
      ;;
    --retention-days)
      RETENTION_DAYS="$2"
      shift
      shift
      ;;
    --retention-size)
      RETENTION_SIZE="$2"
      shift
      shift
      ;;
    --prometheus-version)
      PROMETHEUS_VERSION="$2"
      shift
      shift
      ;;
    --with-pushgateway)
      INCLUDE_PUSHGATEWAY=true
      shift
      ;;
    --username)
      PROMETHEUS_USERNAME="$2"
      shift
      shift
      ;;
    --password)
      PROMETHEUS_PASSWORD="$2"
      GENERATED_PASSWORD=false
      shift
      shift
      ;;
    --no-secure)
      SECURE_MODE=false
      shift
      ;;
    --config-only)
      CONFIG_ONLY=true
      shift
      ;;
    --restart)
      RESTART_SERVICES=true
      shift
      ;;
    --no-traefik)
      TRAEFIK_DISABLE=true
      shift
      ;;
    --email-alerts)
      EMAIL_ALERTS=true
      shift
      ;;
    --webhook-alerts)
      WEBHOOK_ALERTS=true
      shift
      ;;
    --webhook-url)
      WEBHOOK_URL="$2"
      shift
      shift
      ;;
    --custom-scrape)
      CUSTOM_SCRAPE_CONFIGS="$2"
      shift
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Create log directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$COMPONENTS_LOG_DIR"
mkdir -p "$INTEGRATIONS_LOG_DIR"
touch "$INSTALL_LOG"
touch "$INTEGRATION_LOG"
touch "$MAIN_INTEGRATION_LOG"

# Validate domain parameter
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: Domain is required. Use --domain option.${NC}"
  show_help
  exit 1

# Log function
log() {
  local level="$1"
  local message="$2"
  local color_message="$3"
  
  echo "$(date +"%Y-%m-%d %H:%M:%S") - [$level] $message" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ] || [ "$level" = "ERROR" ]; then
    echo -e "$color_message"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Prometheus - $message" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Prometheus - $message" >> "$MAIN_INTEGRATION_LOG"
  
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$message"
  fi
}

# Success log
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log "INFO" "$1" "${GREEN}$1${NC}"
}

# Info log
  log "INFO" "$1" "${BLUE}$1${NC}"
}

# Warning log
  log "WARNING" "$1" "${YELLOW}$1${NC}"
}

# Error log
  log "ERROR" "$1" "${RED}$1${NC}"
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
  log_info "Checking dependencies..."
  
  local missing_deps=()
  
  # Required dependencies
  for cmd in docker docker-compose curl jq openssl; do
    if ! command_exists "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done
  
  # If there are missing dependencies
  if [ ${#missing_deps[@]} -gt 0 ]; then
    log_warning "Missing dependencies: ${missing_deps[*]}"
    
    if [ "$WITH_DEPS" = true ]; then
      log_info "Installing missing dependencies..."
      
      # Update package lists
      if command_exists apt-get; then
        apt-get update
        
        # Install missing dependencies
        for dep in "${missing_deps[@]}"; do
          case "$dep" in
            docker)
              log_info "Installing Docker..."
              curl -fsSL https://get.docker.com | sh
              systemctl enable docker
              systemctl start docker
              ;;
            docker-compose)
              log_info "Installing Docker Compose..."
              curl -L "https://github.com/docker/compose/releases/download/v2.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              ;;
            *)
              log_info "Installing $dep..."
              apt-get install -y "$dep"
              ;;
          esac
        done
      else
        log_error "Automatic dependency installation is only supported on Debian/Ubuntu systems."
        log_error "Please install the following dependencies manually: ${missing_deps[*]}"
        exit 1
      fi
    else
      log_error "Missing dependencies: ${missing_deps[*]}"
      log_error "Please install them or run with --with-deps to install automatically."
      exit 1
    fi
  fi
  
  # Validate Docker is running
  if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
  fi
  
  # Check if Traefik is installed
  if docker network ls | grep -q "$TRAEFIK_NETWORK"; then
    TRAEFIK_INSTALLED=true
  fi
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "All dependencies are installed."
}

# Create required directories
create_directories() {
  log_info "Creating required directories..."
  
  mkdir -p "$PROMETHEUS_DIR"
  mkdir -p "$PROMETHEUS_DATA_DIR"
  mkdir -p "$PROMETHEUS_CONFIG_DIR"
  mkdir -p "$NODE_EXPORTER_DIR"
  mkdir -p "$ALERTMANAGER_DIR"
  mkdir -p "$ALERTMANAGER_DATA_DIR"
  mkdir -p "$ALERTMANAGER_CONFIG_DIR"
  
  if [ "$INCLUDE_PUSHGATEWAY" = true ]; then
    mkdir -p "$PUSHGATEWAY_DIR"
  fi
  
  mkdir -p "$COMPOSE_DIR"
  
  # Set correct permissions
  chown -R root:root "$CONFIG_DIR"
  chmod -R 755 "$CONFIG_DIR"
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Directories created successfully."
}

# Check if services are already installed
check_existing_installation() {
  if [ -f "${COMPOSE_DIR}/docker-compose.prometheus.yml" ] && [ "$FORCE" != true ]; then
    log_warning "Prometheus installation already exists at ${COMPOSE_DIR}/docker-compose.prometheus.yml"
    log_warning "Use --force to reinstall or --restart to restart services."
    
    if [ "$RESTART_SERVICES" = true ]; then
      log_info "Restarting Prometheus services..."
      cd "${COMPOSE_DIR}" && docker-compose -f docker-compose.prometheus.yml restart
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Prometheus services restarted successfully."
      exit 0
    else
      exit 0
    fi
  fi
}

# Generate a basic auth password file
generate_basic_auth() {
  log_info "Generating basic auth credentials..."
  
  local auth_dir="${PROMETHEUS_CONFIG_DIR}/auth"
  mkdir -p "$auth_dir"
  
  # Generate htpasswd file
  if command_exists htpasswd; then
    htpasswd -bc "${auth_dir}/prometheus.htpasswd" "$PROMETHEUS_USERNAME" "$PROMETHEUS_PASSWORD"
  else
    # If htpasswd is not available, use Docker to generate it
    docker run --rm -v "${auth_dir}:/auth" httpd:alpine htpasswd -bBc /auth/prometheus.htpasswd "$PROMETHEUS_USERNAME" "$PROMETHEUS_PASSWORD"
  fi
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Basic auth credentials generated."
  
  if [ "$GENERATED_PASSWORD" = true ]; then
    log_info "Generated username: $PROMETHEUS_USERNAME"
    log_info "Generated password: $PROMETHEUS_PASSWORD"
    echo "$PROMETHEUS_PASSWORD" > "${auth_dir}/prometheus.password"
    chmod 600 "${auth_dir}/prometheus.password"
  fi
}

# Generate Prometheus configuration
generate_prometheus_config() {
  log_info "Generating Prometheus configuration..."
  
  local config_file="${PROMETHEUS_CONFIG_DIR}/prometheus.yml"
  
  # Determine client-specific prefix if CLIENT_ID is provided
  local client_prefix=""
  if [ -n "$CLIENT_ID" ]; then
    client_prefix="${CLIENT_ID}-"
  fi

  # Create main prometheus.yml file
  cat > "$config_file" << EOF
# Prometheus configuration for AgencyStack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")
# Client ID: ${CLIENT_ID:-none}

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s
  external_labels:
    monitor: '${client_prefix}prometheus'
    environment: 'production'

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - alertmanager:9093

# Rule files to load
rule_files:
  - "/etc/prometheus/rules/*.yml"

# Scrape configurations
scrape_configs:
  # Self monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter for system metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # Docker metrics
  - job_name: 'docker'
    static_configs:
      - targets: ['172.17.0.1:9323']

  # Traefik metrics (if available)
  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8082']
EOF

  # Add Pushgateway if included
  if [ "$INCLUDE_PUSHGATEWAY" = true ]; then
    cat >> "$config_file" << EOF

  # Pushgateway for batch job metrics
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
EOF
  fi

  # Auto-discovery for other AgencyStack components
  if [ -n "$STACK_DOMAIN" ]; then
    cat >> "$config_file" << EOF

  # AgencyStack service discovery
  - job_name: 'agency_stack_services'
    scrape_interval: 30s
    dns_sd_configs:
      - names:
        - 'tasks.agency_stack_network'
        type: 'A'
        port: 9100
EOF
  fi

  # Include custom scrape configurations if provided
  if [ -n "$CUSTOM_SCRAPE_CONFIGS" ] && [ -f "$CUSTOM_SCRAPE_CONFIGS" ]; then
    log_info "Including custom scrape configurations from $CUSTOM_SCRAPE_CONFIGS"
    cat "$CUSTOM_SCRAPE_CONFIGS" >> "$config_file"
  fi

  # Create rules directory
  mkdir -p "${PROMETHEUS_CONFIG_DIR}/rules"

  # Create default alerting rules
  cat > "${PROMETHEUS_CONFIG_DIR}/rules/node_alerts.yml" << EOF
groups:
- name: node_alerts
  rules:
  - alert: HighCPULoad
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High CPU load (instance {{ \$labels.instance }})
      description: "CPU load is > 80%\n  VALUE = {{ \$value }}\n  LABELS = {{ \$labels }}"

  - alert: HighMemoryLoad
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High memory load (instance {{ \$labels.instance }})
      description: "Memory load is > 80%\n  VALUE = {{ \$value }}\n  LABELS = {{ \$labels }}"

  - alert: HighDiskUsage
    expr: (node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"} - node_filesystem_free_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"}) / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"} * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High disk usage (instance {{ \$labels.instance }})
      description: "Disk usage is > 85%\n  VALUE = {{ \$value }}\n  LABELS = {{ \$labels }}"
EOF

  # Create prometheus service alert rules
  cat > "${PROMETHEUS_CONFIG_DIR}/rules/service_alerts.yml" << EOF
groups:
- name: service_alerts
  rules:
  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ \$labels.job }} is down"
      description: "Service {{ \$labels.job }} on {{ \$labels.instance }} has been down for more than 1 minute."

  - alert: InstanceDown
    expr: up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ \$labels.instance }} down"
      description: "{{ \$labels.instance }} of job {{ \$labels.job }} has been down for more than 5 minutes."
EOF

    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Prometheus configuration generated successfully."
}

# Generate AlertManager configuration
generate_alertmanager_config() {
  log_info "Generating AlertManager configuration..."
  
  local config_file="${ALERTMANAGER_CONFIG_DIR}/alertmanager.yml"
  
  # Create base alertmanager.yml
  cat > "$config_file" << EOF
# AlertManager configuration for AgencyStack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp:25'
  smtp_from: 'alertmanager@${DOMAIN}'
  smtp_require_tls: false

route:
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default-receiver'

receivers:
- name: 'default-receiver'
  webhook_configs:
  - url: 'http://localhost:9090/-/reload'
EOF

  # Add email alerting if enabled
  if [ "$EMAIL_ALERTS" = true ] && [ -n "$ADMIN_EMAIL" ]; then
    cat > "$config_file" << EOF
# AlertManager configuration for AgencyStack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp:25'
  smtp_from: 'alertmanager@${DOMAIN}'
  smtp_require_tls: false

route:
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'email-alerts'

receivers:
- name: 'email-alerts'
  email_configs:
  - to: '${ADMIN_EMAIL}'
    send_resolved: true
EOF
  fi

  # Add webhook alerting if enabled
  if [ "$WEBHOOK_ALERTS" = true ] && [ -n "$WEBHOOK_URL" ]; then
    cat > "$config_file" << EOF
# AlertManager configuration for AgencyStack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'webhook-alerts'

receivers:
- name: 'webhook-alerts'
  webhook_configs:
  - url: '${WEBHOOK_URL}'
    send_resolved: true
EOF
  fi

  # Add both email and webhook if both are enabled
  if [ "$EMAIL_ALERTS" = true ] && [ "$WEBHOOK_ALERTS" = true ] && [ -n "$ADMIN_EMAIL" ] && [ -n "$WEBHOOK_URL" ]; then
    cat > "$config_file" << EOF
# AlertManager configuration for AgencyStack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp:25'
  smtp_from: 'alertmanager@${DOMAIN}'
  smtp_require_tls: false

route:
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'all-alerts'
  routes:
  - match:
      severity: critical
    receiver: 'all-alerts'
    continue: true

receivers:
- name: 'all-alerts'
  email_configs:
  - to: '${ADMIN_EMAIL}'
    send_resolved: true
  webhook_configs:
  - url: '${WEBHOOK_URL}'
    send_resolved: true
EOF
  fi

    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "AlertManager configuration generated successfully."
}

# Generate docker-compose file
generate_docker_compose() {
  log_info "Generating Docker Compose configuration..."
  
  local compose_file="${COMPOSE_DIR}/docker-compose.prometheus.yml"
  
  # Start with basic services
  cat > "$compose_file" << EOF
# Docker Compose configuration for Prometheus stack
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")
# AgencyStack monitoring component

version: '3.8'

services:
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VERSION}
    container_name: ${COMPOSE_PROJECT_NAME}_prometheus
    volumes:
      - ${PROMETHEUS_CONFIG_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROMETHEUS_CONFIG_DIR}/rules:/etc/prometheus/rules:ro
      - ${PROMETHEUS_DATA_DIR}:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${RETENTION_DAYS}d'
      - '--storage.tsdb.retention.size=${RETENTION_SIZE}'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
EOF

  # Add basic auth if secure mode is enabled
  if [ "$SECURE_MODE" = true ]; then
    cat >> "$compose_file" << EOF
      - '--web.config.file=/etc/prometheus/web-config.yml'
    volumes:
      - ${PROMETHEUS_CONFIG_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROMETHEUS_CONFIG_DIR}/rules:/etc/prometheus/rules:ro
      - ${PROMETHEUS_CONFIG_DIR}/web-config.yml:/etc/prometheus/web-config.yml:ro
      - ${PROMETHEUS_DATA_DIR}:/prometheus
EOF
  fi

  # Add Traefik configuration if not disabled
  if [ "$TRAEFIK_DISABLE" != true ] && [ "$TRAEFIK_INSTALLED" = true ]; then
    cat >> "$compose_file" << EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure"
      - "traefik.http.routers.prometheus.tls=true"
      - "traefik.http.routers.prometheus.tls.certresolver=default"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
    networks:
      - default
      - ${TRAEFIK_NETWORK}
EOF
  else
    cat >> "$compose_file" << EOF
    ports:
      - "9090:9090"
EOF
  fi

  # Add Node Exporter
  cat >> "$compose_file" << EOF

  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VERSION}
    container_name: ${COMPOSE_PROJECT_NAME}_node_exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    expose:
      - 9100
    restart: unless-stopped
EOF

  # Add AlertManager
  cat >> "$compose_file" << EOF

  alertmanager:
    image: prom/alertmanager:${ALERTMANAGER_VERSION}
    container_name: ${COMPOSE_PROJECT_NAME}_alertmanager
    volumes:
      - ${ALERTMANAGER_CONFIG_DIR}/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - ${ALERTMANAGER_DATA_DIR}:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
EOF

  # Add Traefik labels for AlertManager
  if [ "$TRAEFIK_DISABLE" != true ] && [ "$TRAEFIK_INSTALLED" = true ]; then
    cat >> "$compose_file" << EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.alertmanager.rule=Host(\`alerts.${DOMAIN}\`)"
      - "traefik.http.routers.alertmanager.entrypoints=websecure"
      - "traefik.http.routers.alertmanager.tls=true"
      - "traefik.http.routers.alertmanager.tls.certresolver=default"
      - "traefik.http.services.alertmanager.loadbalancer.server.port=9093"
EOF
  else
    cat >> "$compose_file" << EOF
    ports:
      - "9093:9093"
EOF
  fi

  # Add Pushgateway if included
  if [ "$INCLUDE_PUSHGATEWAY" = true ]; then
    cat >> "$compose_file" << EOF

  pushgateway:
    image: prom/pushgateway:${PUSHGATEWAY_VERSION}
    container_name: ${COMPOSE_PROJECT_NAME}_pushgateway
    restart: unless-stopped
EOF

    # Add Traefik labels for Pushgateway
    if [ "$TRAEFIK_DISABLE" != true ] && [ "$TRAEFIK_INSTALLED" = true ]; then
      cat >> "$compose_file" << EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pushgateway.rule=Host(\`push.${DOMAIN}\`)"
      - "traefik.http.routers.pushgateway.entrypoints=websecure"
      - "traefik.http.routers.pushgateway.tls=true"
      - "traefik.http.routers.pushgateway.tls.certresolver=default"
      - "traefik.http.services.pushgateway.loadbalancer.server.port=9091"
EOF
    else
      cat >> "$compose_file" << EOF
    ports:
      - "9091:9091"
EOF
    fi
  fi

  # Add networks section
  if [ "$TRAEFIK_DISABLE" != true ] && [ "$TRAEFIK_INSTALLED" = true ]; then
    cat >> "$compose_file" << EOF

networks:
  default:
    name: ${COMPOSE_PROJECT_NAME}_network
  ${TRAEFIK_NETWORK}:
    external: true
EOF
  else
    cat >> "$compose_file" << EOF

networks:
  default:
    name: ${COMPOSE_PROJECT_NAME}_network
EOF
  fi

    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Docker Compose configuration generated successfully."
}

# Create web-config file for Prometheus (TLS)
generate_web_config() {
  log_info "Generating web config for TLS and authentication..."
  
  local web_config_file="${PROMETHEUS_CONFIG_DIR}/web-config.yml"
  
  # Generate web-config.yml for basic auth
  cat > "$web_config_file" << EOF
# Web configuration for Prometheus
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

tls_server_config:
  cert_file: /etc/prometheus/ssl/prometheus.crt
  key_file: /etc/prometheus/ssl/prometheus.key

basic_auth_users:
  ${PROMETHEUS_USERNAME}: $(openssl passwd -apr1 "$PROMETHEUS_PASSWORD")
EOF

  # Create SSL directory
  mkdir -p "${PROMETHEUS_CONFIG_DIR}/ssl"
  
  # Generate self-signed certificate
  if [ "$SECURE_MODE" = true ]; then
    log_info "Generating self-signed certificate..."
    
    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
      -keyout "${PROMETHEUS_CONFIG_DIR}/ssl/prometheus.key" \
      -out "${PROMETHEUS_CONFIG_DIR}/ssl/prometheus.crt" \
      -subj "/CN=${DOMAIN}/O=AgencyStack/C=US" \
      -addext "subjectAltName = DNS:${DOMAIN}"
    
    chmod 600 "${PROMETHEUS_CONFIG_DIR}/ssl/prometheus.key"
    chmod 644 "${PROMETHEUS_CONFIG_DIR}/ssl/prometheus.crt"
    
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "SSL certificate generated successfully."
  fi
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Web configuration generated successfully."
}

# Configure Grafana integration
configure_grafana() {
  if [ -z "$GRAFANA_DOMAIN" ] && [ "$INSTALL_GRAFANA" != true ]; then
    log_warning "Skipping Grafana integration: no Grafana domain specified and install not requested."
    return 0
  fi
  
  log_info "Configuring Grafana integration..."
  
  # Install Grafana if requested
  if [ "$INSTALL_GRAFANA" = true ]; then
    if [ -f "${ROOT_DIR}/scripts/components/install_grafana.sh" ]; then
      log_info "Installing Grafana with AgencyStack script..."
      bash "${ROOT_DIR}/scripts/components/install_grafana.sh" \
        --domain "${GRAFANA_DOMAIN:-grafana.$DOMAIN}" \
        --admin-user admin \
        --admin-password "$(openssl rand -hex 12)" \
        ${CLIENT_ID:+--client-id "$CLIENT_ID"} \
        ${FORCE:+--force} \
        ${WITH_DEPS:+--with-deps} \
        ${VERBOSE:+--verbose}
    else
      log_warning "Grafana installation script not found. Skipping installation."
    fi
  fi
  
  # If Grafana domain is specified, configure datasource
  if [ -n "$GRAFANA_DOMAIN" ]; then
    log_info "Setting up Prometheus as Grafana datasource..."
    
    # Create datasource JSON
    local ds_dir="${CONFIG_DIR}/grafana/provisioning/datasources"
    if [ -d "$ds_dir" ]; then
      cat > "${ds_dir}/prometheus.yml" << EOF
# Prometheus data source for Grafana
# Auto-generated on $(date +"%Y-%m-%d %H:%M:%S")

apiVersion: 1

datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://prometheus:9090
  isDefault: true
  editable: false
EOF
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Grafana datasource configuration created."
    else
      log_warning "Grafana provisioning directory not found. Manual datasource configuration will be needed."
      
      # If Grafana is available but no provisioning dir, try API configuration
      if [ -n "$GRAFANA_DOMAIN" ]; then
        log_info "Attempting to configure Grafana datasource via API..."
        
        # Wait for Grafana to be available (if just installed)
        sleep 5
        
        # Try to add datasource via API - using default admin credentials
        curl -s -X POST \
          -H "Content-Type: application/json" \
          -d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus:9090","access":"proxy","isDefault":true}' \
          "http://admin:admin@${GRAFANA_DOMAIN}/api/datasources" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
          log_success "Grafana datasource configured via API."
        else
          log_warning "Failed to configure Grafana datasource via API. Manual configuration required."
        fi
      fi
    fi
  fi
}

# Setup Makefile targets for Prometheus
setup_makefile_targets() {
  log_info "Setting up Makefile targets..."
  
  local makefile_dir="${ROOT_DIR}"
  local makefile="${makefile_dir}/Makefile"
  
  # Check if Makefile exists
  if [ ! -f "$makefile" ]; then
    log_warning "Makefile not found at ${makefile}. Skipping Makefile target setup."
    return 1
  fi
  
  # Check if Prometheus targets already exist
  if grep -q "prometheus-start:" "$makefile"; then
    log_info "Prometheus targets already exist in Makefile."
    return 0
  fi
  
  # Add Prometheus targets to Makefile
  cat >> "$makefile" << 'EOF'

# ------------------------------------------------------------------------------
# Prometheus Monitoring Targets
# ------------------------------------------------------------------------------

.PHONY: prometheus-start prometheus-stop prometheus-restart prometheus-logs prometheus-status prometheus-clean prometheus-update

prometheus-start: ## Start Prometheus monitoring stack
	@echo "Starting Prometheus stack..."
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml up -d
	@echo "Prometheus started successfully."

prometheus-stop: ## Stop Prometheus monitoring stack
	@echo "Stopping Prometheus stack..."
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml down
	@echo "Prometheus stopped successfully."

prometheus-restart: ## Restart Prometheus monitoring stack
	@echo "Restarting Prometheus stack..."
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml restart
	@echo "Prometheus restarted successfully."

prometheus-logs: ## View Prometheus logs
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml logs -f

prometheus-status: ## Check Prometheus status
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml ps

prometheus-clean: ## Remove Prometheus containers and persistent data (USE WITH CAUTION)
	@echo "Removing Prometheus stack and data..."
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml down -v
	@echo "Prometheus removed successfully."

prometheus-update: ## Update Prometheus to the latest version
	@echo "Updating Prometheus stack to the latest version..."
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml pull
	@cd /opt/agency_stack/docker-compose && docker-compose -f docker-compose.prometheus.yml up -d
	@echo "Prometheus updated successfully."

EOF
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Makefile targets added successfully."
}

# Update system configuration (firewall, etc.)
update_system_config() {
  log_info "Updating system configuration..."
  
  # Check if UFW is installed and enabled
  if command_exists ufw && ufw status | grep -q "Status: active"; then
    log_info "Configuring firewall rules..."
    
    # Allow Prometheus ports
    ufw allow 9090/tcp comment "Prometheus"
    ufw allow 9100/tcp comment "Node Exporter"
    ufw allow 9093/tcp comment "AlertManager"
    
    if [ "$INCLUDE_PUSHGATEWAY" = true ]; then
      ufw allow 9091/tcp comment "Prometheus Pushgateway"
    fi
    
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "Firewall rules updated."
  fi
  
  # Enable Docker metrics for Prometheus
  if [ -d "/etc/docker" ]; then
    log_info "Enabling Docker metrics for Prometheus..."
    
    # Create or update daemon.json
    local daemon_json="/etc/docker/daemon.json"
    if [ -f "$daemon_json" ]; then
      # Check if metrics are already enabled
      if grep -q "metrics-addr" "$daemon_json"; then
        log_info "Docker metrics already enabled."
      else
        # Backup existing file
        cp "$daemon_json" "${daemon_json}.bak"
        
        # Update with metrics configuration
        if [ "$(cat "$daemon_json" | grep -v '}' | wc -l)" -gt 2 ]; then
          # Add comma to last config item
          sed -i '$ s/}/, "metrics-addr": "0.0.0.0:9323", "experimental": true}/' "$daemon_json"
        else
          # Replace entire config
          cat > "$daemon_json" << EOF
{
  "metrics-addr": "0.0.0.0:9323",
  "experimental": true
}
EOF
        fi
        
        # Restart Docker to apply changes
        systemctl restart docker
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
        log_success "Docker metrics enabled. Docker restarted."
      fi
    else
      # Create new daemon.json
      mkdir -p /etc/docker
      cat > "$daemon_json" << EOF
{
  "metrics-addr": "0.0.0.0:9323",
  "experimental": true
}
EOF
      systemctl restart docker
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Docker metrics configuration created. Docker restarted."
    fi
  fi
}

# Main execution function
main() {
  log_info "Starting AgencyStack Prometheus installation..."
  integration_log "Installing Prometheus monitoring stack"
  
  # Check for existing installation first
  check_existing_installation
  
  # Check dependencies
  check_dependencies
  
  # Create required directories
  create_directories
  
  # Generate configurations
  generate_prometheus_config
  generate_alertmanager_config
  
  # Generate web configuration for TLS and auth
  if [ "$SECURE_MODE" = true ]; then
    generate_web_config
    generate_basic_auth
  fi
  
  # Generate Docker Compose file
  generate_docker_compose
  
  # Update system configuration if needed
  update_system_config
  
  # Set up Makefile targets
  setup_makefile_targets
  
  # Configure Grafana integration
  configure_grafana
  
  # Start services if not in config-only mode
  if [ "$CONFIG_ONLY" != true ]; then
    log_info "Starting Prometheus services..."
    cd "${COMPOSE_DIR}" && docker-compose -f docker-compose.prometheus.yml up -d
    
    # Check if services started successfully
    if docker ps | grep -q "${COMPOSE_PROJECT_NAME}_prometheus"; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Prometheus services started successfully."
    else
      log_error "Failed to start Prometheus services. Check logs for details."
      exit 1
    fi
  else
    log_info "Configuration completed successfully. Use the following to start services:"
    log_info "cd ${COMPOSE_DIR} && docker-compose -f docker-compose.prometheus.yml up -d"
  fi
  
  # Show access information
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "======================================================"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "AgencyStack Prometheus Installation Completed"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "======================================================"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Access Prometheus:      https://${DOMAIN}"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Access AlertManager:    https://alerts.${DOMAIN}"
  
  if [ "$INCLUDE_PUSHGATEWAY" = true ]; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "Access Pushgateway:     https://push.${DOMAIN}"
  fi
  
  if [ "$INSTALL_GRAFANA" = true ] || [ -n "$GRAFANA_DOMAIN" ]; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "Access Grafana:         https://${GRAFANA_DOMAIN:-grafana.$DOMAIN}"
  fi
  
  if [ "$SECURE_MODE" = true ]; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "Username:               ${PROMETHEUS_USERNAME}"
    
    if [ "$GENERATED_PASSWORD" = true ]; then
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Password:               ${PROMETHEUS_PASSWORD}"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Password saved to:      ${PROMETHEUS_CONFIG_DIR}/auth/prometheus.password"
    else
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
      log_success "Password:               <as provided>"
    fi
  fi
  
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Configuration:          ${PROMETHEUS_CONFIG_DIR}"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Data Directory:         ${PROMETHEUS_DATA_DIR}"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "Docker Compose File:    ${COMPOSE_DIR}/docker-compose.prometheus.yml"
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
  log_success "======================================================"
  
  # Register component with AgencyStack
  if [ -f "${ROOT_DIR}/scripts/integrate_components.sh" ]; then
    log_info "Registering Prometheus with AgencyStack..."
    bash "${ROOT_DIR}/scripts/integrate_components.sh" \
      --component "prometheus" \
      --domain "${DOMAIN}" \
      --description "Monitoring system and time series database" \
      --version "${PROMETHEUS_VERSION}" \
      --install-date "$(date +%Y-%m-%d)"
    
    # Mark component as installed
    mark_installed "prometheus" "${COMPONENT_DIR}"
        
    log_success "Prometheus registered with AgencyStack."
  fi
  
  integration_log "Prometheus monitoring stack installed successfully"
}

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
  log_error "This script must be run as root"
  exit 1

# Run system validation
if [ -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
  log_info "Validating system requirements..."
  bash "${ROOT_DIR}/scripts/utils/validate_system.sh" || {
    log_error "System validation failed. Please fix the issues and try again."
    exit 1
  }
  log_warning "System validation script not found. Proceeding without validation."

# Execute main function
main
