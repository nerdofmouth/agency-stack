#!/bin/bash
# dashboard_update_cron.sh - Hourly dashboard update script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script is designed to be run via cron hourly
# It updates the dashboard data to reflect the current state of all components
# 
# Usage: ./dashboard_update_cron.sh
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Environment variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
DASHBOARD_LOG="${LOG_DIR}/dashboard.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
fi

# Log start of dashboard update
echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Starting scheduled dashboard update" >> "$DASHBOARD_LOG"

# Run dashboard update and capture output
DASHBOARD_OUTPUT=$(cd /home/revelationx/CascadeProjects/foss-server-stack && make dashboard-update 2>&1)
DASHBOARD_STATUS=$?

# Log the output
echo "$DASHBOARD_OUTPUT" >> "$DASHBOARD_LOG"

if [ $DASHBOARD_STATUS -ne 0 ]; then
  # Dashboard update failed
  echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Dashboard update failed with status $DASHBOARD_STATUS" >> "$DASHBOARD_LOG"
else
  # Dashboard update succeeded
  echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Dashboard update completed successfully" >> "$DASHBOARD_LOG"
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Scheduled dashboard update completed" >> "$DASHBOARD_LOG"
echo "----------------------------------------" >> "$DASHBOARD_LOG"

exit $DASHBOARD_STATUS
