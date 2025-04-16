#!/bin/bash
# setup_log_segmentation.sh - Configure client-specific log segmentation
# https://stack.nerdofmouth.com
#
# This script configures log rotation and segmentation for AgencyStack clients
# It ensures logs are properly segmented by client for better isolation and auditing
#
# Usage: ./setup_log_segmentation.sh [--client-id <client_id>]
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
CLIENTS_DIR="${CONFIG_DIR}/clients"
LOG_DIR="/var/log/agency_stack"
CLIENT_LOGS_DIR="${LOG_DIR}/clients"
CLIENT_ID=""

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Log Segmentation Setup${NC}"
echo -e "===================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Usage: $0 [--client-id <client_id>]"
      exit 1
      ;;
  esac
done

# Function to log messages
log() {
  echo -e "$1"
}

# Function to configure log directories for a client
setup_client_logs() {
  local client="$1"
  
  if [ ! -d "${CLIENTS_DIR}/${client}" ]; then
    log "${YELLOW}Warning: Client ${client} does not exist in ${CLIENTS_DIR}${NC}"
    return 1
  fi
  
  log "${BLUE}Setting up logs for client: ${client}${NC}"
  
  # Create client log directories
  mkdir -p "${CLIENT_LOGS_DIR}/${client}"
  
  # Create standard log files if they don't exist
  touch "${CLIENT_LOGS_DIR}/${client}/access.log"
  touch "${CLIENT_LOGS_DIR}/${client}/error.log"
  touch "${CLIENT_LOGS_DIR}/${client}/audit.log"
  touch "${CLIENT_LOGS_DIR}/${client}/backup.log"
  
  # Create service-specific log directories
  mkdir -p "${CLIENT_LOGS_DIR}/${client}/services"
  chmod 750 "${CLIENT_LOGS_DIR}/${client}"
  
  # Configure log rotation for client logs
  LOGROTATE_CONF="/etc/logrotate.d/agency-stack-${client}"
  
  cat > "$LOGROTATE_CONF" << EOF
${CLIENT_LOGS_DIR}/${client}/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  create 640 root root
  postrotate
    systemctl reload rsyslog >/dev/null 2>&1 || true
  endscript
}

${CLIENT_LOGS_DIR}/${client}/services/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  create 640 root root
  postrotate
    systemctl reload rsyslog >/dev/null 2>&1 || true
  endscript
}
EOF
  
  log "${GREEN}Created log rotation configuration in ${LOGROTATE_CONF}${NC}"
  
  # Create rsyslog configuration for client
  RSYSLOG_CONF="/etc/rsyslog.d/30-agency-stack-${client}.conf"
  
  cat > "$RSYSLOG_CONF" << EOF
# AgencyStack rsyslog configuration for client: ${client}
# Created: $(date +"%Y-%m-%d %H:%M:%S")

# Filter logs by client ID and container labels
:syslogtag, startswith, "docker/${client}_" /var/log/agency_stack/clients/${client}/services/docker.log
:syslogtag, startswith, "docker/" {
  if \$msg contains "client.id=${client}" then /var/log/agency_stack/clients/${client}/services/docker.log
}

# Route Apache/Nginx logs containing the client domain
:msg, contains, "client_id=${client}" /var/log/agency_stack/clients/${client}/access.log

# Keycloak logs for this client's realm
:syslogtag, startswith, "keycloak" {
  if \$msg contains "realm=${client}" then /var/log/agency_stack/clients/${client}/services/keycloak.log
}

# Database logs for this client
:syslogtag, contains, "mysql" {
  if \$msg contains "client_${client}" then /var/log/agency_stack/clients/${client}/services/mysql.log
}

:syslogtag, contains, "postgres" {
  if \$msg contains "client_${client}" then /var/log/agency_stack/clients/${client}/services/postgres.log
}
EOF
  
  log "${GREEN}Created rsyslog configuration in ${RSYSLOG_CONF}${NC}"
  
  # Reload rsyslog
  systemctl restart rsyslog
  
  log "${GREEN}Reloaded rsyslog service${NC}"
  
  # Update docker-compose override to add logging labels
  DOCKER_COMPOSE_FILE="${CLIENTS_DIR}/${client}/docker-compose.override.yml"
  
  if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    log "${BLUE}Updating Docker Compose file with logging configuration...${NC}"
    
    # Backup existing file
    cp "$DOCKER_COMPOSE_FILE" "${DOCKER_COMPOSE_FILE}.bak"
    
    # Add logging labels to services if not already present
    if ! grep -q "logging:" "$DOCKER_COMPOSE_FILE"; then
      # Add logging configuration to all services
      sed -i '/services:/a \
  x-client-logging: &client-logging\n\
    logging:\n\
      driver: "json-file"\n\
      options:\n\
        tag: "{{.Name}}"\n\
        labels: "client.id,client.name"\n\
        max-size: "10m"\n\
        max-file: "3"' "$DOCKER_COMPOSE_FILE"
      
      # Find all service entries and add the logging reference
      services=$(grep -E '^ +[a-zA-Z0-9_-]+:' "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
      for service in $services; do
        if ! grep -q "<<: \*client-logging" "$DOCKER_COMPOSE_FILE"; then
          sed -i "/^ \+${service}:/a \    <<: *client-logging" "$DOCKER_COMPOSE_FILE"
        fi
      done
      
      log "${GREEN}Added logging configuration to Docker Compose file${NC}"
    else
      log "${YELLOW}Logging configuration already exists in Docker Compose file${NC}"
    fi
  else
    log "${YELLOW}Warning: Docker Compose override file not found for client ${client}${NC}"
  fi
  
  log "${GREEN}Log segmentation setup complete for client ${client}${NC}"
  return 0
}

