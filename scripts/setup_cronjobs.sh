#!/bin/bash
# setup_cronjobs.sh - Installer for AgencyStack scheduled tasks
# https://stack.nerdofmouth.com
#
# This script installs all necessary cron jobs for AgencyStack
# It avoids duplicates and can be safely re-run
# All jobs log to /var/log/agency_stack/cron/
#
# Usage: ./setup_cronjobs.sh
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
SCRIPTS_DIR="/home/revelationx/CascadeProjects/foss-server-stack/scripts"
CRONJOBS_DIR="${SCRIPTS_DIR}/cronjobs"
LOG_DIR="/var/log/agency_stack/cron"
CRON_TEMP_FILE="/tmp/agencystack_crontab.tmp"

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Cron Jobs Setup${NC}"
echo -e "==============================="
echo -e "This script will set up scheduled tasks for AgencyStack.\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Ensure scripts directory exists
if [ ! -d "$CRONJOBS_DIR" ]; then
  echo -e "${RED}Error: Cronjobs directory not found at $CRONJOBS_DIR${NC}"
  exit 1
fi

# Ensure all scripts are executable
echo -e "${BLUE}Making all cron scripts executable...${NC}"
chmod +x ${CRONJOBS_DIR}/*.sh
echo -e "${GREEN}Done${NC}\n"

# Create log directory
echo -e "${BLUE}Creating log directory...${NC}"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"
echo -e "${GREEN}Log directory created at $LOG_DIR${NC}\n"

# Function to add a cron job
add_cron_job() {
  local user="$1"
  local schedule="$2"
  local command="$3"
  local description="$4"
  
  echo -e "${BLUE}Setting up cron job: ${CYAN}$description${NC}"
  
  # Get current crontab for user
  crontab -u "$user" -l 2>/dev/null > "$CRON_TEMP_FILE" || echo "" > "$CRON_TEMP_FILE"
  
  # Check if cron job already exists
  if grep -q "$command" "$CRON_TEMP_FILE"; then
    echo -e "${YELLOW}Cron job already exists, skipping${NC}"
  else
    # Add cron job
    echo -e "# AgencyStack - $description" >> "$CRON_TEMP_FILE"
    echo -e "$schedule $command > $LOG_DIR/\$(basename $command).log 2>&1" >> "$CRON_TEMP_FILE"
    echo -e "" >> "$CRON_TEMP_FILE"
    
    # Install new crontab
    crontab -u "$user" "$CRON_TEMP_FILE"
    echo -e "${GREEN}Cron job installed successfully${NC}"
  fi
  echo ""
}

# Install cron jobs
echo -e "${BLUE}${BOLD}Installing cron jobs...${NC}\n"

# 1. Daily health check at 02:00
add_cron_job "root" "0 2 * * *" "$CRONJOBS_DIR/health_check_cron.sh" "Daily health check"

# 2. Weekly backup verification on Sundays at 03:00
add_cron_job "root" "0 3 * * 0" "$CRONJOBS_DIR/backup_verify_cron.sh" "Weekly backup verification"

# 3. Hourly dashboard update
add_cron_job "root" "0 * * * *" "$CRONJOBS_DIR/dashboard_update_cron.sh" "Hourly dashboard update"

# 4. Daily integrations refresh at 01:00
add_cron_job "root" "0 1 * * *" "$CRONJOBS_DIR/integrations_refresh_cron.sh" "Daily integrations refresh"

# Clean up
rm -f "$CRON_TEMP_FILE"

# Log rotation setup
echo -e "${BLUE}Setting up log rotation...${NC}"
cat > /etc/logrotate.d/agency_stack_cron << EOF
/var/log/agency_stack/cron/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
}
EOF
echo -e "${GREEN}Log rotation configured${NC}\n"

# Summary
echo -e "${GREEN}${BOLD}AgencyStack cron jobs setup complete!${NC}"
echo -e "The following jobs have been installed:"
echo -e "  - Daily health check at 02:00"
echo -e "  - Weekly backup verification on Sundays at 03:00"
echo -e "  - Hourly dashboard update"
echo -e "  - Daily integrations refresh at 01:00"
echo -e "\nLogs will be written to: ${CYAN}$LOG_DIR${NC}"
echo -e "All jobs can be viewed with ${CYAN}crontab -l${NC}"

exit 0
