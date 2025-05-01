#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: wordpress_module.sh
# Path: /scripts/components/install_wordpress_module.sh
#

# Enforce containerization (prevent host contamination)

# AgencyStack WordPress Module Installer

SCRIPT_NAME=$(basename "$0")
LOGFILE="/var/log/agency_stack/components/wordpress_module.log"
mkdir -p /var/log/agency_stack/components

# Forward all arguments to the main WordPress stack installer
WP_INSTALLER="$(dirname "$0")/install_wordpress.sh"

if [ ! -f "$WP_INSTALLER" ]; then
  echo "[FATAL] $SCRIPT_NAME: Main WordPress installer not found at $WP_INSTALLER" | tee -a "$LOGFILE"
  exit 1

# Log invocation
{
  echo "[INFO] $SCRIPT_NAME: Invoking main WordPress stack installer at $WP_INSTALLER with args: $@"
  date
} | tee -a "$LOGFILE"

bash "$WP_INSTALLER" "$@" 2>&1 | tee -a "$LOGFILE"
EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo "[SUCCESS] $SCRIPT_NAME: WordPress stack installed successfully." | tee -a "$LOGFILE"
  echo "[FAILURE] $SCRIPT_NAME: WordPress stack installer failed with exit code $EXIT_CODE." | tee -a "$LOGFILE"

exit $EXIT_CODE
