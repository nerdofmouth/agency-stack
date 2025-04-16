#!/bin/bash
# prepare_vm_snapshot.sh - Prepare VM for snapshot distribution
#
# Performs cleanup and hardening before creating a VM snapshot for distribution
# Usage: sudo ./prepare_vm_snapshot.sh [--skip-ssh-hardening] [--skip-log-cleanup]

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${ROOT_DIR}/scripts/utils/common.sh"
source "${ROOT_DIR}/scripts/utils/log_helpers.sh"

# Default settings
SKIP_SSH_HARDENING=false
SKIP_LOG_CLEANUP=false
SKIP_HISTORY_CLEANUP=false
SKIP_TEMP_CLEANUP=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-ssh-hardening)
            SKIP_SSH_HARDENING=true
            shift
            ;;
        --skip-log-cleanup)
            SKIP_LOG_CLEANUP=true
            shift
            ;;
        --skip-history-cleanup)
            SKIP_HISTORY_CLEANUP=true
            shift
            ;;
        --skip-temp-cleanup)
            SKIP_TEMP_CLEANUP=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: sudo $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-ssh-hardening    Skip SSH hardening steps"
            echo "  --skip-log-cleanup      Skip log file cleanup"
            echo "  --skip-history-cleanup  Skip shell history cleanup"
            echo "  --skip-temp-cleanup     Skip temporary files cleanup"
            echo "  --verbose               Show detailed output"
            echo "  --help                  Show this help message"
            echo ""
            echo "Example:"
            echo "  sudo $(basename "$0") --verbose"
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root. Please use sudo."
    exit 1
fi

# Function to clean up temporary files
cleanup_temp_files() {
    log_banner "Cleaning Temporary Files"
    
    if [[ "$SKIP_TEMP_CLEANUP" == "true" ]]; then
        log_warning "Temporary files cleanup skipped as requested"
        return 0
    fi
    
    log_info "Cleaning up /tmp directory"
    find /tmp -type f -delete
    
    log_info "Cleaning up /var/tmp directory"
    find /var/tmp -type f -delete
    
    log_info "Removing package caches"
    apt-get clean
    
    log_success "Temporary files cleanup completed"
    return 0
}

# Function to clean up log files
cleanup_log_files() {
    log_banner "Cleaning Log Files"
    
    if [[ "$SKIP_LOG_CLEANUP" == "true" ]]; then
        log_warning "Log files cleanup skipped as requested"
        return 0
    fi
    
    log_info "Preserving log file structure but clearing content"
    
    # Create log directory if it doesn't exist
    mkdir -p /var/log/agency_stack
    
    # Find log files and truncate them
    find /var/log -type f -name "*.log" -exec truncate --size=0 {} \;
    find /var/log -type f -name "*.gz" -delete
    
    # Create a timestamp marker in the AgencyStack log directory
    echo "Logs cleared during VM snapshot preparation on $(date)" > /var/log/agency_stack/log_reset_marker.txt
    
    log_success "Log files cleanup completed"
    return 0
}

# Function to clean up shell history
cleanup_shell_history() {
    log_banner "Cleaning Shell History"
    
    if [[ "$SKIP_HISTORY_CLEANUP" == "true" ]]; then
        log_warning "Shell history cleanup skipped as requested"
        return 0
    fi
    
    log_info "Clearing shell history files"
    
    # Find all user home directories and clear history files
    find /home -maxdepth 1 -mindepth 1 -type d | while read -r user_home; do
        log_info "Clearing history for user directory: $user_home"
        rm -f "${user_home}/.bash_history" "${user_home}/.zsh_history" "${user_home}/.history"
        touch "${user_home}/.bash_history" "${user_home}/.zsh_history"
    done
    
    # Clear root history as well
    rm -f /root/.bash_history /root/.zsh_history /root/.history
    touch /root/.bash_history /root/.zsh_history
    
    log_success "Shell history cleanup completed"
    return 0
}

