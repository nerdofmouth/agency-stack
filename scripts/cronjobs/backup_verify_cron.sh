#!/bin/bash
# backup_verify_cron.sh - Weekly backup verification script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script is designed to be run via cron weekly (Sundays at 03:00)
# It verifies all AgencyStack backups and logs the results
# If configured, it will also send alerts on failure
#
# Usage: ./backup_verify_cron.sh [--alert]
# Options:
#   --alert    Send alerts on failure regardless of .env setting
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
BACKUP_LOG="${LOG_DIR}/backup.log"
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
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Config file $CONFIG_ENV not found" >> "$BACKUP_LOG"
  exit 1
fi

# Set default values if not present in config.env
ALERT_ON_FAILURE=${ALERT_ON_FAILURE:-false}

# Log start of backup verification
echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Starting scheduled backup verification" >> "$BACKUP_LOG"

# Run backup verification and capture output
BACKUP_OUTPUT=$(cd /home/revelationx/CascadeProjects/foss-server-stack && make verify-backup 2>&1)
BACKUP_STATUS=$?

# Log the output
echo "$BACKUP_OUTPUT" >> "$BACKUP_LOG"

if [ $BACKUP_STATUS -ne 0 ]; then
  # Backup verification failed
  FAILURE_MESSAGE="Backup verification failed with status $BACKUP_STATUS"
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $FAILURE_MESSAGE" >> "$BACKUP_LOG"
  
  # Send alert if configured to do so
  if [ "$ALERT_ON_FAILURE" = true ] || [ "$FORCE_ALERT" = true ]; then
    if [ -f "${NOTIFICATION_DIR}/notify_all.sh" ]; then
      # Extract failed components from backup verification output
      FAILED_COMPONENTS=$(echo "$BACKUP_OUTPUT" | grep -oE "\[FAIL\] [A-Za-z0-9]+" | cut -d " " -f 2 | tr '\n' ', ' | sed 's/,$//')
      
      # Create alert message
      ALERT_SUBJECT="⚠️ AgencyStack Backup Verification Failed"
      ALERT_MESSAGE="Backup verification failed on server $(hostname)\n\nTimestamp: $(date +"%Y-%m-%d %H:%M:%S")\n\nFailed components: $FAILED_COMPONENTS\n\nPlease check the backup log for more details: $BACKUP_LOG"
      
      # Log alert
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ALERT] $ALERT_SUBJECT - $ALERT_MESSAGE" >> "$ALERTS_LOG"
      
      # Send alert
      bash "${NOTIFICATION_DIR}/notify_all.sh" "$ALERT_SUBJECT" "$ALERT_MESSAGE"
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Notification script not found at ${NOTIFICATION_DIR}/notify_all.sh" >> "$BACKUP_LOG"
    fi
  fi
else
  # Backup verification succeeded
  echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Backup verification completed successfully" >> "$BACKUP_LOG"
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Scheduled backup verification completed" >> "$BACKUP_LOG"
echo "----------------------------------------" >> "$BACKUP_LOG"

exit $BACKUP_STATUS
