#!/bin/bash
# notify_email.sh - Email notification script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sends email notifications using the Mailu SMTP relay
# It requires the Mailu component to be installed and properly configured
#
# Usage: ./notify_email.sh "Subject" "Message body"
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
ALERTS_LOG="${LOG_DIR}/alerts.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 \"Subject\" \"Message body\""
  echo "Example: $0 \"Server Alert\" \"Disk space is low\""
  exit 1
fi

SUBJECT="$1"
MESSAGE="$2"

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Config file $CONFIG_ENV not found" >> "$ALERTS_LOG"
  exit 1
fi

# Check if required variables are set
if [ -z "$ALERT_EMAIL_FROM" ] || [ -z "$ALERT_EMAIL_TO" ] || [ -z "$ALERT_EMAIL_SERVER" ]; then
  # Try to get values from Mailu configuration if installed
  if [ -d "/opt/agency_stack/mailu" ] && [ -f "/opt/agency_stack/mailu/.env" ]; then
    source "/opt/agency_stack/mailu/.env"
    ALERT_EMAIL_FROM="${POSTMASTER}@${DOMAIN}"
    ALERT_EMAIL_TO="${POSTMASTER}@${DOMAIN}"
    ALERT_EMAIL_SERVER="mail.${DOMAIN}"
    ALERT_EMAIL_PORT="587"
    ALERT_EMAIL_USER="${POSTMASTER}@${DOMAIN}"
    ALERT_EMAIL_PASSWORD="${POSTMASTER_PASSWORD}"
    
    # Save values to config.env for future use
    if [ -f "$CONFIG_ENV" ]; then
      echo "ALERT_EMAIL_FROM=\"${ALERT_EMAIL_FROM}\"" >> "$CONFIG_ENV"
      echo "ALERT_EMAIL_TO=\"${ALERT_EMAIL_TO}\"" >> "$CONFIG_ENV"
      echo "ALERT_EMAIL_SERVER=\"${ALERT_EMAIL_SERVER}\"" >> "$CONFIG_ENV"
      echo "ALERT_EMAIL_PORT=\"${ALERT_EMAIL_PORT}\"" >> "$CONFIG_ENV"
      echo "ALERT_EMAIL_USER=\"${ALERT_EMAIL_USER}\"" >> "$CONFIG_ENV"
      echo "ALERT_EMAIL_PASSWORD=\"${ALERT_EMAIL_PASSWORD}\"" >> "$CONFIG_ENV"
    fi
  else
    echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Email alert configuration missing in $CONFIG_ENV" >> "$ALERTS_LOG"
    echo "Please set ALERT_EMAIL_FROM, ALERT_EMAIL_TO, and ALERT_EMAIL_SERVER variables."
    exit 1
  fi
fi

# Set default values if not present
ALERT_EMAIL_PORT=${ALERT_EMAIL_PORT:-587}
ALERT_EMAIL_USER=${ALERT_EMAIL_USER:-$ALERT_EMAIL_FROM}
ALERT_EMAIL_PASSWORD=${ALERT_EMAIL_PASSWORD:-""}

# Prepare email content
EMAIL_CONTENT="From: AgencyStack <$ALERT_EMAIL_FROM>
To: $ALERT_EMAIL_TO
Subject: $SUBJECT
Content-Type: text/plain; charset=UTF-8

$MESSAGE

--
Sent by AgencyStack on $(hostname) at $(date)
https://stack.nerdofmouth.com
"

# Use the appropriate method to send email based on configuration
if [ -x "$(command -v msmtp)" ]; then
  # Using msmtp if available
  echo "$EMAIL_CONTENT" | msmtp --auth=on --tls=on --tls-starttls=on \
    --tls-trust-file=/etc/ssl/certs/ca-certificates.crt \
    --host="$ALERT_EMAIL_SERVER" --port="$ALERT_EMAIL_PORT" \
    --user="$ALERT_EMAIL_USER" --passwordeval="echo '$ALERT_EMAIL_PASSWORD'" \
    --from="$ALERT_EMAIL_FROM" "$ALERT_EMAIL_TO"
  
  EMAIL_STATUS=$?
elif [ -x "$(command -v curl)" ]; then
  # Using curl as a fallback
  echo "$EMAIL_CONTENT" | curl --url "smtp://${ALERT_EMAIL_SERVER}:${ALERT_EMAIL_PORT}" \
    --ssl-reqd \
    --mail-from "$ALERT_EMAIL_FROM" \
    --mail-rcpt "$ALERT_EMAIL_TO" \
    --user "${ALERT_EMAIL_USER}:${ALERT_EMAIL_PASSWORD}" \
    --upload-file -
  
  EMAIL_STATUS=$?
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] No suitable email client found. Please install msmtp or curl." >> "$ALERTS_LOG"
  exit 1
fi

# Log the result
if [ $EMAIL_STATUS -eq 0 ]; then
  echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Email alert sent successfully to $ALERT_EMAIL_TO: $SUBJECT" >> "$ALERTS_LOG"
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Failed to send email alert to $ALERT_EMAIL_TO: $SUBJECT" >> "$ALERTS_LOG"
fi

exit $EMAIL_STATUS
