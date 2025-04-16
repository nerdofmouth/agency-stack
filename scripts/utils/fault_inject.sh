#!/bin/bash
# fault_inject.sh - Simulate failure states for AgencyStack recovery testing
#
# Injects controlled faults to test recovery mechanisms
# Usage: ./fault_inject.sh [FAULT_TYPE] [--component=NAME] [--severity=LEVEL] [--help]

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default values
FAULT_TYPE="${1:-}"
COMPONENT=""
SEVERITY="medium"
CLIENT_ID="${CLIENT_ID:-default}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
LOG_DIR="/var/log/agency_stack"

# Shift the first argument (FAULT_TYPE)
if [[ $# -gt 0 ]]; then
    shift
fi

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --component=*)
            COMPONENT="${1#*=}"
            shift
            ;;
        --severity=*)
            SEVERITY="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $(basename "$0") FAULT_TYPE [OPTIONS]"
            echo ""
            echo "Fault Types:"
            echo "  disk-fill        Fill disk space to test low space scenarios"
            echo "  port-block       Block ports to test connectivity issues"
            echo "  docker-kill      Kill docker containers to test crash recovery"
            echo "  marker-remove    Remove .installed_ok markers to test reinstall"
            echo "  log-corrupt      Corrupt log files to test log resilience"
            echo ""
            echo "Options:"
            echo "  --component=NAME    Target specific component"
            echo "  --severity=LEVEL    Fault severity: low, medium, high (default: medium)"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") disk-fill --severity=low"
            echo "  $(basename "$0") docker-kill --component=mailu"
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate fault type
if [[ -z "$FAULT_TYPE" ]]; then
    log_error "No fault type specified. Use --help for usage information."
    exit 1
fi

# Function to inject disk fill fault
inject_disk_fill() {
    log_banner "Injecting Disk Fill Fault"
    
    # Determine fill size based on severity
    local fill_size
    case "$SEVERITY" in
        low)
            fill_size="100M"
            ;;
        medium)
            fill_size="500M"
            ;;
        high)
            fill_size="1G"
            ;;
        *)
            log_error "Invalid severity level: $SEVERITY"
            return 1
            ;;
    esac
    
    log_warning "Creating $fill_size fault file in /tmp"
    dd if=/dev/zero of=/tmp/fault_file bs=1M count="${fill_size//[^0-9]/}" status=progress
    
    log_info "Disk fill fault injected with $fill_size"
    log_warning "Run 'rm /tmp/fault_file' to remove the fault condition"
    
    return 0
}

# Function to block ports
inject_port_block() {
    log_banner "Injecting Port Block Fault"
    
    # Ensure iptables is available
    if ! command -v iptables &>/dev/null; then
        log_error "iptables command not found. Cannot inject port block fault."
        return 1
    fi
    
    # Determine ports to block based on component and severity
    local ports
    if [[ -n "$COMPONENT" ]]; then
        case "$COMPONENT" in
            docker)
                ports="2375 2376"
                ;;
            mailu)
                ports="25 143 587 993"
                ;;
            tailscale)
                ports="41641"
                ;;
            *)
                # Get ports from component's config if available
                if [[ -f "${INSTALL_DIR}/${COMPONENT}/config/ports.txt" ]]; then
                    ports=$(cat "${INSTALL_DIR}/${COMPONENT}/config/ports.txt")
                else
                    log_warning "No known ports for component: $COMPONENT"
                    ports="80 443"  # Default to standard web ports
                fi
                ;;
        esac
    else
        # Default ports based on severity
        case "$SEVERITY" in
            low)
                ports="8080"  # Block non-critical port
                ;;
            medium)
                ports="80 443"  # Block web ports
                ;;
            high)
                ports="80 443 22 53"  # Block critical services
                ;;
        esac
    fi
    
    log_warning "Blocking ports: $ports"
    
    # Block each port
    for port in $ports; do
        iptables -A INPUT -p tcp --dport "$port" -j DROP
        iptables -A OUTPUT -p tcp --sport "$port" -j DROP
        log_info "Blocked port: $port"
    done
    
    log_info "Port block fault injected for ports: $ports"
    log_warning "Run 'iptables -F' to remove all port blocks"
    
    return 0
}

# Function to kill Docker containers
inject_docker_kill() {
    log_banner "Injecting Docker Kill Fault"
    
    # Ensure docker is available
    if ! command -v docker &>/dev/null; then
        log_error "docker command not found. Cannot inject docker kill fault."
        return 1
    fi
    
    # Get containers to kill based on component and severity
    local containers
    if [[ -n "$COMPONENT" ]]; then
        # Get containers for specific component
        containers=$(docker ps --format '{{.Names}}' | grep "$COMPONENT" || echo "")
        
        if [[ -z "$containers" ]]; then
            log_warning "No running containers found for component: $COMPONENT"
            return 1
        fi
    else
        # Get containers based on severity
        case "$SEVERITY" in
            low)
                # Kill non-critical containers (get latest container)
                containers=$(docker ps --format '{{.Names}}' | tail -1)
                ;;
            medium)
                # Kill half of running containers
                local count=$(docker ps --format '{{.Names}}' | wc -l)
                local half=$((count / 2))
                containers=$(docker ps --format '{{.Names}}' | head -"$half")
                ;;
            high)
                # Kill all containers except essential infrastructure
                containers=$(docker ps --format '{{.Names}}' | grep -v "traefik")
                ;;
        esac
    fi
    
    if [[ -z "$containers" ]]; then
        log_warning "No containers selected for killing"
        return 1
    fi
    
    log_warning "Killing containers: $containers"
    
    # Kill each container
    echo "$containers" | while read -r container; do
        docker kill "$container" &>/dev/null
        log_info "Killed container: $container"
    done
    
    log_info "Docker kill fault injected"
    log_warning "Run 'docker-compose up -d' in component directories to restart"
    
    return 0
}

