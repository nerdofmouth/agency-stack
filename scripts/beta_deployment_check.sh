#!/bin/bash
# beta_deployment_check.sh - Comprehensive validation for AgencyStack Beta
# 
# Validates a complete AgencyStack deployment across all critical components
# Author: AgencyStack Team
# Date: 2025-04-14

set -eo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${SCRIPT_DIR}/utils/common.sh"

# Default values
DOMAIN=""
CLIENT_ID="default"
VERBOSE=false
SKIP_EXPENSIVE=false
MAX_PARALLEL=2
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0
BETA_CHECK_LOG="/var/log/agency_stack/beta_check_$(date +%Y%m%d%H%M%S).log"

# Show usage information
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Performs comprehensive validation of AgencyStack Beta deployment."
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN         Primary domain name for validation (required)"
    echo "  --client-id CLIENT_ID   Client ID for multi-tenant validation (default: default)"
    echo "  --skip-expensive        Skip resource-intensive checks"
    echo "  --max-parallel N        Maximum parallel validation tasks (default: 2)"
    echo "  --verbose               Enable verbose output"
    echo "  --help                  Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --domain agency.example.com --client-id tenant1"
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
        --skip-expensive)
            SKIP_EXPENSIVE=true
            shift
            ;;
        --max-parallel)
            MAX_PARALLEL="$2"
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

# Create log directory if it doesn't exist
mkdir -p /var/log/agency_stack

