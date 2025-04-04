#!/bin/bash
# wrapper.sh - Wrapper for AgencyStack Integration System
# https://stack.nerdofmouth.com

# Get the integration type from arguments
INTEGRATION_TYPE="${1:-all}"
AUTO_MODE="${2:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the appropriate integration script
case "$INTEGRATION_TYPE" in
  "sso")
    if [ "$AUTO_MODE" = "true" ]; then
      bash "${SCRIPT_DIR}/integrate_sso.sh" --auto
    else
      bash "${SCRIPT_DIR}/integrate_sso.sh"
    fi
    ;;
  "email")
    if [ "$AUTO_MODE" = "true" ]; then
      bash "${SCRIPT_DIR}/integrate_email.sh" --auto
    else
      bash "${SCRIPT_DIR}/integrate_email.sh"
    fi
    ;;
  "monitoring")
    if [ "$AUTO_MODE" = "true" ]; then
      bash "${SCRIPT_DIR}/integrate_monitoring.sh" --auto
    else
      bash "${SCRIPT_DIR}/integrate_monitoring.sh"
    fi
    ;;
  "data-bridge")
    if [ "$AUTO_MODE" = "true" ]; then
      bash "${SCRIPT_DIR}/integrate_data_bridge.sh" --auto
    else
      bash "${SCRIPT_DIR}/integrate_data_bridge.sh"
    fi
    ;;
  "all")
    echo "Running all integrations..."
    
    # Run each integration in sequence
    if [ "$AUTO_MODE" = "true" ]; then
      bash "${SCRIPT_DIR}/integrate_sso.sh" --auto
      bash "${SCRIPT_DIR}/integrate_email.sh" --auto
      bash "${SCRIPT_DIR}/integrate_monitoring.sh" --auto
      bash "${SCRIPT_DIR}/integrate_data_bridge.sh" --auto
    else
      bash "${SCRIPT_DIR}/integrate_sso.sh"
      bash "${SCRIPT_DIR}/integrate_email.sh"
      bash "${SCRIPT_DIR}/integrate_monitoring.sh"
      bash "${SCRIPT_DIR}/integrate_data_bridge.sh"
    fi
    ;;
  *)
    echo "Unknown integration type: $INTEGRATION_TYPE"
    echo "Valid types: sso, email, monitoring, data-bridge, all"
    exit 1
    ;;
esac

exit 0
