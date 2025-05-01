#!/bin/bash
# AgencyStack Agent Linter - Enforces Charter v1.0.3 principles
set -euo pipefail

SCRIPTS_DIR="${1:-scripts/components}"
echo "Scanning ${SCRIPTS_DIR} for AgencyStack Charter compliance..."
ERRORS=0

# Check for sourcing of common.sh
for script in "${SCRIPTS_DIR}"/*.sh; do
  if [ -f "${script}" ]; then
    if ! grep -q "source.*utils/common.sh" "${script}"; then
      echo "ERROR: ${script} does not source common.sh"
      ERRORS=$((${ERRORS}+1))
    fi

    # Check for exit_with_warning_if_host call
    if ! grep -q "exit_with_warning_if_host" "${script}"; then
      echo "ERROR: ${script} does not call exit_with_warning_if_host"
      ERRORS=$((${ERRORS}+1))
    fi

    # Check for reimplementation of utility functions
    for func in "log_info" "log_error" "log_warning" "log_success" "ensure_directory_exists" "check_prerequisites"; do
      if grep -q "^${func}()" "${script}"; then
        echo "ERROR: ${script} reimplements ${func} instead of using common.sh"
        ERRORS=$((${ERRORS}+1))
      fi
    done
  fi
done

if [ ${ERRORS} -gt 0 ]; then
  echo "Found ${ERRORS} Charter compliance issues!"
  exit 1
else
  echo "All scripts pass Charter compliance checks ✓"
fi
