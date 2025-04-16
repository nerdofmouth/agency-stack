#!/bin/bash
# health_check_cron.sh - Daily health check script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script is designed to be run via cron daily at 02:00
# It performs a health check on all AgencyStack components and logs the results
# If configured, it will also send alerts on failure
#
# Usage: ./health_check_cron.sh [--alert]
# Options:
#   --alert    Send alerts on failure regardless of .env setting
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
HEALTH_LOG="${LOG_DIR}/health.log"
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
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Config file $CONFIG_ENV not found" >> "$HEALTH_LOG"
  exit 1
fi

# Set default values if not present in config.env
ALERT_ON_FAILURE=${ALERT_ON_FAILURE:-false}

# Log start of health check
echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Starting scheduled health check" >> "$HEALTH_LOG"

# Run health check and capture output
HEALTH_OUTPUT=$(cd /home/revelationx/CascadeProjects/foss-server-stack && make health-check 2>&1)
HEALTH_STATUS=$?

# Log the output
echo "$HEALTH_OUTPUT" >> "$HEALTH_LOG"

if [ $HEALTH_STATUS -ne 0 ]; then
  # Health check failed
  FAILURE_MESSAGE="Health check failed with status $HEALTH_STATUS"
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $FAILURE_MESSAGE" >> "$HEALTH_LOG"
  
  # Send alert if configured to do so
  if [ "$ALERT_ON_FAILURE" = true ] || [ "$FORCE_ALERT" = true ]; then
    if [ -f "${NOTIFICATION_DIR}/notify_all.sh" ]; then
      # Extract failed services from health check output
      FAILED_SERVICES=$(echo "$HEALTH_OUTPUT" | grep -oE "\[FAIL\] [A-Za-z0-9]+" | cut -d " " -f 2 | tr '\n' ', ' | sed 's/,$//')
      
      # Create alert message
      ALERT_SUBJECT="🔴 AgencyStack Health Check Failed"
      ALERT_MESSAGE="Health check failed on server $(hostname)\n\nTimestamp: $(date +"%Y-%m-%d %H:%M:%S")\n\nFailed services: $FAILED_SERVICES\n\nPlease check the health log for more details: $HEALTH_LOG"
      
      # Log alert
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ALERT] $ALERT_SUBJECT - $ALERT_MESSAGE" >> "$ALERTS_LOG"
      
      # Send alert
      bash "${NOTIFICATION_DIR}/notify_all.sh" "$ALERT_SUBJECT" "$ALERT_MESSAGE"
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Notification script not found at ${NOTIFICATION_DIR}/notify_all.sh" >> "$HEALTH_LOG"
    fi
  fi
else
  # Health check succeeded
  echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Health check completed successfully" >> "$HEALTH_LOG"
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Scheduled health check completed" >> "$HEALTH_LOG"
echo "----------------------------------------" >> "$HEALTH_LOG"

exit $HEALTH_STATUS
