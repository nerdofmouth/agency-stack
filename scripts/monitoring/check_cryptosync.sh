#!/bin/bash
# check_cryptosync.sh - Health check for Cryptosync encrypted storage
# Part of the AgencyStack monitoring system
#
# Checks vault mount status and rclone remote connectivity
# Updates dashboard_data.json with current status
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Variables
CONFIG_DIR="/opt/agency_stack"
DASHBOARD_DATA="${CONFIG_DIR}/config/dashboard_data.json"
DEFAULT_CLIENT_ID="default"
CLIENT_ID="${1:-$DEFAULT_CLIENT_ID}"
CONFIG_NAME="${2:-default}"

# Function to update dashboard data
update_dashboard() {
  local mounted="$1"
  local health="$2"
  local remote_dest="$3"
  local last_sync="$4"
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for dashboard updates"
    exit 1
  fi
  
  # Create components section if it doesn't exist
  if [ ! -f "$DASHBOARD_DATA" ]; then
    mkdir -p "$(dirname "$DASHBOARD_DATA")"
    echo '{"components":{}}' > "$DASHBOARD_DATA"
  fi
  
  # Create security_storage section if needed
  if ! jq -e '.components.security_storage' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.security_storage = {}' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create cryptosync entry if needed
  if ! jq -e '.components.security_storage.cryptosync' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.security_storage.cryptosync = {
      "name": "Cryptosync",
      "description": "Encrypted local vaults + remote cloud sync",
      "version": "1.0.0",
      "icon": "lock",
      "status": {
        "mounted": false,
        "last_sync": null,
        "remote_destination": "",
        "health": "unknown"
      },
      "client_data": {}
    }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create client_data entry if needed
  if ! jq -e ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\"" "$DASHBOARD_DATA" &> /dev/null; then
    jq ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\" = {
      \"mounted\": false,
      \"last_sync\": null,
      \"remote_destination\": \"\",
      \"health\": \"unknown\"
    }" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update status data
  jq ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\".mounted = ${mounted}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\".health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\".remote_destination = \"${remote_dest}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  # Update last_sync if provided
  if [ -n "$last_sync" ]; then
    jq ".components.security_storage.cryptosync.client_data.\"${CLIENT_ID}\".last_sync = \"${last_sync}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update overall component status based on client data
  # Use the latest client's status for the main component display
  jq ".components.security_storage.cryptosync.status.mounted = ${mounted}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.security_storage.cryptosync.status.health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.security_storage.cryptosync.status.remote_destination = \"${remote_dest}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$last_sync" ]; then
    jq ".components.security_storage.cryptosync.status.last_sync = \"${last_sync}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
}

# Check if the configuration exists
CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
CONFIG_FILE="${CLIENT_DIR}/cryptosync/config/cryptosync.${CONFIG_NAME}.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  update_dashboard "false" "error" "not configured" ""
  echo "Error: Configuration not found: $CONFIG_FILE"
  exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Check if mount exists
if [ -z "$MOUNT_DIR" ]; then
  MOUNT_DIR="${CLIENT_DIR}/vault/decrypted"
fi

# Check if encrypted directory exists
if [ ! -d "$ENCRYPTED_DIR" ] && [ -z "$ENCRYPTED_DIR" ]; then
  ENCRYPTED_DIR="${CLIENT_DIR}/vault/encrypted"
  if [ ! -d "$ENCRYPTED_DIR" ]; then
    update_dashboard "false" "error" "vault missing" ""
    echo "Error: Encrypted directory not found: $ENCRYPTED_DIR"
    exit 1
  fi
fi

# Check mount status
MOUNTED="false"
if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
  MOUNTED="true"
  MOUNT_HEALTH="healthy"
else
  MOUNT_HEALTH="unmounted"
fi

# Check rclone configuration
RCLONE_CONFIG="${CLIENT_DIR}/rclone/rclone.conf"
REMOTE_STATUS="not configured"

if [ -f "$RCLONE_CONFIG" ]; then
  # Check if remote name exists in config
  if grep -q "^\[$REMOTE_NAME\]$" "$RCLONE_CONFIG" 2>/dev/null; then
    # Extract remote type and path for display
    REMOTE_TYPE=$(grep -A 1 "^\[$REMOTE_NAME\]$" "$RCLONE_CONFIG" | grep "type" | cut -d= -f2 | tr -d ' ')
    REMOTE_DEST="${REMOTE_NAME} (${REMOTE_TYPE})"
    
    # Try to check remote connectivity (if mounted)
    if [ "$MOUNTED" = "true" ]; then
      if rclone lsd --config "$RCLONE_CONFIG" "${REMOTE_NAME}:" &>/dev/null; then
        REMOTE_STATUS="connected"
      else
        REMOTE_STATUS="disconnected"
      fi
    else
      REMOTE_STATUS="configured"
    fi
  else
    REMOTE_DEST="none"
    REMOTE_STATUS="not configured"
  fi
else
  REMOTE_DEST="none"
  REMOTE_STATUS="not configured"
fi

# Check last sync time
SYNC_LOG="${CLIENT_DIR}/cryptosync/logs/sync.log"
LAST_SYNC=""

if [ -f "$SYNC_LOG" ]; then
  LAST_SYNC=$(grep "Sync completed" "$SYNC_LOG" | tail -1 | awk '{print $1 " " $2}')
fi

# Determine overall health
if [ "$MOUNTED" = "true" ] && [ "$REMOTE_STATUS" = "connected" ]; then
  HEALTH="healthy"
elif [ "$MOUNTED" = "true" ] && [ "$REMOTE_STATUS" = "configured" ]; then
  HEALTH="warning"
elif [ "$MOUNTED" = "true" ] && [ "$REMOTE_STATUS" = "not configured" ]; then
  HEALTH="warning"
elif [ "$MOUNTED" = "false" ] && [ "$REMOTE_STATUS" = "configured" ]; then
  HEALTH="unmounted"
else
  HEALTH="needs setup"
fi

# Update dashboard
update_dashboard "$MOUNTED" "$HEALTH" "$REMOTE_DEST" "$LAST_SYNC"

# Output status 
echo "Cryptosync status for client '${CLIENT_ID}':"
echo "- Mounted: ${MOUNTED}"
echo "- Mount point: ${MOUNT_DIR}"
echo "- Remote: ${REMOTE_DEST}"
echo "- Remote status: ${REMOTE_STATUS}"
echo "- Last sync: ${LAST_SYNC:-Never}"
echo "- Health: ${HEALTH}"

exit 0
