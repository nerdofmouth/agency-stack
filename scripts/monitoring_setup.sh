#!/bin/bash
# monitoring_setup.sh - Install Loki and Grafana monitoring stack for AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/monitoring_setup-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}📊 AgencyStack Monitoring Setup${NC}"
log "=================================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  log "${RED}This script must be run as root${NC}"
  exit 1
fi

# Verify script locations
SCRIPTS_DIR="/opt/agency_stack/scripts"
BOOTSTRAP_DIR="/opt/agency_stack/scripts/agency_stack_bootstrap_bundle_v10"
INSTALL_LOKI="${BOOTSTRAP_DIR}/install_loki.sh"
INSTALL_GRAFANA="${BOOTSTRAP_DIR}/install_grafana.sh"

# Copy scripts to the agency_stack directory if they're in the current directory
for script in install_loki.sh install_grafana.sh; do
  if [ -f "$(dirname "$0")/agency_stack_bootstrap_bundle_v10/$script" ] && [ ! -f "${BOOTSTRAP_DIR}/$script" ]; then
    mkdir -p "${BOOTSTRAP_DIR}"
    cp "$(dirname "$0")/agency_stack_bootstrap_bundle_v10/$script" "${BOOTSTRAP_DIR}/$script"
    chmod +x "${BOOTSTRAP_DIR}/$script"
    log "${GREEN}Copied $script to ${BOOTSTRAP_DIR}/$script${NC}"
  fi
done

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  log "${RED}Error: config.env file not found${NC}"
  log "Please run the AgencyStack installation first"
  exit 1
fi

# Install Loki
log "${BLUE}Installing Loki log aggregation...${NC}"
if [ -f "$INSTALL_LOKI" ]; then
  bash "$INSTALL_LOKI"
  if [ $? -ne 0 ]; then
    log "${RED}Failed to install Loki${NC}"
    log "Check the log file for details: $LOG_FILE"
    exit 1
  fi
else
  log "${RED}Loki installation script not found: $INSTALL_LOKI${NC}"
  exit 1
fi

# Install Grafana
log "${BLUE}Installing Grafana dashboard...${NC}"
if [ -f "$INSTALL_GRAFANA" ]; then
  bash "$INSTALL_GRAFANA"
  if [ $? -ne 0 ]; then
    log "${RED}Failed to install Grafana${NC}"
    log "Check the log file for details: $LOG_FILE"
    exit 1
  fi
else
  log "${RED}Grafana installation script not found: $INSTALL_GRAFANA${NC}"
  exit 1
fi

# Add monitoring configuration to AgencyStack config.env
log "${BLUE}Updating AgencyStack configuration...${NC}"
source /opt/agency_stack/config.env

if ! grep -q "MONITORING_ENABLED" /opt/agency_stack/config.env; then
  echo -e "\n# Monitoring Configuration" >> /opt/agency_stack/config.env
  echo "MONITORING_ENABLED=true" >> /opt/agency_stack/config.env
  echo "ALERT_EMAIL_ENABLED=false" >> /opt/agency_stack/config.env
  echo "ALERT_EMAIL_RECIPIENT=admin@${PRIMARY_DOMAIN}" >> /opt/agency_stack/config.env
  echo "ALERT_TELEGRAM_ENABLED=false" >> /opt/agency_stack/config.env
  echo "TELEGRAM_BOT_TOKEN=" >> /opt/agency_stack/config.env
  echo "TELEGRAM_CHAT_ID=" >> /opt/agency_stack/config.env
  echo "ALERT_WEBHOOK_ENABLED=false" >> /opt/agency_stack/config.env
  echo "WEBHOOK_URL=" >> /opt/agency_stack/config.env
  log "${GREEN}Updated configuration with monitoring settings${NC}"
fi

# Setup cron jobs
log "${BLUE}Setting up automated monitoring tasks...${NC}"
if [ -f "$(dirname "$0")/cron_setup.sh" ]; then
  bash "$(dirname "$0")/cron_setup.sh"
else
  log "${YELLOW}Cron setup script not found${NC}"
  log "To set up automated monitoring tasks, run: make setup-cron"
fi

log ""
log "${GREEN}${BOLD}Monitoring setup complete!${NC}"
log "You can access your monitoring stack at:"
log "- Grafana: https://grafana.${PRIMARY_DOMAIN} (port 3333)"
log "- Loki: https://loki.${PRIMARY_DOMAIN} (internal use only)"
log ""
log "Default Grafana credentials:"
log "- Username: admin"
log "- Password: Check the output above or /opt/agency_stack/config.env"
log ""
log "To enable alerting, edit /opt/agency_stack/config.env and set:"
log "- ALERT_EMAIL_ENABLED=true (requires valid SMTP configuration)"
log "- ALERT_TELEGRAM_ENABLED=true (requires bot token and chat ID)"
log "- ALERT_WEBHOOK_ENABLED=true (requires webhook URL)"
