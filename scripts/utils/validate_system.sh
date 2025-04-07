#!/bin/bash
# validate_system.sh - System requirements validator for AgencyStack
# 
# Performs environment, memory, disk, network, and docker checks before installation
# Usage: scripts/utils/validate_system.sh [--verbose] [--skip-network]

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default parameters
VERBOSE=false
SKIP_NETWORK=false
MIN_MEMORY_GB=4
MIN_DISK_GB=20
REQUIRED_PORTS=(80 443 5432 6379)
REQUIRED_COMMANDS=(docker docker-compose curl wget jq grep sed)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --skip-network)
            SKIP_NETWORK=true
            shift
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

log_info "Starting system validation..."

# Check system memory
check_memory() {
    log_info "Checking system memory..."
    total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_memory_gb=$(echo "scale=2; $total_memory_kb / 1024 / 1024" | bc)
    
    log_info "Total memory: ${total_memory_gb}GB"
    
    if (( $(echo "$total_memory_gb < $MIN_MEMORY_GB" | bc -l) )); then
        log_error "Insufficient memory. Required: ${MIN_MEMORY_GB}GB, Available: ${total_memory_gb}GB"
        return 1
    else
        log_success "Memory check passed"
        return 0
    fi
}

# Check disk space
check_disk() {
    log_info "Checking disk space..."
    # Get available disk space where AgencyStack will be installed
    available_disk_kb=$(df -k /opt | awk 'NR==2 {print $4}')
    available_disk_gb=$(echo "scale=2; $available_disk_kb / 1024 / 1024" | bc)
    
    log_info "Available disk space: ${available_disk_gb}GB"
    
    if (( $(echo "$available_disk_gb < $MIN_DISK_GB" | bc -l) )); then
        log_error "Insufficient disk space. Required: ${MIN_DISK_GB}GB, Available: ${available_disk_gb}GB"
        return 1
    else
        log_success "Disk space check passed"
        return 0
    fi
}

# Check required commands
check_commands() {
    log_info "Checking required commands..."
    local missing_commands=()
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
            log_warning "Command not found: $cmd"
        else
            [[ "$VERBOSE" == "true" ]] && log_info "Command found: $cmd"
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    else
        log_success "All required commands are available"
        return 0
    fi
}

# Check network connectivity
check_network() {
    if [[ "$SKIP_NETWORK" == "true" ]]; then
        log_warning "Network check skipped as requested"
        return 0
    fi
    
    log_info "Checking network connectivity..."
    if ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        log_error "Network connectivity check failed"
        return 1
    else
        log_success "Network connectivity check passed"
        return 0
    fi
}

# Check ports
check_ports() {
    log_info "Checking port availability..."
    local busy_ports=()
    
    for port in "${REQUIRED_PORTS[@]}"; do
        # Check if port is already in use
        if netstat -tuln | grep -q ":${port} "; then
            busy_ports+=("$port")
            log_warning "Port ${port} is already in use"
        else
            [[ "$VERBOSE" == "true" ]] && log_info "Port ${port} is available"
        fi
    done
    
    if [[ ${#busy_ports[@]} -gt 0 ]]; then
        log_warning "The following ports are in use: ${busy_ports[*]}"
        log_warning "Consider stopping services using these ports before installation"
        return 0  # Warning only, not a failure
    else
        log_success "All required ports are available"
        return 0
    fi
}

# Check Docker
check_docker() {
    log_info "Checking Docker..."
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    log_info "Docker version: $docker_version"
    
    # Check Docker Compose version
    compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
    log_info "Docker Compose version: $compose_version"
    
    log_success "Docker check passed"
    return 0
}

# Run all checks
run_validation() {
    local failed=0
    
    # Start with required checks
    check_commands || ((failed++))
    check_memory || ((failed++))
    check_disk || ((failed++))
    check_docker || ((failed++))
    
    # These checks provide warnings but don't fail the validation
    check_network
    check_ports
    
    # Summary
    if [[ $failed -eq 0 ]]; then
        log_success "System validation completed successfully"
        return 0
    else
        log_error "System validation completed with $failed failures"
        return 1
    fi
}

# Execute validation
run_validation
