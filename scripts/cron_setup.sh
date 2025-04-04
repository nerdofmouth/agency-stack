#!/bin/bash
# cron_setup.sh - Configure automated jobs for AgencyStack
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

# Variables
SCRIPTS_DIR="$(dirname "$0")"
AGENCY_STACK_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/cron_setup-$(date +%Y%m%d-%H%M%S).log"
LOGROTATE_CONF="/etc/logrotate.d/agency_stack"
CRON_USER="root"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}📅 AgencyStack Cron Setup${NC}"
log "============================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Function to create cron jobs
setup_cron_jobs() {
  log "${BLUE}Setting up cron jobs for AgencyStack...${NC}"
  
  # Create temporary file for crontab
  TEMP_CRONTAB=$(mktemp)
  
  # Export current crontab
  crontab -l -u "$CRON_USER" > "$TEMP_CRONTAB" 2>/dev/null || echo "" > "$TEMP_CRONTAB"
  
  # Add marker for AgencyStack cron jobs
  if ! grep -q "# AgencyStack Automated Jobs" "$TEMP_CRONTAB"; then
    echo "" >> "$TEMP_CRONTAB"
    echo "# AgencyStack Automated Jobs" >> "$TEMP_CRONTAB"
    echo "# Do not edit this section manually, use make setup-cron" >> "$TEMP_CRONTAB"
  else
    # Remove existing AgencyStack jobs
    sed -i '/# AgencyStack Automated Jobs/,/# End AgencyStack Jobs/d' "$TEMP_CRONTAB"
    echo "" >> "$TEMP_CRONTAB"
    echo "# AgencyStack Automated Jobs" >> "$TEMP_CRONTAB"
    echo "# Do not edit this section manually, use make setup-cron" >> "$TEMP_CRONTAB"
  fi
  
  # Add health check cron job (daily at 3 AM)
  echo "0 3 * * * cd $AGENCY_STACK_DIR && bash ${SCRIPTS_DIR}/health_check.sh --auto > $LOG_DIR/health_check_cron.log 2>&1" >> "$TEMP_CRONTAB"
  log "${GREEN}✅ Added health check cron job (daily at 3 AM)${NC}"
  
  # Add backup verification cron job (weekly on Sunday at 4 AM)
  if [ -f "${SCRIPTS_DIR}/verify_backup.sh" ]; then
    echo "0 4 * * 0 cd $AGENCY_STACK_DIR && bash ${SCRIPTS_DIR}/verify_backup.sh --auto > $LOG_DIR/backup_verify_cron.log 2>&1" >> "$TEMP_CRONTAB"
    log "${GREEN}✅ Added backup verification cron job (weekly on Sunday at 4 AM)${NC}"
  else
    log "${YELLOW}⚠️ Skipping backup verification cron job: verify_backup.sh not found${NC}"
  fi
  
  # Add config snapshot cron job (daily at 2 AM)
  if [ -f "${SCRIPTS_DIR}/config_snapshot.sh" ]; then
    echo "0 2 * * * cd $AGENCY_STACK_DIR && bash ${SCRIPTS_DIR}/config_snapshot.sh snapshot \"Automated daily snapshot\" --auto > $LOG_DIR/config_snapshot_cron.log 2>&1" >> "$TEMP_CRONTAB"
    log "${GREEN}✅ Added configuration snapshot cron job (daily at 2 AM)${NC}"
  else
    log "${YELLOW}⚠️ Skipping configuration snapshot cron job: config_snapshot.sh not found${NC}"
  fi
  
  # Add DNS verification cron job (daily at 1 AM)
  if [ -f "${SCRIPTS_DIR}/verify_dns.sh" ]; then
    echo "0 1 * * * cd $AGENCY_STACK_DIR && bash ${SCRIPTS_DIR}/verify_dns.sh --auto > $LOG_DIR/dns_verify_cron.log 2>&1" >> "$TEMP_CRONTAB"
    log "${GREEN}✅ Added DNS verification cron job (daily at 1 AM)${NC}"
  else
    log "${YELLOW}⚠️ Skipping DNS verification cron job: verify_dns.sh not found${NC}"
  fi
  
  # Add MOTD update cron job (daily at 5 AM)
  if [ -f "${SCRIPTS_DIR}/motd_generator.sh" ]; then
    echo "0 5 * * * cd $AGENCY_STACK_DIR && bash ${SCRIPTS_DIR}/motd_generator.sh --auto > $LOG_DIR/motd_generator_cron.log 2>&1" >> "$TEMP_CRONTAB"
    log "${GREEN}✅ Added MOTD update cron job (daily at 5 AM)${NC}"
  else
    log "${YELLOW}⚠️ Skipping MOTD update cron job: motd_generator.sh not found${NC}"
  fi
  
  # Add end marker
  echo "# End AgencyStack Jobs" >> "$TEMP_CRONTAB"
  
  # Install new crontab
  crontab -u "$CRON_USER" "$TEMP_CRONTAB"
  
  # Clean up
  rm -f "$TEMP_CRONTAB"
  
  log "${GREEN}✅ AgencyStack cron jobs setup complete${NC}"
}

