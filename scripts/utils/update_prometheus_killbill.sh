#!/bin/bash
# update_prometheus_killbill.sh - Add KillBill metrics to Prometheus
# Part of AgencyStack Monitoring Suite
#
# Ensures proper monitoring integration for KillBill billing platform
# Author: AgencyStack Team
# Date: 2025-04-14

set -eo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default values
CLIENT_ID="default"
VERBOSE=false
FORCE=false

# Show usage information
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Updates Prometheus configuration to include KillBill metrics."
    echo ""
    echo "Options:"
    echo "  --client-id CLIENT_ID   Client ID for multi-tenant setup (default: default)"
    echo "  --force                 Force update even if already configured"
    echo "  --verbose               Enable verbose output"
    echo "  --help                  Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --client-id tenant1 --force"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

log_header "Updating Prometheus Configuration for KillBill Metrics"
log_info "Client ID: $CLIENT_ID"

# Check if Prometheus is installed
PROMETHEUS_CONFIG="/opt/agency_stack/prometheus/prometheus.yml"
if [ ! -f "$PROMETHEUS_CONFIG" ]; then
    log_error "Prometheus configuration not found at $PROMETHEUS_CONFIG"
    exit 1
fi

# Check if KillBill is installed
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/killbill"
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "KillBill is not installed for client $CLIENT_ID"
    exit 1
fi

# Create backup of Prometheus configuration
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${PROMETHEUS_CONFIG}.${TIMESTAMP}.bak"
cp "$PROMETHEUS_CONFIG" "$BACKUP_FILE"
log_info "Created backup of Prometheus configuration: $BACKUP_FILE"

# Check if KillBill metrics are already configured
if grep -q "job_name: 'killbill'" "$PROMETHEUS_CONFIG" && [ "$FORCE" != "true" ]; then
    log_warning "KillBill metrics are already configured in Prometheus"
    log_info "Use --force to update the configuration anyway"
    exit 0
fi

# Add KillBill metrics to Prometheus configuration
TEMP_CONFIG=$(mktemp)
cat "$PROMETHEUS_CONFIG" > "$TEMP_CONFIG"

# Find the scrape_configs section
SCRAPE_CONFIGS_LINE=$(grep -n "scrape_configs:" "$TEMP_CONFIG" | cut -d: -f1)
if [ -z "$SCRAPE_CONFIGS_LINE" ]; then
    log_error "Could not find scrape_configs section in Prometheus configuration"
    rm "$TEMP_CONFIG"
    exit 1
fi

# Prepare the KillBill job configuration
KILLBILL_JOB="  - job_name: 'killbill'
    scrape_interval: 15s
    metrics_path: /
    static_configs:
      - targets: ['localhost:9092']
        labels:
          instance: 'killbill'
          client_id: '$CLIENT_ID'"

# Insert the KillBill job after the scrape_configs line
sed -i "$((SCRAPE_CONFIGS_LINE+1))i\\
$KILLBILL_JOB" "$TEMP_CONFIG"

# Check if the update was successful
if ! grep -q "job_name: 'killbill'" "$TEMP_CONFIG"; then
    log_error "Failed to update Prometheus configuration"
    rm "$TEMP_CONFIG"
    exit 1
fi

# Apply the updated configuration
mv "$TEMP_CONFIG" "$PROMETHEUS_CONFIG"
log_success "Updated Prometheus configuration with KillBill metrics"

# Reload Prometheus
if docker ps | grep -q prometheus; then
    log_info "Reloading Prometheus configuration"
    curl -s -X POST http://localhost:9090/-/reload > /dev/null
    log_success "Prometheus configuration reloaded"
else
    log_warning "Prometheus container not found. You may need to restart Prometheus manually."
fi

# Update component registry
COMPONENT_REGISTRY="/opt/agency_stack/config/registry/component_registry.json"
if [ -f "$COMPONENT_REGISTRY" ]; then
    log_info "Updating component registry to set monitoring flag for KillBill"
    
    # Use temporary file for jq processing
    TEMP_REGISTRY=$(mktemp)
    jq '.business_applications.killbill.integration_status.monitoring = true' "$COMPONENT_REGISTRY" > "$TEMP_REGISTRY"
    
    if [ $? -eq 0 ]; then
        mv "$TEMP_REGISTRY" "$COMPONENT_REGISTRY"
        log_success "Component registry updated successfully"
    else
        log_error "Failed to update component registry"
        rm "$TEMP_REGISTRY"
    fi
else
    log_warning "Component registry not found at $COMPONENT_REGISTRY"
fi

log_success "KillBill metrics integration completed successfully"
exit 0
