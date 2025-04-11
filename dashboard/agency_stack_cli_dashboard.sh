#!/bin/bash
# AgencyStack CLI Dashboard
# Displays real-time status of AgencyStack components installed via make demo-core

# Colors and formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
RESET="\033[0m"

# Symbols for status and features
RUNNING_SYMBOL="✅"
STOPPED_SYMBOL="⚠️"
ERROR_SYMBOL="❌"
NOT_INSTALLED_SYMBOL="⬜"
SSO_SYMBOL="🔑"
TLS_SYMBOL="🔒"
MULTI_TENANT_SYMBOL="👥"
LOGS_SYMBOL="📋"
DASHBOARD_SYMBOL="🖥️"

# Default paths
REGISTRY_PATH="/root/_repos/agency-stack/config/registry/component_registry.json"
LOGS_DIR="/var/log/agency_stack/components"
INSTALL_DIR="/opt/agency_stack"

# Display header
display_header() {
    clear
    echo -e "${MAGENTA}${BOLD}============================================================${RESET}"
    echo -e "${MAGENTA}${BOLD}          AgencyStack Component Status Dashboard           ${RESET}"
    echo -e "${MAGENTA}${BOLD}============================================================${RESET}"
    echo -e "${BLUE}Hostname:${RESET} $(hostname) | ${BLUE}Last Updated:${RESET} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Display summary stats
display_summary() {
    local total=$(jq '.components | .[] | length' "$REGISTRY_PATH" | wc -l)
    local installed=0
    local running=0
    local error=0
    
    # Count installed and running components
    while IFS= read -r component_id; do
        if [[ -f "${INSTALL_DIR}/${component_id}/.installed_ok" ]]; then
            ((installed++))
            
            # Check if component is running
            if make ${component_id}-status &>/dev/null; then
                ((running++))
            else
                ((error++))
            fi
        fi
    done < <(find_components)
    
    echo -e "${BOLD}Summary:${RESET}"
    echo -e "  ${BLUE}Total Components:${RESET} $total"
    echo -e "  ${GREEN}Installed:${RESET} $installed"
    echo -e "  ${GREEN}Running:${RESET} $running"
    echo -e "  ${RED}Error/Stopped:${RESET} $((installed - running))"
    echo ""
}

# Function to extract all component IDs from registry
find_components() {
    jq -r '.components | to_entries[] | .value | to_entries[] | .key' "$REGISTRY_PATH"
}

# Check status of a component
check_component_status() {
    local component_id="$1"
    
    # Check if installed
    if [[ ! -f "${INSTALL_DIR}/${component_id}/.installed_ok" ]]; then
        echo "not_installed"
        return
    fi
    
    # Check if running properly
    if make ${component_id}-status &>/dev/null; then
        # Further check the output for specific indication of "running"
        if make ${component_id}-status 2>&1 | grep -q -i 'running\|active\|healthy'; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "error"
    fi
}

# Get component name from ID
get_component_name() {
    local component_id="$1"
    jq -r --arg id "$component_id" '.components[][] | select(.name != null) | select(has($id)) | .[$id].name' "$REGISTRY_PATH" 2>/dev/null || echo "$component_id"
}

# Get component category from ID
get_component_category() {
    local component_id="$1"
    
    # This is a simplistic approach - in a real implementation, you'd parse the JSON properly
    for category in $(jq -r '.components | keys[]' "$REGISTRY_PATH"); do
        if jq -e --arg cat "$category" --arg id "$component_id" '.components[$cat] | has($id)' "$REGISTRY_PATH" >/dev/null; then
            echo "$category"
            return
        fi
    done
    
    echo "unknown"
}

# Check if component has a specific feature flag
has_feature() {
    local component_id="$1"
    local feature="$2"
    local category=$(get_component_category "$component_id")
    
    jq -e --arg cat "$category" --arg id "$component_id" --arg feature "$feature" \
       '.components[$cat][$id].integration_status[$feature] == true' "$REGISTRY_PATH" >/dev/null
}

# Display feature flags for a component
display_feature_flags() {
    local component_id="$1"
    local flags=""
    
    if has_feature "$component_id" "sso"; then
        flags+=" $SSO_SYMBOL"
    fi
    
    if has_feature "$component_id" "traefik_tls"; then
        flags+=" $TLS_SYMBOL"
    fi
    
    if has_feature "$component_id" "multi_tenant"; then
        flags+=" $MULTI_TENANT_SYMBOL"
    fi
    
    if has_feature "$component_id" "logs"; then
        flags+=" $LOGS_SYMBOL"
    fi
    
    if has_feature "$component_id" "dashboard"; then
        flags+=" $DASHBOARD_SYMBOL"
    fi
    
    echo "$flags"
}

# Display a single component
display_component() {
    local component_id="$1"
    local status=$(check_component_status "$component_id")
    local name=$(get_component_name "$component_id")
    local category=$(get_component_category "$component_id")
    local feature_flags=$(display_feature_flags "$component_id")
    local status_symbol
    local status_color
    
    case "$status" in
        "running")
            status_symbol="$RUNNING_SYMBOL"
            status_color="$GREEN"
            ;;
        "stopped")
            status_symbol="$STOPPED_SYMBOL"
            status_color="$YELLOW"
            ;;
        "error")
            status_symbol="$ERROR_SYMBOL"
            status_color="$RED"
            ;;
        "not_installed")
            status_symbol="$NOT_INSTALLED_SYMBOL"
            status_color="$WHITE"
            ;;
    esac
    
    printf "${BOLD}%-20s${RESET} ${status_color}%-10s${RESET} ${CYAN}%-20s${RESET} %s\n" \
           "$name" "$status" "$category" "$feature_flags"
}