# Function to setup log rotation
setup_log_rotation() {
  log "${BLUE}Setting up log rotation for AgencyStack...${NC}"
  
  # Create logrotate configuration
  cat > "$LOGROTATE_CONF" << EOL
$LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOL
  
  # Make sure logrotate configuration is valid
  if logrotate -d "$LOGROTATE_CONF" > /dev/null 2>&1; then
    log "${GREEN}✅ Log rotation configured successfully${NC}"
    log "${GREEN}✅ Logs will be rotated daily and kept for 14 days${NC}"
  else
    log "${RED}❌ Error in logrotate configuration${NC}"
    log "${YELLOW}⚠️ Using fallback configuration${NC}"
    
    # Fallback configuration
    cat > "$LOGROTATE_CONF" << EOL
$LOG_DIR/*.log {
    weekly
    missingok
    rotate 4
    compress
    notifempty
}
EOL
    
    log "${YELLOW}⚠️ Fallback configuration: weekly rotation, kept for 4 weeks${NC}"
  fi
}

# Main function
main() {
  # Check if script is run as root
  if [ "$EUID" -ne 0 ]; then
    log "${RED}Error: This script must be run as root${NC}"
    exit 1
  fi
  
  # Check if crontab is available
  if ! command -v crontab &> /dev/null; then
    log "${RED}Error: crontab is not installed${NC}"
    log "Please install it with: apt-get install cron"
    exit 1
  fi
  
  # Check if logrotate is available
  if ! command -v logrotate &> /dev/null; then
    log "${YELLOW}Warning: logrotate is not installed${NC}"
    log "Log rotation will not be configured"
    log "Install it with: apt-get install logrotate"
  else
    setup_log_rotation
  fi
  
  # Ask for confirmation if not in auto mode
  if [ "$AUTO_MODE" = false ]; then
    log "${YELLOW}This will set up the following cron jobs:${NC}"
    log "  - Health check: Daily at 3 AM"
    log "  - Backup verification: Weekly on Sunday at 4 AM"
    log "  - Configuration snapshot: Daily at 2 AM"
    log "  - DNS verification: Daily at 1 AM"
    log "  - MOTD update: Daily at 5 AM"
    log ""
    read -p "Continue with setup? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
      log "${YELLOW}Cron setup cancelled${NC}"
      exit 0
    fi
  fi
  
  # Set up cron jobs
  setup_cron_jobs
  
  log ""
  log "${GREEN}${BOLD}✅ AgencyStack cron setup complete!${NC}"
  log "${CYAN}All automated jobs will log to: ${LOG_DIR}/${NC}"
  log "${CYAN}Log rotation is configured to retain logs for 14 days${NC}"
}

# Run main function
main