# Function to harden SSH configuration
harden_ssh() {
    log_banner "Hardening SSH Configuration"
    
    if [[ "$SKIP_SSH_HARDENING" == "true" ]]; then
        log_warning "SSH hardening skipped as requested"
        return 0
    fi
    
    local ssh_config="/etc/ssh/sshd_config"
    local made_changes=false
    
    if [[ ! -f "$ssh_config" ]]; then
        log_warning "SSH config file not found: $ssh_config"
        return 1
    fi
    
    log_info "Backing up original SSH config"
    cp "$ssh_config" "${ssh_config}.bak.$(date +%Y%m%d%H%M%S)"
    
    # Disable root login
    if grep -q "^PermitRootLogin" "$ssh_config"; then
        log_info "Updating PermitRootLogin setting"
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
        made_changes=true
    else
        log_info "Adding PermitRootLogin setting"
        echo "PermitRootLogin no" >> "$ssh_config"
        made_changes=true
    fi
    
    # Disable password authentication
    if grep -q "^PasswordAuthentication" "$ssh_config"; then
        log_info "Updating PasswordAuthentication setting"
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config"
        made_changes=true
    else
        log_info "Adding PasswordAuthentication setting"
        echo "PasswordAuthentication no" >> "$ssh_config"
        made_changes=true
    fi
    
    # Enable public key authentication
    if grep -q "^PubkeyAuthentication" "$ssh_config"; then
        log_info "Updating PubkeyAuthentication setting"
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$ssh_config"
        made_changes=true
    else
        log_info "Adding PubkeyAuthentication setting"
        echo "PubkeyAuthentication yes" >> "$ssh_config"
        made_changes=true
    fi
    
    if [[ "$made_changes" == "true" ]]; then
        log_info "Restarting SSH service to apply changes"
        systemctl restart sshd
        log_success "SSH hardening completed"
    else
        log_info "No changes needed for SSH configuration"
    fi
    
    return 0
}

# Function to create installation snapshot
create_install_snapshot() {
    log_banner "Creating Installation Snapshot"
    
    # Create snapshot directory
    local snapshot_dir="/opt/agency_stack/snapshot"
    mkdir -p "$snapshot_dir"
    
    # Create timestamp marker
    echo "Snapshot created on: $(date)" > "${snapshot_dir}/snapshot_timestamp.txt"
    
    # Create list of installed components
    log_info "Creating installed components list"
    find /opt/agency_stack/clients -name ".installed_ok" | sort > "${snapshot_dir}/installed_components.txt"
    
    # Generate system info
    log_info "Capturing system information"
    {
        echo "=== System Information ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)"
        echo "Memory: $(free -h | grep "Mem:" | awk '{print $2}')"
        echo "Disk: $(df -h / | awk 'NR==2 {print $2}')"
        echo ""
        echo "=== Docker Information ==="
        if command -v docker &>/dev/null; then
            docker --version
            docker-compose --version
            echo ""
            echo "Running containers:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "Docker not installed"
        fi
        echo ""
        echo "=== AgencyStack Information ==="
        echo "Installation directory: /opt/agency_stack"
        echo "Components installed: $(find /opt/agency_stack/clients -name ".installed_ok" | wc -l)"
    } > "${snapshot_dir}/system_info.txt"
    
    # Create a healthstamp file
    log_info "Creating healthstamp file"
    {
        echo "AgencyStack Healthstamp"
        echo "======================="
        echo "Generated: $(date)"
        echo "Uptime: $(uptime)"
        echo ""
        echo "Component Status:"
        
        # Get all components with .installed_ok marker
        find /opt/agency_stack/clients -name ".installed_ok" | while read -r marker; do
            component_dir=$(dirname "$marker")
            component_name=$(basename "$component_dir")
            
            # Check if component is running (using docker)
            if docker ps | grep -q "$component_name"; then
                echo "$component_name: Running"
            else
                echo "$component_name: Installed but not running"
            fi
        done
    } > "${snapshot_dir}/healthstamp.txt"
    
    # Package permission check
    log_info "Setting correct permissions"
    chmod -R 750 "$snapshot_dir"
    
    log_success "Installation snapshot created successfully at: $snapshot_dir"
    return 0
}

# Main function
main() {
    log_banner "AgencyStack VM Snapshot Preparation"
    log_info "Starting snapshot preparation: $(date)"
    
    # Perform cleanup and hardening
    cleanup_temp_files
    cleanup_log_files
    cleanup_shell_history
    harden_ssh
    create_install_snapshot
    
    log_banner "Snapshot Preparation Complete"
    log_success "VM is now ready for snapshot capture"
    log_warning "Remember to shut down the VM before taking a snapshot"
    
    # Instructions for snapshot and distribution
    cat << EOF

============================================================================
AgencyStack VM Snapshot Instructions
============================================================================

The VM is now prepared for snapshot capture. Follow these steps:

1. Shut down the VM:
   $ sudo shutdown -h now

2. Take a snapshot of the VM in your virtualization platform

3. Start the VM from the snapshot

4. Verify the installation:
   $ cd /opt/agency_stack/repo
   $ make alpha-check

The snapshot is now ready for distribution.

Snapshot metadata is available at: /opt/agency_stack/snapshot/

============================================================================
EOF

    return 0
}

# Execute main function
main