# Main function
main() {
  # Create main log directories if they don't exist
  mkdir -p "$LOG_DIR"
  mkdir -p "$CLIENT_LOGS_DIR"
  
  # Set proper permissions
  chmod 750 "$LOG_DIR"
  chmod 750 "$CLIENT_LOGS_DIR"
  
  # Configure global log rotation
  GLOBAL_LOGROTATE_CONF="/etc/logrotate.d/agency-stack"
  
  cat > "$GLOBAL_LOGROTATE_CONF" << EOF
${LOG_DIR}/*.log {
  daily
  rotate 30
  compress
  delaycompress
  missingok
  notifempty
  create 640 root root
  postrotate
    systemctl reload rsyslog >/dev/null 2>&1 || true
  endscript
}
EOF
  
  log "${GREEN}Created global log rotation configuration in ${GLOBAL_LOGROTATE_CONF}${NC}"
  
  # Create global rsyslog configuration
  GLOBAL_RSYSLOG_CONF="/etc/rsyslog.d/10-agency-stack.conf"
  
  cat > "$GLOBAL_RSYSLOG_CONF" << EOF
# AgencyStack global rsyslog configuration
# Created: $(date +"%Y-%m-%d %H:%M:%S")

# Create a template for Docker logs to extract client ID from labels
\$template AgencyStackDockerFormat,"%timestamp% [%syslogtag%] %msg%\\n"

# Docker logs for AgencyStack containers
:syslogtag, startswith, "docker/agency_stack" /var/log/agency_stack/docker.log;AgencyStackDockerFormat

# Aggregate all security-related logs
:syslogtag, contains, "auth" /var/log/agency_stack/security.log
:syslogtag, contains, "authpriv" /var/log/agency_stack/security.log
:syslogtag, contains, "keycloak" /var/log/agency_stack/security.log
:msg, contains, "authentication" /var/log/agency_stack/security.log
:msg, contains, "failed login" /var/log/agency_stack/security.log
:msg, contains, "unauthorized" /var/log/agency_stack/security.log
EOF
  
  log "${GREEN}Created global rsyslog configuration in ${GLOBAL_RSYSLOG_CONF}${NC}"
  
  # Process specific client if provided, otherwise process all clients
  if [ -n "$CLIENT_ID" ]; then
    setup_client_logs "$CLIENT_ID"
  else
    log "${BLUE}Setting up logs for all clients...${NC}"
    
    # Get all client directories
    for client_dir in "${CLIENTS_DIR}"/*; do
      if [ -d "$client_dir" ]; then
        client=$(basename "$client_dir")
        setup_client_logs "$client"
      fi
    done
  fi
  
  # Reload rsyslog to apply all changes
  systemctl restart rsyslog
  
  # Update Docker daemon to support log labels
  DOCKER_DAEMON_CONF="/etc/docker/daemon.json"
  
  if [ ! -f "$DOCKER_DAEMON_CONF" ]; then
    cat > "$DOCKER_DAEMON_CONF" << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "client.id,client.name"
  }
}
EOF
    log "${GREEN}Created Docker daemon configuration in ${DOCKER_DAEMON_CONF}${NC}"
    
    # Restart Docker to apply the changes
    log "${YELLOW}Restarting Docker to apply logging changes...${NC}"
    systemctl restart docker
    log "${GREEN}Docker restarted${NC}"
  elif ! grep -q '"labels":' "$DOCKER_DAEMON_CONF"; then
    # Backup existing configuration
    cp "$DOCKER_DAEMON_CONF" "${DOCKER_DAEMON_CONF}.bak"
    
    # Add log labels support if not already present
    if grep -q '"log-opts":' "$DOCKER_DAEMON_CONF"; then
      # Add to existing log-opts
      sed -i '/"log-opts": {/ a\    "labels": "client.id,client.name",' "$DOCKER_DAEMON_CONF"
    else
      # Add new log-opts section before the closing brace
      sed -i '/{/ a\  "log-driver": "json-file",\n  "log-opts": {\n    "max-size": "10m",\n    "max-file": "3",\n    "labels": "client.id,client.name"\n  }' "$DOCKER_DAEMON_CONF"
    fi
    
    log "${GREEN}Updated Docker daemon configuration to support log labels${NC}"
    
    # Restart Docker to apply the changes
    log "${YELLOW}Restarting Docker to apply logging changes...${NC}"
    systemctl restart docker
    log "${GREEN}Docker restarted${NC}"
  else
    log "${GREEN}Docker daemon already configured for log labels${NC}"
  fi
  
  # Final confirmation
  log "\n${GREEN}${BOLD}Log segmentation setup complete!${NC}"
  log "Logs are now segmented by client in ${CLIENT_LOGS_DIR}"
  log "Log rotation has been configured for all log files"
  log "Docker logs will include client ID and name labels"
}

# Run main function
main

exit 0
