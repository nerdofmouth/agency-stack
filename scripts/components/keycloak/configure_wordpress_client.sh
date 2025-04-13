#!/bin/bash
# WordPress SSO integration with Keycloak
# This script configures a WordPress instance to use Keycloak for SSO

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/common.sh"

# Default values
CLIENT_ID="default"
DOMAIN=""
ADMIN_EMAIL=""
VERBOSE=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
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
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$DOMAIN" ]]; then
    log_error "Domain must be specified with --domain"
    exit 1
fi

# Set up variables
WP_DIR="/opt/agency_stack/wordpress"
if [[ -n "$CLIENT_ID" && "$CLIENT_ID" != "default" ]]; then
    WP_DIR="/opt/agency_stack/clients/${CLIENT_ID}/wordpress"
fi

KEYCLOAK_DIR="/opt/agency_stack/keycloak"
if [[ -n "$CLIENT_ID" && "$CLIENT_ID" != "default" ]]; then
    KEYCLOAK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/keycloak"
fi

KEYCLOAK_DOMAIN="auth.${DOMAIN}"
KEYCLOAK_REALM="agency-stack"
WP_SITE_URL="https://${DOMAIN}"
OAUTH_PLUGIN_DIR="${WP_DIR}/${DOMAIN}/html/wp-content/plugins/oauth2-provider"

log_info "Configuring WordPress SSO integration with Keycloak"
log_info "Domain: ${DOMAIN}"
log_info "Keycloak Domain: ${KEYCLOAK_DOMAIN}"
log_info "WordPress Site URL: ${WP_SITE_URL}"

# Check if WordPress is installed
if [[ ! -d "${WP_DIR}/${DOMAIN}" ]]; then
    log_error "WordPress directory not found at ${WP_DIR}/${DOMAIN}"
    log_error "Please install WordPress first with: make wordpress DOMAIN=${DOMAIN}"
    exit 1
fi

# Check if Keycloak is installed
if [[ ! -d "${KEYCLOAK_DIR}" ]]; then
    log_error "Keycloak directory not found at ${KEYCLOAK_DIR}"
    log_error "Please install Keycloak first with: make keycloak DOMAIN=${DOMAIN}"
    exit 1
fi

# Create WordPress OAuth client in Keycloak
log_info "Creating WordPress OAuth client in Keycloak"

# Get admin token
log_info "Getting Keycloak admin token"
ADMIN_TOKEN=$(curl -s -X POST \
    "https://${KEYCLOAK_DOMAIN}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r .access_token)

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
    log_error "Failed to get Keycloak admin token"
    exit 1
fi

log_info "Checking if WordPress client already exists"
CLIENT_ID_UUID=$(curl -s -X GET \
    "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=wordpress" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

if [[ -n "$CLIENT_ID_UUID" && "$CLIENT_ID_UUID" != "null" ]]; then
    log_info "WordPress client already exists with ID: ${CLIENT_ID_UUID}"
    # Update existing client if forced
    if [[ "$FORCE" == "true" ]]; then
        log_info "Updating existing WordPress client"
        curl -s -X PUT \
            "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_UUID}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "clientId": "wordpress",
                "name": "WordPress",
                "description": "WordPress authentication client",
                "rootUrl": "'${WP_SITE_URL}'",
                "adminUrl": "'${WP_SITE_URL}'/wp-admin",
                "baseUrl": "'${WP_SITE_URL}'",
                "redirectUris": ["'${WP_SITE_URL}'/wp-login.php"],
                "webOrigins": ["'${WP_SITE_URL}'"],
                "publicClient": false,
                "protocol": "openid-connect",
                "standardFlowEnabled": true,
                "implicitFlowEnabled": false,
                "directAccessGrantsEnabled": true,
                "serviceAccountsEnabled": false,
                "authorizationServicesEnabled": false,
                "fullScopeAllowed": true
            }'
    fi
else
    log_info "Creating new WordPress client"
    # Create new client
    curl -s -X POST \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "wordpress",
            "name": "WordPress",
            "description": "WordPress authentication client",
            "rootUrl": "'${WP_SITE_URL}'",
            "adminUrl": "'${WP_SITE_URL}'/wp-admin",
            "baseUrl": "'${WP_SITE_URL}'",
            "redirectUris": ["'${WP_SITE_URL}'/wp-login.php"],
            "webOrigins": ["'${WP_SITE_URL}'"],
            "publicClient": false,
            "protocol": "openid-connect",
            "standardFlowEnabled": true,
            "implicitFlowEnabled": false,
            "directAccessGrantsEnabled": true,
            "serviceAccountsEnabled": false,
            "authorizationServicesEnabled": false,
            "fullScopeAllowed": true
        }'

    # Get the client UUID
    CLIENT_ID_UUID=$(curl -s -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=wordpress" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
fi

# Generate client secret if it doesn't exist
log_info "Getting client secret"
CLIENT_SECRET=$(curl -s -X GET \
    "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_UUID}/client-secret" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

if [[ -z "$CLIENT_SECRET" || "$CLIENT_SECRET" == "null" ]]; then
    log_info "Generating new client secret"
    curl -s -X POST \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_UUID}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}"
    
    CLIENT_SECRET=$(curl -s -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_UUID}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')
