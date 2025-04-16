#!/bin/bash
# killbill_validation.sh - Validation script for KillBill integration
# Part of AgencyStack TLS/SSO Validation Suite
#
# Validates KillBill deployment for proper TLS, SSO, and metrics configuration
# Author: AgencyStack Team
# Date: 2025-04-14

set -eo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default values
DOMAIN=""
CLIENT_ID="default"
VERBOSE=false
TIMEOUT=10
ERROR_COUNT=0
WARNING_COUNT=0

# Show usage information
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Validates KillBill deployment for proper TLS, SSO, and metrics integration."
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN         Domain name for validation (required)"
    echo "  --client-id CLIENT_ID   Client ID for multi-tenant setup (default: default)"
    echo "  --timeout TIMEOUT       Connection timeout in seconds (default: 10)"
    echo "  --verbose               Enable verbose output"
    echo "  --help                  Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --domain billing.example.com --client-id tenant1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
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

# Verify domain is specified
if [ -z "$DOMAIN" ]; then
    log_error "Domain is required. Use --domain to specify it."
    show_help
    exit 1
fi

# Print header
log_header "KillBill TLS/SSO/Metrics Validation"
log_info "Validating KillBill integration for domain: $DOMAIN (client: $CLIENT_ID)"
echo ""

# Check if KillBill is installed
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/killbill"
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "KillBill is not installed for client $CLIENT_ID"
    exit 1
fi

# Validate TLS Configuration
log_section "Validating TLS Configuration"

# Check KillBill API TLS
log_info "Checking TLS for KillBill API (billing.$DOMAIN)"
TLS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "https://billing.${DOMAIN}/api/1.0/kb/healthcheck" 2>/dev/null || echo "failed")
if [ "$TLS_STATUS" = "failed" ]; then
    log_error "Unable to connect to KillBill API. TLS connection failed."
else
    if [ "$TLS_STATUS" = "401" ] || [ "$TLS_STATUS" = "200" ]; then
        log_success "KillBill API TLS connection successful (HTTP $TLS_STATUS)"
        
        # Check certificate expiration
        CERT_EXPIRY=$(echo | openssl s_client -servername "billing.${DOMAIN}" -connect "billing.${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        CERT_EXPIRY_SECONDS=$(date -d "$CERT_EXPIRY" +%s)
        NOW_SECONDS=$(date +%s)
        DAYS_REMAINING=$(( ($CERT_EXPIRY_SECONDS - $NOW_SECONDS) / 86400 ))
        
        if [ $DAYS_REMAINING -lt 30 ]; then
            log_warning "Certificate will expire in $DAYS_REMAINING days ($CERT_EXPIRY)"
        else
            log_success "Certificate valid for $DAYS_REMAINING days ($CERT_EXPIRY)"
        fi
    else
        log_error "KillBill API TLS connection failed with status $TLS_STATUS"
    fi
fi

# Check KAUI TLS
log_info "Checking TLS for KAUI UI (billing-admin.$DOMAIN)"
TLS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "https://billing-admin.${DOMAIN}/" 2>/dev/null || echo "failed")
if [ "$TLS_STATUS" = "failed" ]; then
    log_error "Unable to connect to KAUI UI. TLS connection failed."
else
    if [ "$TLS_STATUS" = "200" ] || [ "$TLS_STATUS" = "302" ]; then
        log_success "KAUI UI TLS connection successful (HTTP $TLS_STATUS)"
    else
        log_error "KAUI UI TLS connection failed with status $TLS_STATUS"
    fi
fi

# Validate SSO Configuration
log_section "Validating SSO Configuration"

# Check if Keycloak is available
log_info "Checking Keycloak availability"
KC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "https://keycloak.${DOMAIN}/" 2>/dev/null || echo "failed")
if [ "$KC_STATUS" = "failed" ]; then
    log_error "Unable to connect to Keycloak. SSO validation will be skipped."
else
    log_success "Keycloak is available (HTTP $KC_STATUS)"
    
    # Check KillBill SSO configuration
    log_info "Checking KillBill SSO configuration"
    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        if grep -q "keycloak" "$INSTALL_DIR/docker-compose.yml"; then
            log_success "KillBill has Keycloak configuration in docker-compose.yml"
        else
            log_warning "KillBill does not have Keycloak configuration in docker-compose.yml"
        fi
    else
        log_error "KillBill docker-compose.yml not found."
    fi
    
    # Check KAUI SSO Redirection
    log_info "Checking KAUI SSO redirection"
    SSO_REDIRECT=$(curl -s -o /dev/null -w "%{redirect_url}" -m ${TIMEOUT} "https://billing-admin.${DOMAIN}/login" 2>/dev/null || echo "failed")
    if [ "$SSO_REDIRECT" = "failed" ]; then
        log_error "Unable to check KAUI SSO redirection"
    else
        if [[ "$SSO_REDIRECT" == *"keycloak"* ]]; then
            log_success "KAUI redirects to Keycloak for authentication"
        else
            log_warning "KAUI does not redirect to Keycloak for authentication"
        fi
    fi
fi

# Validate Prometheus Metrics
log_section "Validating Prometheus Metrics Configuration"

# Check if metrics endpoint is exposed
log_info "Checking KillBill metrics endpoint"
METRICS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "http://localhost:9092" 2>/dev/null || echo "failed")
if [ "$METRICS_STATUS" = "failed" ]; then
    log_warning "KillBill metrics endpoint is not accessible locally"
else
    log_success "KillBill metrics endpoint is accessible (HTTP $METRICS_STATUS)"
fi

# Check if metrics are configured in Prometheus
log_info "Checking Prometheus configuration for KillBill"
PROMETHEUS_CONFIG="/opt/agency_stack/prometheus/prometheus.yml"
if [ -f "$PROMETHEUS_CONFIG" ]; then
    if grep -q "killbill" "$PROMETHEUS_CONFIG"; then
        log_success "KillBill metrics are configured in Prometheus"
    else
        log_warning "KillBill metrics are not configured in Prometheus"
    fi
else
    log_warning "Prometheus configuration file not found"
fi

# Summary
log_section "Validation Summary"
log_info "Domain: billing.$DOMAIN (Client: $CLIENT_ID)"

if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
    log_success "All checks passed successfully!"
    exit 0
elif [ $ERROR_COUNT -eq 0 ]; then
    log_warning "Validation completed with $WARNING_COUNT warnings."
    exit 0
else
    log_error "Validation failed with $ERROR_COUNT errors and $WARNING_COUNT warnings."
    exit 1
fi