# Display components by category
display_components_by_category() {
    local current_category=""
    
    echo -e "${BOLD}Component Status:${RESET}"
    echo -e "${BOLD}$(printf '%-20s %-10s %-20s %s\n' 'Name' 'Status' 'Category' 'Features')${RESET}"
    echo -e "--------------------------------------------------------------------------------"
    
    for category in $(jq -r '.components | keys[]' "$REGISTRY_PATH" | sort); do
        local pretty_category=$(echo "$category" | sed 's/\b\(.\)/\u\1/g' | sed 's/_/ /g')
        echo -e "\n${YELLOW}${BOLD}$pretty_category:${RESET}"
        
        while IFS= read -r component_id; do
            if [[ $(get_component_category "$component_id") == "$category" ]]; then
                display_component "$component_id"
            fi
        done < <(find_components | sort)
    done
}

# Display help/legend
display_legend() {
    echo -e "\n${BOLD}Legend:${RESET}"
    echo -e "  $RUNNING_SYMBOL Running"
    echo -e "  $STOPPED_SYMBOL Stopped"
    echo -e "  $ERROR_SYMBOL Error"
    echo -e "  $NOT_INSTALLED_SYMBOL Not Installed"
    echo -e ""
    echo -e "  $SSO_SYMBOL SSO-Enabled"
    echo -e "  $TLS_SYMBOL TLS-Enabled"
    echo -e "  $MULTI_TENANT_SYMBOL Multi-Tenant Capable"
    echo -e "  $LOGS_SYMBOL Logs Available"
    echo -e "  $DASHBOARD_SYMBOL UI Dashboard Available"
    echo -e ""
    echo -e "${BOLD}Commands:${RESET}"
    echo -e "  make <component>-status    Check component status"
    echo -e "  make <component>-logs      View component logs"
    echo -e "  make <component>-restart   Restart component"
    echo -e "  make dashboard-refresh     Refresh this dashboard"
}

# Check if registry file exists
check_requirements() {
    if [[ ! -f "$REGISTRY_PATH" ]]; then
        echo -e "${RED}Error: Component registry not found at $REGISTRY_PATH${RESET}"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${RESET}"
        echo -e "Please install with: ${BOLD}apt-get install jq${RESET}"
        exit 1
    fi
}

# Main function
main() {
    check_requirements
    display_header
    display_summary
    display_components_by_category
    display_legend
    
    echo -e "\n${MAGENTA}${BOLD}============================================================${RESET}"
    echo -e "${CYAN}Press Ctrl+C to exit or wait for auto-refresh (every 30 seconds)${RESET}"
}

# Set up auto-refresh (if running in interactive mode)
if [[ -t 0 ]]; then
    while true; do
        main
        sleep 30
    done
else
    main
fi