fi

log_info "Client secret: ${CLIENT_SECRET}"

# Install and configure OAuth plugin in WordPress
log_info "Installing and configuring OAuth plugin in WordPress"

# Check if WordPress container is running
WP_CONTAINER="wordpress"
if [[ "$CLIENT_ID" != "default" ]]; then
    WP_CONTAINER="${CLIENT_ID}_wordpress"
fi

if ! docker ps --format '{{.Names}}' | grep -q "$WP_CONTAINER"; then
    log_error "WordPress container not running"
    log_error "Please start WordPress with: make wordpress-restart"
    exit 1
fi

# Install the OpenID Connect plugin
log_info "Installing and activating the OpenID Connect plugin"
docker exec -i "$WP_CONTAINER" wp plugin install miniorange-openid-connect-client --activate

# Configure the plugin
log_info "Configuring the OpenID Connect plugin"
PLUGIN_CONFIG="
{
    \"openid_url\": \"https://${KEYCLOAK_DOMAIN}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration\",
    \"client_id\": \"wordpress\",
    \"client_secret\": \"${CLIENT_SECRET}\",
    \"redirect_uri\": \"${WP_SITE_URL}/wp-login.php\",
    \"scope\": \"openid email profile\"
}
"

# Create the plugin configuration directory
docker exec -i "$WP_CONTAINER" mkdir -p /var/www/html/wp-content/plugins/miniorange-openid-connect-client/config/

# Write the configuration
echo "$PLUGIN_CONFIG" | docker exec -i "$WP_CONTAINER" tee /var/www/html/wp-content/plugins/miniorange-openid-connect-client/config/config.json > /dev/null

# Add marker file to indicate SSO is configured
log_info "Creating SSO configuration marker"
mkdir -p "${WP_DIR}/${DOMAIN}/sso"
touch "${WP_DIR}/${DOMAIN}/sso/.sso_configured"

# Update component registry to indicate SSO is configured
log_info "Updating component registry"
REGISTRY_FILE="/opt/agency_stack/registry/component_registry.json"
if [[ -f "$REGISTRY_FILE" ]]; then
    # Update the wordpress component to indicate SSO is configured
    if jq -e '.components[] | select(.name=="wordpress")' "$REGISTRY_FILE" > /dev/null; then
        # Component exists, update it
        jq '(.components[] | select(.name=="wordpress")).sso_configured = true' "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
        mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
    else
        # Component doesn't exist, add it
        jq '.components += [{"name":"wordpress","description":"WordPress CMS","enabled":true,"sso":true,"sso_configured":true}]' "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
        mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
    fi
fi

log_success "WordPress SSO integration with Keycloak configured successfully"
log_info "You can now log in to WordPress using Keycloak credentials at: ${WP_SITE_URL}/wp-login.php"
