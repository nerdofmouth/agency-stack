#!/bin/bash
# component_sso_helper.sh - Helper script for enabling SSO on AgencyStack components
#
# This script provides standardized functions for enabling SSO on various AgencyStack components
# following the Prototype Phase Directives for SSO integration.
#
# Author: AgencyStack Team
# Date: 2025-04-11

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/log_helpers.sh"
source "${SCRIPT_DIR}/keycloak_integration.sh"

# Constants
CLIENT_REGISTRY_DIR="/opt/agency_stack/clients"
COMPONENT_REGISTRY="/opt/agency_stack/config/registry/component_registry.json"

# Function to enable SSO for a specific component
# Arguments:
#   1. component_name - Name of the component (e.g., "jitsi", "wordpress")
#   2. domain - Domain name
#   3. client_id - Keycloak client ID (defaults to component name if not provided)
#   4. redirect_uris - JSON array of redirect URIs (e.g., '["https://domain.com/*"]')
#   5. client_id - Optional client ID override (defaults to $component_name)
enable_component_sso() {
    local component_name="$1"
    local domain="$2"
    local client_name="AgencyStack ${component_name^}"
    local redirect_uris="$3"
    local client_id="${4:-$component_name}"
    local realm="${5:-agency_stack}"
    local client_id_path="${client_id// /_}"
    local component_dir="${CLIENT_REGISTRY_DIR}/${CLIENT_ID:-default}/apps/${component_name}"
    local sso_dir="${component_dir}/sso"
    
    log_info "Enabling SSO for component: ${component_name}"
    
    # Create SSO directory for the component if it doesn't exist
    mkdir -p "${sso_dir}"
    
    # Check if Keycloak is available
    if ! keycloak_is_available "${domain}"; then
        log_warning "Keycloak is not available at https://${domain}/auth"
        log_warning "SSO integration will be configured but may not work until Keycloak becomes available"
        echo "pending" > "${sso_dir}/status"
        return 0
    fi
    
    # Verify realm exists
    if ! keycloak_realm_exists "${domain}" "${realm}"; then
        log_info "Creating realm '${realm}' for domain ${domain}"
        if ! keycloak_create_realm "${domain}" "${realm}" "AgencyStack ${realm^} Realm"; then
            log_error "Failed to create realm '${realm}' for domain ${domain}"
            echo "failed" > "${sso_dir}/status"
            return 1
        fi
    fi
    
    # Register the client
    log_info "Registering client '${client_id}' for component '${component_name}'"
    local client_secret=$(keycloak_register_client "${domain}" "${realm}" "${client_id}" "${client_name}" "${redirect_uris}")
    
    if [ $? -ne 0 ]; then
        log_error "Failed to register client for component '${component_name}'"
        echo "failed" > "${sso_dir}/status"
        return 1
    fi
    
    # Store credentials
    log_info "Storing SSO credentials for component '${component_name}'"
    cat > "${sso_dir}/credentials" <<EOF
KEYCLOAK_REALM=${realm}
KEYCLOAK_CLIENT_ID=${client_id}
KEYCLOAK_CLIENT_SECRET=${client_secret}
KEYCLOAK_URL=https://${domain}/auth
KEYCLOAK_ISSUER=https://${domain}/auth/realms/${realm}
EOF
    
    # Mark SSO as configured
    echo "configured" > "${sso_dir}/status"
    touch "${sso_dir}/.sso_configured"
    
    # Update component registry
    update_component_registry "${component_name}"
    
    log_success "Successfully enabled SSO for component: ${component_name}"
    return 0
}

