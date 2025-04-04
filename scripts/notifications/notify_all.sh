#!/bin/bash
# notify_all.sh - Multi-channel notification script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sends notifications to all configured channels (email and Telegram)
# It requires the individual channel scripts to be configured properly
#
# Usage: ./notify_all.sh "Message title" "Message body"
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
ALERTS_LOG="${LOG_DIR}/alerts.log"
SCRIPTS_DIR="/home/revelationx/CascadeProjects/foss-server-stack/scripts"
NOTIFICATION_DIR="${SCRIPTS_DIR}/notifications"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 \"Title\" \"Message body\""
  echo "Example: $0 \"Server Alert\" \"Disk space is low\""
  exit 1
fi

TITLE="$1"
MESSAGE="$2"

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
fi

# Set default values if not present in config.env
ALERT_EMAIL_ENABLED=${ALERT_EMAIL_ENABLED:-true}
ALERT_TELEGRAM_ENABLED=${ALERT_TELEGRAM_ENABLED:-true}

# Log the alert
echo "$(date +"%Y-%m-%d %H:%M:%S") [ALERT] $TITLE - $MESSAGE" >> "$ALERTS_LOG"

# Send email notification if enabled
if [ "$ALERT_EMAIL_ENABLED" = true ] && [ -f "${NOTIFICATION_DIR}/notify_email.sh" ]; then
  echo "Sending email notification..."
  bash "${NOTIFICATION_DIR}/notify_email.sh" "$TITLE" "$MESSAGE"
  EMAIL_STATUS=$?
  
  if [ $EMAIL_STATUS -ne 0 ]; then
    echo "Failed to send email notification"
  fi
else
  echo "Email notifications disabled or script not found"
fi

# Send Telegram notification if enabled
if [ "$ALERT_TELEGRAM_ENABLED" = true ] && [ -f "${NOTIFICATION_DIR}/notify_telegram.sh" ]; then
  echo "Sending Telegram notification..."
  bash "${NOTIFICATION_DIR}/notify_telegram.sh" "$TITLE" "$MESSAGE"
  TELEGRAM_STATUS=$?
  
  if [ $TELEGRAM_STATUS -ne 0 ]; then
    echo "Failed to send Telegram notification"
  fi
else
  echo "Telegram notifications disabled or script not found"
fi

# Return success if at least one notification was sent successfully
if ( [ "$ALERT_EMAIL_ENABLED" = true ] && [ $EMAIL_STATUS -eq 0 ] ) || \
   ( [ "$ALERT_TELEGRAM_ENABLED" = true ] && [ $TELEGRAM_STATUS -eq 0 ] ); then
  echo "Alert sent successfully through at least one channel"
  exit 0
else
  echo "Failed to send alert through any channel"
  exit 1
fi
