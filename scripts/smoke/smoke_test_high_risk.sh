#!/bin/bash
# smoke_test_high_risk.sh - Smoke test for high-risk components
#
# Tests runtime functionality of critical components: docker, mailu, tailscale
# Usage: ./smoke_test_high_risk.sh [--verbose] [--component=NAME] [--test-all]

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${ROOT_DIR}/scripts/utils/common.sh"
source "${ROOT_DIR}/scripts/utils/log_helpers.sh"

# Default settings
VERBOSE=false
COMPONENT=""
TEST_ALL=false
LOG_FILE="/var/log/agency_stack/smoke_test.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --component=*)
            COMPONENT="${1#*=}"
            shift
            ;;
        --test-all)
            TEST_ALL=true
            shift
            ;;
        --help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose           Show detailed output"
            echo "  --component=NAME    Only test specific component"
            echo "  --test-all          Include Mailu and Tailscale tests"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Function to test Docker functionality
test_docker() {
    log_banner "Testing Docker" "$LOG_FILE"
    
    # Check Docker daemon
    if docker info &>/dev/null; then
        log_success "Docker daemon is running" 
        echo "docker status: running" >> "$LOG_FILE"
        
        # Check default networks
        if docker network ls | grep -q "agency-network"; then
            log_success "Agency network exists"
        else
            log_warning "Agency network not found"
            echo "docker network missing: agency-network" >> "$LOG_FILE"
        fi
        
        # Check running containers
        container_count=$(docker ps --format '{{.Names}}' | wc -l)
        log_info "Found $container_count running containers"
        echo "docker containers: $container_count" >> "$LOG_FILE"
        
        return 0
    else
        log_error "Docker daemon is not running"
        echo "docker status: not running" >> "$LOG_FILE"
        return 1
    fi
}

# Function to test Mailu email functionality
test_mailu() {
    log_banner "Testing Mailu" "$LOG_FILE"
    
    # Check if Mailu container is running
    if docker ps | grep -q "mailu"; then
        log_success "Mailu container is running"
        echo "mailu container: running" >> "$LOG_FILE"
        
        # Test SMTP port
        if nc -z localhost 25 &>/dev/null; then
            log_success "Mailu SMTP port (25) is open"
            echo "mailu smtp: responsive" >> "$LOG_FILE"
        else
            log_warning "Mailu SMTP port (25) is not accessible"
            echo "mailu smtp: not responsive" >> "$LOG_FILE"
        fi
        
        # Test IMAP port
        if nc -z localhost 143 &>/dev/null; then
            log_success "Mailu IMAP port (143) is open"
            echo "mailu imap: responsive" >> "$LOG_FILE"
        else
            log_warning "Mailu IMAP port (143) is not accessible"
            echo "mailu imap: not responsive" >> "$LOG_FILE"
        fi
        
        # Test admin interface
        if curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302\|401"; then
            log_success "Mailu admin interface is responsive"
            echo "mailu admin: responsive" >> "$LOG_FILE"
        else
            log_warning "Mailu admin interface is not responsive"
            echo "mailu admin: not responsive" >> "$LOG_FILE"
        fi
        
        return 0
    else
        log_warning "Mailu container is not running"
        echo "mailu container: not running" >> "$LOG_FILE"
        return 1
    fi
}

# Function to test Tailscale connectivity
test_tailscale() {
    log_banner "Testing Tailscale" "$LOG_FILE"
    
    # Check if tailscale is installed
    if command -v tailscale &>/dev/null; then
        log_success "Tailscale is installed"
        echo "tailscale installed: yes" >> "$LOG_FILE"
        
        # Check if tailscale is running
        if tailscale status &>/dev/null; then
            log_success "Tailscale is running"
            echo "tailscale status: running" >> "$LOG_FILE"
            
            # Get IP address
            tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
            log_info "Tailscale IP: $tailscale_ip"
            echo "tailscale ip: $tailscale_ip" >> "$LOG_FILE"
            
            return 0
        else
            log_warning "Tailscale is not connected"
            echo "tailscale status: not connected" >> "$LOG_FILE"
            return 1
        fi
    else
        log_warning "Tailscale is not installed"
        echo "tailscale installed: no" >> "$LOG_FILE"
        return 1
    fi
}

# Main function to run tests
main() {
    log_banner "AgencyStack High-Risk Component Smoke Test" "$LOG_FILE"
    log_info "Starting smoke tests: $(date)"
    echo "test_start: $(date)" >> "$LOG_FILE"
    
    # Initialize counters
    local pass_count=0
    local fail_count=0
    local total_count=0
    
    # Run tests based on component parameter
    if [[ -z "$COMPONENT" || "$COMPONENT" == "docker" ]]; then
        if test_docker; then
            ((pass_count++))
            log_info "Docker test: PASSED"
        else
            ((fail_count++))
            log_error "Docker test: FAILED"
        fi
        ((total_count++))
    fi
    
    # Test Mailu only if --test-all flag is present
    if [[ -z "$COMPONENT" || "$COMPONENT" == "mailu" ]]; then
        if [[ "$TEST_ALL" == "true" ]]; then
            if test_mailu; then
                ((pass_count++))
                log_info "Mailu test: PASSED"
            else
                ((fail_count++))
                log_warning "Mailu test: FAILED (Not installed or not running)"
            fi
            ((total_count++))
        else
            log_info "Skipping Mailu test (use --test-all to include)"
        fi
    fi
    
    # Test Tailscale only if --test-all flag is present
    if [[ -z "$COMPONENT" || "$COMPONENT" == "tailscale" ]]; then
        if [[ "$TEST_ALL" == "true" ]]; then
            if test_tailscale; then
                ((pass_count++))
                log_info "Tailscale test: PASSED"
            else
                ((fail_count++))
                log_warning "Tailscale test: FAILED (Not installed or not running)"
            fi
            ((total_count++))
        else
            log_info "Skipping Tailscale test (use --test-all to include)"
        fi
    fi
    
    # Show summary
    log_banner "Smoke Test Summary" "$LOG_FILE"
    log_info "Tests completed: $(date)"
    log_info "Passed: $pass_count"
    log_info "Failed: $fail_count"
    log_info "Total: $total_count"
    
    echo "test_end: $(date)" >> "$LOG_FILE"
    echo "tests_passed: $pass_count" >> "$LOG_FILE"
    echo "tests_failed: $fail_count" >> "$LOG_FILE"
    echo "tests_total: $total_count" >> "$LOG_FILE"
    
    # Exit with failure if any tests failed
    if [[ $fail_count -gt 0 ]]; then
        log_error "Smoke test failed with $fail_count failures"
        echo "test_result: FAILED" >> "$LOG_FILE"
        return 1
    else
        log_success "All smoke tests passed!"
        echo "test_result: PASSED" >> "$LOG_FILE"
        return 0
    fi
}

# Execute main function
main