# Print header
{
    log_header "AgencyStack Beta Deployment Validation"
    log_info "Domain: $DOMAIN"
    log_info "Client ID: $CLIENT_ID"
    log_info "Date: $(date)"
    log_info "Hostname: $(hostname)"
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Check system resources
{
    log_section "System Resources"
    log_info "CPU: $(nproc) cores"
    log_info "Memory: $(free -h | grep Mem | awk '{print $2}')"
    log_info "Disk space: $(df -h / | awk 'NR==2 {print $4}') available"
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Check if we're running on a VM
{
    log_section "Environment Check"
    if systemd-detect-virt -q; then
        VIRT_TYPE=$(systemd-detect-virt)
        log_info "Running on virtual machine: $VIRT_TYPE"
    else
        log_info "Running on bare metal or unknown virtualization"
    fi
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Run TLS/SSO validation
{
    log_section "TLS/SSO Validation"
    log_info "Running TLS verification..."
    if [ -f "${ROOT_DIR}/scripts/utils/tls_verify.sh" ]; then
        bash "${ROOT_DIR}/scripts/utils/tls_verify.sh" --domain "$DOMAIN" || {
            log_error "TLS verification failed"
            ((ERROR_COUNT++))
        }
    else
        log_warning "TLS verification script not found"
        ((WARNING_COUNT++))
    fi

    log_info "Running SSO status check..."
    if [ -f "${ROOT_DIR}/scripts/utils/sso_status.sh" ]; then
        bash "${ROOT_DIR}/scripts/utils/sso_status.sh" --domain "$DOMAIN" --client-id "$CLIENT_ID" || {
            log_error "SSO status check failed"
            ((ERROR_COUNT++))
        }
    else
        log_warning "SSO status script not found"
        ((WARNING_COUNT++))
    fi

    log_info "Running registry validation..."
    if [ -f "${ROOT_DIR}/scripts/utils/tls_sso_registry_check.sh" ]; then
        bash "${ROOT_DIR}/scripts/utils/tls_sso_registry_check.sh" || {
            log_warning "Registry validation found issues"
            ((WARNING_COUNT++))
        }
    else
        log_warning "Registry validation script not found"
        ((WARNING_COUNT++))
    fi
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Run AI validation
{
    log_section "AI Suite Validation"
    log_info "Running AI alpha check..."
    
    # Run the AI alpha check
    make -C "$ROOT_DIR" ai-alpha-check || {
        log_error "AI alpha check failed"
        ((ERROR_COUNT++))
    }

    # Check mock mode functionality
    if [ "$SKIP_EXPENSIVE" = "false" ]; then
        log_info "Testing AI mock mode..."
        make -C "$ROOT_DIR" ai-mock-mode && {
            log_success "Mock mode enabled successfully"
            ((SUCCESS_COUNT++))
            
            # Disable mock mode after successful test
            make -C "$ROOT_DIR" ai-mock-mode-disable
        } || {
            log_warning "Mock mode test failed"
            ((WARNING_COUNT++))
        }
    else
        log_info "Skipping AI mock mode test (expensive)"
    fi
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Run billing validation
{
    log_section "Billing Validation"
    log_info "Running billing alpha check..."

    if [ -f "${ROOT_DIR}/scripts/utils/killbill_validation.sh" ]; then
        bash "${ROOT_DIR}/scripts/utils/killbill_validation.sh" --domain "$DOMAIN" --client-id "$CLIENT_ID" || {
            log_error "KillBill validation failed"
            ((ERROR_COUNT++))
        }
    else
        log_warning "KillBill validation script not found"
        ((WARNING_COUNT++))
    fi
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Validate inter-component connectivity
{
    log_section "Inter-Component Connectivity"
    log_info "Checking key service connectivity..."

    # Define critical services and their ports
    declare -A SERVICES=(
        ["keycloak"]="8080"
        ["dashboard"]="80"
        ["langchain"]="5111"
        ["resource_watcher"]="5220"
        ["killbill"]="8080"
        ["prometheus"]="9090"
        ["traefik"]="8080"
    )

    for service in "${!SERVICES[@]}"; do
        port="${SERVICES[$service]}"
        log_info "Checking $service on port $port..."
        if nc -z localhost "$port" 2>/dev/null; then
            log_success "$service is accessible on port $port"
            ((SUCCESS_COUNT++))
        else
            log_warning "$service is not accessible on port $port"
            ((WARNING_COUNT++))
        fi
    done
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Check DNS configuration
{
    log_section "DNS Configuration"
    log_info "Validating DNS setup for $DOMAIN..."

    # Check main domain
    host "$DOMAIN" > /dev/null 2>&1 && {
        log_success "Main domain $DOMAIN resolves correctly"
        ((SUCCESS_COUNT++))
    } || {
        log_error "Failed to resolve main domain $DOMAIN"
        ((ERROR_COUNT++))
    }

    # Check critical subdomains
    SUBDOMAINS=("keycloak" "dashboard" "billing" "ai" "mail")
    for subdomain in "${SUBDOMAINS[@]}"; do
        fqdn="${subdomain}.$DOMAIN"
        host "$fqdn" > /dev/null 2>&1 && {
            log_success "Subdomain $fqdn resolves correctly"
            ((SUCCESS_COUNT++))
        } || {
            log_warning "Failed to resolve subdomain $fqdn"
            ((WARNING_COUNT++))
        }
    done
    echo ""
} | tee -a "$BETA_CHECK_LOG"

# Generate summary
{
    log_section "Beta Validation Summary"
    log_info "Success count: $SUCCESS_COUNT"
    log_info "Warning count: $WARNING_COUNT"
    log_info "Error count: $ERROR_COUNT"
    log_info "Detailed log: $BETA_CHECK_LOG"
    
    if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
        log_success "All checks passed successfully! Deployment is ready for Beta."
        echo "✅ BETA_READY=true" >> "$BETA_CHECK_LOG"
        exit 0
    elif [ $ERROR_COUNT -eq 0 ]; then
        log_warning "Deployment has $WARNING_COUNT warnings but may be suitable for Beta."
        echo "⚠️ BETA_READY=maybe" >> "$BETA_CHECK_LOG"
        exit 0
    else
        log_error "Deployment has $ERROR_COUNT errors and is not ready for Beta."
        echo "❌ BETA_READY=false" >> "$BETA_CHECK_LOG"
        exit 1
    fi
} | tee -a "$BETA_CHECK_LOG"