# Function to update component registry with SSO status
update_component_registry() {
    local component_name="$1"
    
    # Check if registry file exists
    if [ ! -f "${COMPONENT_REGISTRY}" ]; then
        log_warning "Component registry file not found: ${COMPONENT_REGISTRY}"
        return 1
    }
    
    # Check if jq is installed
    if ! command -v jq &>/dev/null; then
        log_warning "jq is required for registry updates"
        apt-get update -qq && apt-get install -y jq
        
        if ! command -v jq &>/dev/null; then
            log_error "Failed to install jq, registry cannot be updated"
            return 1
        fi
    fi
    
    log_info "Updating component registry for ${component_name}"
    
    # Determine component category
    local categories=($(jq -r '.components | keys[]' "${COMPONENT_REGISTRY}"))
    local component_category=""
    local component_path=""
    
    for category in "${categories[@]}"; do
        if jq -e ".components.${category}.${component_name}" "${COMPONENT_REGISTRY}" &>/dev/null; then
            component_category="${category}"
            component_path=".components.${category}.${component_name}"
            break
        fi
    done
    
    if [ -z "${component_category}" ]; then
        log_warning "Component '${component_name}' not found in registry"
        return 1
    fi
    
    # Update component registry
    local temp_file=$(mktemp)
    
    jq "${component_path}.integration_status.sso = true | ${component_path}.integration_status.sso_configured = true" \
       "${COMPONENT_REGISTRY}" > "${temp_file}"
    
    # Only replace if jq command was successful
    if [ $? -eq 0 ]; then
        mv "${temp_file}" "${COMPONENT_REGISTRY}"
        log_success "Updated component registry for ${component_name} with SSO status"
    else
        rm -f "${temp_file}"
        log_error "Failed to update component registry for ${component_name}"
        return 1
    fi
    
    return 0
}

# Function to get SSO status for a component
get_component_sso_status() {
    local component_name="$1"
    local component_dir="${CLIENT_REGISTRY_DIR}/${CLIENT_ID:-default}/apps/${component_name}"
    local sso_dir="${component_dir}/sso"
    
    if [ ! -d "${sso_dir}" ]; then
        echo "not_configured"
        return 1
    fi
    
    if [ -f "${sso_dir}/status" ]; then
        cat "${sso_dir}/status"
    elif [ -f "${sso_dir}/.sso_configured" ]; then
        echo "configured"
    else
        echo "unknown"
    fi
    
    return 0
}

# Define redirect URIs for standard components
get_component_redirect_uris() {
    local component_name="$1"
    local domain="$2"
    
    case "${component_name}" in
        jitsi)
            echo '["https://'"${domain}"'/*", "https://meet.'"${domain}"'/*"]'
            ;;
        wordpress)
            echo '["https://'"${domain}"'/*", "https://blog.'"${domain}"'/*", "https://cms.'"${domain}"'/*"]'
            ;;
        ghost)
            echo '["https://'"${domain}"'/*", "https://blog.'"${domain}"'/*", "https://news.'"${domain}"'/*"]'
            ;;
        seafile)
            echo '["https://'"${domain}"'/*", "https://files.'"${domain}"'/*", "https://seafile.'"${domain}"'/*"]'
            ;;
        peertube)
            echo '["https://'"${domain}"'/*", "https://video.'"${domain}"'/*", "https://tube.'"${domain}"'/*"]'
            ;;
        erpnext)
            echo '["https://'"${domain}"'/*", "https://erp.'"${domain}"'/*"]'
            ;;
        focalboard)
            echo '["https://'"${domain}"'/*", "https://board.'"${domain}"'/*"]'
            ;;
        documenso)
            echo '["https://'"${domain}"'/*", "https://sign.'"${domain}"'/*"]'
            ;;
        killbill)
            echo '["https://'"${domain}"'/*", "https://billing.'"${domain}"'/*"]'
            ;;
        calcom)
            echo '["https://'"${domain}"'/*", "https://calendar.'"${domain}"'/*", "https://cal.'"${domain}"'/*"]'
            ;;
        mailu)
            echo '["https://'"${domain}"'/*", "https://mail.'"${domain}"'/*"]'
            ;;
        chatwoot)
            echo '["https://'"${domain}"'/*", "https://chat.'"${domain}"'/*", "https://support.'"${domain}"'/*"]'
            ;;
        posthog)
            echo '["https://'"${domain}"'/*", "https://analytics.'"${domain}"'/*"]'
            ;;
        matomo)
            echo '["https://'"${domain}"'/*", "https://analytics.'"${domain}"'/*"]'
            ;;
        uptime-kuma)
            echo '["https://'"${domain}"'/*", "https://status.'"${domain}"'/*"]'
            ;;
        *)
            # Default pattern with component name as subdomain
            echo '["https://'"${domain}"'/*", "https://'"${component_name}.${domain}"'/*"]'
            ;;
    esac
}

# Export functions
export -f enable_component_sso
export -f update_component_registry
export -f get_component_sso_status
export -f get_component_redirect_uris
