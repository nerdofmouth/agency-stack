#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: stub.sh
# Path: /scripts/components/install_stub.sh
#

# Enforce containerization (prevent host contamination)

# Generic stub installer for missing AgencyStack components
COMPONENT_NAME=$(basename "$0" | sed 's/^install_//;s/\.sh$//')
LOGFILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
mkdir -p /var/log/agency_stack/components

echo "[STUB] $COMPONENT_NAME installer not yet implemented." | tee -a "$LOGFILE"
exit 0
