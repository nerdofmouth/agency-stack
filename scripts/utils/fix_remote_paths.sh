#!/bin/bash
# fix_remote_paths.sh - Fix script paths according to AgencyStack Alpha Phase Directory conventions
#
# This utility script ensures that all component scripts on a remote VM can properly find their dependencies
# following the AgencyStack repository integrity policy and alpha phase directory conventions.

set -e

# Source common utilities if available
SCRIPT_DIR="/opt/agency_stack/scripts"
UTILS_DIR="${SCRIPT_DIR}/utils"
COMPONENTS_DIR="${SCRIPT_DIR}/components"
DASHBOARD_DIR="${SCRIPT_DIR}/dashboard"

# Create required directories
mkdir -p /opt/agency_stack/logs/components /opt/agency_stack/config
mkdir -p /var/log/agency_stack/components

# Ensure common.sh is available to all scripts
find "${SCRIPT_DIR}" -type f -name "*.sh" -exec chmod +x {} \;

# Create an environment file for the scripts
cat > /opt/agency_stack/scripts/env.sh << EOF
#!/bin/bash
# Environment for AgencyStack scripts
export SCRIPT_DIR="/opt/agency_stack/scripts"
export UTILS_DIR="/opt/agency_stack/scripts/utils"
export COMPONENTS_DIR="/opt/agency_stack/scripts/components"
export DASHBOARD_DIR="/opt/agency_stack/scripts/dashboard"
export CONFIG_DIR="/opt/agency_stack/config"
export LOGS_DIR="/opt/agency_stack/logs"
export COMPONENT_LOGS_DIR="/var/log/agency_stack/components"
EOF

chmod +x /opt/agency_stack/scripts/env.sh

echo 'Path fixes applied for AgencyStack Alpha Phase Directory conventions'
