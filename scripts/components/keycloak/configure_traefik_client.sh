#!/bin/bash
# Traefik SSO integration with Keycloak
# This script configures Traefik dashboard to use Keycloak for authentication

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/common.sh"

# Default values
CLIENT_ID="default"
DOMAIN=""
ADMIN_EMAIL=""
DASHBOARD_PORT="8081"
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
        --dashboard-port)
            DASHBOARD_PORT="$2"
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

# Ensure Keycloak is running
if ! curl -s -k "https://${DOMAIN}/health" &>/dev/null; then
    log_error "Keycloak is not accessible at https://${DOMAIN}"
    exit 1
fi

log_info "Configuring Traefik dashboard authentication with Keycloak"

# Get Keycloak admin token
log_info "Getting Keycloak admin token"
ADMIN_PASSWORD=$(cat "/opt/agency_stack/clients/${CLIENT_ID}/keycloak/secrets/admin_password.txt" 2>/dev/null)

if [[ -z "$ADMIN_PASSWORD" ]]; then
    log_error "Keycloak admin password not found at /opt/agency_stack/clients/${CLIENT_ID}/keycloak/secrets/admin_password.txt"
    exit 1
fi

ADMIN_TOKEN=$(curl -s -k -X POST "https://${DOMAIN}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=${ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
    log_error "Failed to get admin token from Keycloak"
    exit 1
fi

# Get Keycloak realm
KEYCLOAK_REALM="${CLIENT_ID}"
KEYCLOAK_DOMAIN="${DOMAIN}"

# Check if Traefik client already exists
log_info "Checking if Traefik client already exists"
CLIENT_ID_EXISTS=$(curl -s -k -X GET \
    "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.[] | select(.clientId=="traefik-dashboard") | .id')

# Path for client configuration file
CLIENT_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/keycloak"
mkdir -p "${CLIENT_CONFIG_DIR}"

# Configure Keycloak client for Traefik
if [[ -n "$CLIENT_ID_EXISTS" && "$FORCE" == "false" ]]; then
    log_info "Traefik client already exists, retrieving configuration"
    
    # Get existing client details
    CLIENT_DETAILS=$(curl -s -k -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json")
    
    # Get client secret
    CLIENT_SECRET=$(curl -s -k -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.value')
    
    if [[ -z "$CLIENT_SECRET" || "$CLIENT_SECRET" == "null" ]]; then
        log_warning "Client secret not found, generating new one"
        
        # Generate new client secret
        curl -s -k -X POST \
            "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" > /dev/null
        
        # Get the new client secret
        CLIENT_SECRET=$(curl -s -k -X GET \
            "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" | jq -r '.value')
    fi
else
    log_info "Creating new Traefik dashboard client"
    
    # Create Traefik client
    CLIENT_CREATION_RESPONSE=$(curl -s -k -X POST \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "traefik-dashboard",
            "name": "Traefik Dashboard",
            "description": "Traefik Dashboard Authentication",
            "rootUrl": "http://localhost:'${DASHBOARD_PORT}'",
            "adminUrl": "http://localhost:'${DASHBOARD_PORT}'",
            "baseUrl": "http://localhost:'${DASHBOARD_PORT}'",
            "redirectUris": [
                "http://localhost:'${DASHBOARD_PORT}'/*"
            ],
            "webOrigins": [
                "http://localhost:'${DASHBOARD_PORT}'"
            ],
            "publicClient": false,
            "clientAuthenticatorType": "client-secret",
            "protocol": "openid-connect",
            "standardFlowEnabled": true,
            "implicitFlowEnabled": false,
            "directAccessGrantsEnabled": true,
            "serviceAccountsEnabled": true,
            "authorizationServicesEnabled": true,
            "fullScopeAllowed": true
        }')
    
    # Get client ID
    CLIENT_ID_EXISTS=$(curl -s -k -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.[] | select(.clientId=="traefik-dashboard") | .id')
    
    if [[ -z "$CLIENT_ID_EXISTS" || "$CLIENT_ID_EXISTS" == "null" ]]; then
        log_error "Failed to create Traefik client"
        exit 1
    fi
    
    # Get client secret
    CLIENT_SECRET=$(curl -s -k -X GET \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.value')
    
    if [[ -z "$CLIENT_SECRET" || "$CLIENT_SECRET" == "null" ]]; then
        log_warning "Client secret not found, generating new one"
        
        # Generate new client secret
        curl -s -k -X POST \
            "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" > /dev/null
        
        # Get the new client secret
        CLIENT_SECRET=$(curl -s -k -X GET \
            "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/client-secret" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" | jq -r '.value')
    fi
    
    # Create mappers for username and email
    curl -s -k -X POST \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/protocol-mappers/models" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "username",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "username",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "preferred_username",
                "jsonType.label": "String"
            }
        }' > /dev/null
    
    curl -s -k -X POST \
        "https://${KEYCLOAK_DOMAIN}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID_EXISTS}/protocol-mappers/models" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "email",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "email",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "email",
                "jsonType.label": "String"
            }
        }' > /dev/null
fi

# Save client information
mkdir -p "${CLIENT_CONFIG_DIR}"
echo "KEYCLOAK_REALM=${KEYCLOAK_REALM}" > "${CLIENT_CONFIG_DIR}/traefik-oidc.env"
echo "KEYCLOAK_DOMAIN=${KEYCLOAK_DOMAIN}" >> "${CLIENT_CONFIG_DIR}/traefik-oidc.env"
echo "OIDC_CLIENT_ID=traefik-dashboard" >> "${CLIENT_CONFIG_DIR}/traefik-oidc.env"
echo "OIDC_CLIENT_SECRET=${CLIENT_SECRET}" >> "${CLIENT_CONFIG_DIR}/traefik-oidc.env"
echo "OIDC_CALLBACK_URL=http://localhost:${DASHBOARD_PORT}/oauth-callback" >> "${CLIENT_CONFIG_DIR}/traefik-oidc.env"

log_success "Traefik client configuration completed successfully!"
log_info "OIDC client information saved to ${CLIENT_CONFIG_DIR}/traefik-oidc.env"

# Output configuration summary
echo ""
echo "==================================================================="
echo "  TRAEFIK KEYCLOAK INTEGRATION SUMMARY"
echo "==================================================================="
echo ""
echo "  Keycloak Domain: ${KEYCLOAK_DOMAIN}"
echo "  Keycloak Realm: ${KEYCLOAK_REALM}"
echo "  OIDC Client ID: traefik-dashboard"
echo "  OIDC Client Secret: ${CLIENT_SECRET:0:8}********"
echo "  Callback URL: http://localhost:${DASHBOARD_PORT}/oauth-callback"
echo ""
echo "  Configuration saved to: ${CLIENT_CONFIG_DIR}/traefik-oidc.env"
echo ""
echo "==================================================================="
