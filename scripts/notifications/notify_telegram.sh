#!/bin/bash
# notify_telegram.sh - Telegram notification script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sends Telegram notifications using the Telegram Bot API
# It requires TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables
#
# Usage: ./notify_telegram.sh "Message title" "Message body"
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
  echo "Usage: $0 \"Title\" \"Message body\""
  echo "Example: $0 \"Server Alert\" \"Disk space is low\""
  exit 1
fi

TITLE="$1"
MESSAGE="$2"

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Config file $CONFIG_ENV not found" >> "$ALERTS_LOG"
  exit 1
fi

# Check if required variables are set
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Telegram configuration missing in $CONFIG_ENV" >> "$ALERTS_LOG"
  echo "Please set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID variables."
  exit 1
fi

# Format message for Telegram (with markdown formatting)
FORMATTED_MESSAGE="*$TITLE*%0A%0A$MESSAGE%0A%0A_Sent from AgencyStack on $(hostname) at $(date)_"
# URL encode special characters
FORMATTED_MESSAGE=$(echo "$FORMATTED_MESSAGE" | sed 's/%/%%/g' | sed 's/ /%20/g' | sed 's/\t/%09/g' | sed 's/\n/%0A/g' | sed 's/\r/%0D/g')

# Telegram API URL
API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Send the message
if [ -x "$(command -v curl)" ]; then
  RESPONSE=$(curl -s -X POST "$API_URL" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$FORMATTED_MESSAGE" -d parse_mode="Markdown")
  TELEGRAM_STATUS=$?
elif [ -x "$(command -v wget)" ]; then
  RESPONSE=$(wget -q -O- --post-data="chat_id=${TELEGRAM_CHAT_ID}&text=${FORMATTED_MESSAGE}&parse_mode=Markdown" "$API_URL")
  TELEGRAM_STATUS=$?
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] No suitable HTTP client found. Please install curl or wget." >> "$ALERTS_LOG"
  exit 1
fi

# Check for API errors
if [ $TELEGRAM_STATUS -eq 0 ]; then
  # Check the response from Telegram
  if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Telegram alert sent successfully: $TITLE" >> "$ALERTS_LOG"
  else
    ERROR_DESC=$(echo "$RESPONSE" | grep -o '"description":"[^"]*"' | sed 's/"description":"\(.*\)"/\1/')
    echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Telegram API error: $ERROR_DESC" >> "$ALERTS_LOG"
    TELEGRAM_STATUS=1
  fi
else
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Failed to send Telegram alert: $TITLE" >> "$ALERTS_LOG"
fi

exit $TELEGRAM_STATUS
