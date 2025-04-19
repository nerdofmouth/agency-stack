#!/bin/bash
# cleanup_install_state.sh: Remove stale AgencyStack install state and failed/pending logs.

STATE_FILES=(
  "/opt/agency_stack/installed_components.txt"
  "/opt/agency_stack/install_state.json"
  "/opt/agency_stack/install_state.lock"
)

for file in "${STATE_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "[CLEANUP] Removing $file"
    rm -f "$file"
  fi
done

# Optionally clean up logs for failed components
find /var/log/agency_stack/ -type f -name '*failed*' -exec rm -f {} +

# Remove any .pending or .lock files in /opt/agency_stack
find /opt/agency_stack/ -type f \( -name '*.pending' -o -name '*.lock' \) -exec rm -f {} +

echo "[INFO] AgencyStack install state cleaned up."