# Function to remove installed_ok markers
inject_marker_remove() {
    log_banner "Injecting Marker Remove Fault"
    
    local markers=()
    
    if [[ -n "$COMPONENT" ]]; then
        # Remove marker for specific component
        local marker="${INSTALL_DIR}/${COMPONENT}/.installed_ok"
        if [[ -f "$marker" ]]; then
            markers+=("$marker")
        else
            log_warning "No .installed_ok marker found for component: $COMPONENT"
            return 1
        fi
    else
        # Get markers based on severity
        case "$SEVERITY" in
            low)
                # Remove one random marker
                local random_component=$(find "$INSTALL_DIR" -name ".installed_ok" | sort -R | head -1)
                if [[ -n "$random_component" ]]; then
                    markers+=("$random_component")
                fi
                ;;
            medium)
                # Remove markers for non-critical components
                while IFS= read -r marker; do
                    if [[ "$marker" != *"docker"* && "$marker" != *"traefik"* ]]; then
                        markers+=("$marker")
                    fi
                done < <(find "$INSTALL_DIR" -name ".installed_ok" | sort -R | head -3)
                ;;
            high)
                # Remove all markers
                while IFS= read -r marker; do
                    markers+=("$marker")
                done < <(find "$INSTALL_DIR" -name ".installed_ok")
                ;;
        esac
    fi
    
    if [[ ${#markers[@]} -eq 0 ]]; then
        log_warning "No .installed_ok markers selected for removal"
        return 1
    fi
    
    log_warning "Removing installation markers: ${markers[*]}"
    
    # Remove each marker
    for marker in "${markers[@]}"; do
        mv "$marker" "${marker}.fault_backup"
        log_info "Removed marker: $marker (backup created)"
    done
    
    log_info "Marker remove fault injected"
    log_warning "Run 'make alpha-check' followed by 'make alpha-fix' to repair"
    
    return 0
}

# Function to corrupt log files
inject_log_corrupt() {
    log_banner "Injecting Log Corruption Fault"
    
    local logs=()
    
    if [[ -n "$COMPONENT" ]]; then
        # Corrupt log for specific component
        local log="${LOG_DIR}/components/${COMPONENT}.log"
        if [[ -f "$log" ]]; then
            logs+=("$log")
        else
            log_warning "No log file found for component: $COMPONENT"
            return 1
        fi
    else
        # Get logs based on severity
        case "$SEVERITY" in
            low)
                # Corrupt one random log
                local random_log=$(find "$LOG_DIR" -name "*.log" | sort -R | head -1)
                if [[ -n "$random_log" ]]; then
                    logs+=("$random_log")
                fi
                ;;
            medium)
                # Corrupt multiple component logs
                while IFS= read -r log_file; do
                    logs+=("$log_file")
                done < <(find "${LOG_DIR}/components" -name "*.log" | sort -R | head -3)
                ;;
            high)
                # Corrupt important logs
                logs+=("${LOG_DIR}/install.log")
                while IFS= read -r log_file; do
                    logs+=("$log_file")
                done < <(find "${LOG_DIR}/components" -name "*.log" | grep -E "docker|traefik|mailu")
                ;;
        esac
    fi
    
    if [[ ${#logs[@]} -eq 0 ]]; then
        log_warning "No log files selected for corruption"
        return 1
    fi
    
    log_warning "Corrupting log files: ${logs[*]}"
    
    # Corrupt each log
    for log_file in "${logs[@]}"; do
        # Create backup
        cp "$log_file" "${log_file}.fault_backup"
        
        # Corrupt the log file (truncate and add garbage)
        truncate -s 100 "$log_file"
        echo "CORRUPTED_LOG_TEST_$$_RANDOM_DATA" >> "$log_file"
        
        log_info "Corrupted log file: $log_file (backup created)"
    done
    
    log_info "Log corruption fault injected"
    log_warning "Check log rotation and recovery mechanisms"
    
    return 0
}

# Main function to inject faults
main() {
    log_info "Starting fault injection: $FAULT_TYPE"
    log_info "Component: ${COMPONENT:-all}"
    log_info "Severity: $SEVERITY"
    
    # Create fault record
    local fault_record="${LOG_DIR}/fault_inject_$(date +%Y%m%d_%H%M%S).log"
    echo "FAULT_TYPE: $FAULT_TYPE" > "$fault_record"
    echo "COMPONENT: ${COMPONENT:-all}" >> "$fault_record"
    echo "SEVERITY: $SEVERITY" >> "$fault_record"
    echo "TIMESTAMP: $(date)" >> "$fault_record"
    
    # Inject fault based on type
    case "$FAULT_TYPE" in
        disk-fill)
            inject_disk_fill >> "$fault_record" 2>&1
            ;;
        port-block)
            inject_port_block >> "$fault_record" 2>&1
            ;;
        docker-kill)
            inject_docker_kill >> "$fault_record" 2>&1
            ;;
        marker-remove)
            inject_marker_remove >> "$fault_record" 2>&1
            ;;
        log-corrupt)
            inject_log_corrupt >> "$fault_record" 2>&1
            ;;
        *)
            log_error "Unknown fault type: $FAULT_TYPE"
            echo "ERROR: Unknown fault type: $FAULT_TYPE" >> "$fault_record"
            exit 1
            ;;
    esac
    
    log_info "Fault injection completed, record saved to: $fault_record"
    log_warning "System is now in a faulty state, ready for recovery testing"
    
    return 0
}

# Execute main function
main
