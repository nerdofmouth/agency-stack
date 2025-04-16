#!/bin/bash
# integrations_refresh_cron.sh - Daily integrations refresh script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script is designed to be run via cron daily at 01:00
# It refreshes all integrations to ensure they remain properly connected
# This is idempotent and only applies changes if needed
#
# Usage: ./integrations_refresh_cron.sh [--alert]
# Options:
#   --alert    Send alerts on failure regardless of .env setting
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
INTEGRATION_LOG="${LOG_DIR}/integration.log"
ALERTS_LOG="${LOG_DIR}/alerts.log"
SCRIPTS_DIR="/opt/agency_stack/scripts"
NOTIFICATION_DIR="${SCRIPTS_DIR}/notifications"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Parse command line arguments
FORCE_ALERT=false
for arg in "$@"; do
  case $arg in
    --alert)
      FORCE_ALERT=true
      ;;
  esac
done

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Config file $CONFIG_ENV not found" >> "$INTEGRATION_LOG"
  exit 1
fi

# Set default values if not present in config.env
ALERT_ON_FAILURE=${ALERT_ON_FAILURE:-false}

# Log start of integrations refresh
echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Starting scheduled integrations refresh" >> "$INTEGRATION_LOG"

# Run integrations refresh and capture output
INTEGRATION_OUTPUT=$(cd /home/revelationx/CascadeProjects/foss-server-stack && make integrate-components 2>&1)
INTEGRATION_STATUS=$?

# Log the output
echo "$INTEGRATION_OUTPUT" >> "$INTEGRATION_LOG"

if [ $INTEGRATION_STATUS -ne 0 ]; then
  # Integrations refresh failed
  FAILURE_MESSAGE="Integrations refresh failed with status $INTEGRATION_STATUS"
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $FAILURE_MESSAGE" >> "$INTEGRATION_LOG"
  
  # Send alert if configured to do so
  if [ "$ALERT_ON_FAILURE" = true ] || [ "$FORCE_ALERT" = true ]; then
    if [ -f "${NOTIFICATION_DIR}/notify_all.sh" ]; then
      # Extract failed integrations from output
      FAILED_INTEGRATIONS=$(echo "$INTEGRATION_OUTPUT" | grep -oE "\[FAIL\] [A-Za-z0-9-]+" | cut -d " " -f 2 | tr '\n' ', ' | sed 's/,$//')
      
      # Create alert message
      ALERT_SUBJECT="🔌 AgencyStack Integrations Refresh Failed"
      ALERT_MESSAGE="Integrations refresh failed on server $(hostname)\n\nTimestamp: $(date +"%Y-%m-%d %H:%M:%S")\n\nFailed integrations: $FAILED_INTEGRATIONS\n\nPlease check the integration log for more details: $INTEGRATION_LOG"
      
      # Log alert
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ALERT] $ALERT_SUBJECT - $ALERT_MESSAGE" >> "$ALERTS_LOG"
      
      # Send alert
      bash "${NOTIFICATION_DIR}/notify_all.sh" "$ALERT_SUBJECT" "$ALERT_MESSAGE"
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Notification script not found at ${NOTIFICATION_DIR}/notify_all.sh" >> "$INTEGRATION_LOG"
    fi
  fi
else
  # Integrations refresh succeeded
  echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Integrations refresh completed successfully" >> "$INTEGRATION_LOG"
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Scheduled integrations refresh completed" >> "$INTEGRATION_LOG"
echo "----------------------------------------" >> "$INTEGRATION_LOG"

exit $INTEGRATION_STATUS
