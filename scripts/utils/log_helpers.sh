#!/bin/bash
# log_helpers.sh - Extended formatting and log file rotation tools
#
# Provides advanced logging functions beyond those in common.sh
# Usage: source "$(dirname "$0")/../utils/log_helpers.sh"

set -euo pipefail

# Import common utilities if not already sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(type -t log_info)" != "function" ]]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Default log settings
DEFAULT_LOG_DIR="/var/log/agency_stack"
MAX_LOG_SIZE_MB=10
MAX_LOG_FILES=5

# General-purpose log function for backwards compatibility
# This ensures existing component scripts continue to work
log() {
    local level="$1"
    local message="${2:-}"
    local display="${3:-$message}"
    
    case "$level" in
        "INFO")
            log_info "$message"
            if [[ -n "${display}" ]]; then
                echo -e "${display}"
            fi
            ;;
        "SUCCESS")
            log_success "$message"
            if [[ -n "${display}" ]]; then
                echo -e "${GREEN}✅ ${display}${NC}"
            fi
            ;;
        "WARNING")
            log_warning "$message"
            if [[ -n "${display}" ]]; then
                echo -e "${YELLOW}⚠️ ${display}${NC}"
            fi
            ;;
        "ERROR")
            log_error "$message"
            if [[ -n "${display}" ]]; then
                echo -e "${RED}❌ ${display}${NC}"
            fi
            ;;
        *)
            log_info "$message"
            if [[ -n "${display}" ]]; then
                echo -e "${display}"
            fi
            ;;
    esac
}

# Rotate a log file when it reaches the maximum size
rotate_log() {
    local log_file="$1"
    local max_size_mb="${2:-$MAX_LOG_SIZE_MB}"
    local max_files="${3:-$MAX_LOG_FILES}"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    # Get log file size in bytes
    local size
    size=$(stat -c %s "$log_file" 2>/dev/null || echo 0)
    
    # Convert to MB for comparison
    local size_mb
    size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
    
    # Check if rotation is needed
    if (( $(echo "$size_mb >= $max_size_mb" | bc -l) )); then
        log_info "Rotating log file: $log_file (size: ${size_mb}MB)"
        
        # Shift existing rotated logs
        for (( i=max_files-1; i>0; i-- )); do
            if [[ -f "${log_file}.${i}" ]]; then
                mv "${log_file}.${i}" "${log_file}.$((i+1))" 2>/dev/null || true
            fi
        done
        
        # Rotate current log
        mv "$log_file" "${log_file}.1" 2>/dev/null || true
        touch "$log_file" 2>/dev/null || true
        chmod 640 "$log_file" 2>/dev/null || true
        
        log_info "Log rotation completed for: $log_file"
    fi
}

# Create a log entry with timestamp and structured format
log_structured() {
    local level="$1"
    local component="$2"
    local message="$3"
    local log_file="${4:-}"
    
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Create structured log entry
    local log_entry="[${timestamp}] [${level}] [${component}] ${message}"
    
    # Output to console based on level
    case "$level" in
        INFO)
            echo -e "[${timestamp}] [${BLUE}${level}${NC}] [${component}] ${message}"
            ;;
        SUCCESS)
            echo -e "[${timestamp}] [${GREEN}${level}${NC}] [${component}] ${message}"
            ;;
        WARNING)
            echo -e "[${timestamp}] [${YELLOW}${level}${NC}] [${component}] ${message}"
            ;;
        ERROR)
            echo -e "[${timestamp}] [${RED}${level}${NC}] [${component}] ${message}" >&2
            ;;
        *)
            echo -e "[${timestamp}] [${level}] [${component}] ${message}"
            ;;
    esac
    
    # Log to file if specified
    if [[ -n "$log_file" ]]; then
        echo "$log_entry" >> "$log_file" 2>/dev/null || true
    fi
}

# Create a banner for major sections in logs
log_banner() {
    local title="$1"
    local log_file="${2:-}"
    local width=80
    
    # Create the banner
    local line
    line=$(printf '%*s' "$width" | tr ' ' '=')
    local centered_title
    centered_title=$(printf "%*s" $(( (width + ${#title}) / 2)) "$title")
    
    # Output to console
    echo -e "\n${BOLD}${line}${NC}"
    echo -e "${BOLD}${centered_title}${NC}"
    echo -e "${BOLD}${line}${NC}\n"
    
    # Log to file if specified
    if [[ -n "$log_file" ]]; then
        echo -e "\n${line}" >> "$log_file" 2>/dev/null || true
        echo -e "${centered_title}" >> "$log_file" 2>/dev/null || true
        echo -e "${line}\n" >> "$log_file" 2>/dev/null || true
    fi
}

# Create a summary report with success/failure counts
log_summary() {
    local title="$1"
    local success_count="$2"
    local warning_count="$3"
    local error_count="$4"
    local log_file="${5:-}"
    
    # Create the summary
    log_banner "$title" "$log_file"
    
    # Output to console
    echo -e "Summary of results:"
    echo -e "  ${GREEN}✓ Success:${NC} $success_count"
    echo -e "  ${YELLOW}⚠ Warnings:${NC} $warning_count"
    echo -e "  ${RED}✗ Errors:${NC} $error_count"
    echo ""
    
    # Log to file if specified
    if [[ -n "$log_file" ]]; then
        echo -e "Summary of results:" >> "$log_file" 2>/dev/null || true
        echo -e "  ✓ Success: $success_count" >> "$log_file" 2>/dev/null || true
        echo -e "  ⚠ Warnings: $warning_count" >> "$log_file" 2>/dev/null || true
        echo -e "  ✗ Errors: $error_count" >> "$log_file" 2>/dev/null || true
        echo "" >> "$log_file" 2>/dev/null || true
    fi
}

# Create a summary report with success/failure counts
log_summary() {
    local total="$1"
    local success="$2"
    local failed="$3"
    local title="${4:-Summary}"
    
    local success_rate=$((success * 100 / total))
    
    log_banner "$title"
    echo -e "  ${BOLD}Total:${NC} $total operations"
    echo -e "  ${GREEN}${BOLD}Successful:${NC} $success operations ($success_rate%)"
    
    if [[ "$failed" -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}Failed:${NC} $failed operations ($((100 - success_rate))%)"
    else
        echo -e "  ${GREEN}${BOLD}No failures!${NC}"
    fi
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$title] Total: $total, Success: $success, Failed: $failed, Rate: $success_rate%" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Log a command being executed with standardized formatting
log_cmd() {
    local command_desc="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${CYAN}CMD${NC}] ${command_desc}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [CMD] ${command_desc}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Archive old logs
archive_logs() {
    local log_dir="${1:-$DEFAULT_LOG_DIR}"
    local days_old="${2:-30}"
    local archive_dir="${3:-${log_dir}/archives}"
    
    # Create archive directory if it doesn't exist
    mkdir -p "$archive_dir" 2>/dev/null || true
    
    # Find logs older than specified days
    log_info "Finding logs older than $days_old days in $log_dir"
    
    # Create an archive name with timestamp
    local archive_name="logs_archive_$(date +%Y%m%d_%H%M%S).tar.gz"
    local archive_path="${archive_dir}/${archive_name}"
    
    # Find and compress old logs
    find "$log_dir" -type f -name "*.log*" -mtime +"$days_old" -print0 | 
    if xargs -0 -r tar czf "$archive_path" 2>/dev/null; then
        local archived_count
        archived_count=$(find "$log_dir" -type f -name "*.log*" -mtime +"$days_old" | wc -l)
        
        if [[ $archived_count -gt 0 ]]; then
            log_success "Archived $archived_count log files to $archive_path"
            
            # Remove the original logs after archiving
            find "$log_dir" -type f -name "*.log*" -mtime +"$days_old" -delete
            
            log_info "Removed original log files after archiving"
        else
            log_info "No log files found older than $days_old days"
            rm -f "$archive_path" 2>/dev/null || true
        fi
    else
        log_warning "No logs found to archive or archive failed"
        rm -f "$archive_path" 2>/dev/null || true
    fi
}

# Usage example
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Log Helpers for AgencyStack"
    echo "==========================="
    echo "This script provides utility functions for log management."
    echo "It should be sourced from other scripts, not run directly."
    echo ""
    echo "Example usage:"
    echo "  source log_helpers.sh"
    echo "  rotate_log /var/log/agency_stack/components/example.log"
    echo "  log_structured INFO example \"This is a test message\""
    echo "  log_banner \"Test Banner\""
    echo "  log_summary \"Test Summary\" 5 2 1"
    echo "  archive_logs /var/log/agency_stack 30"
    echo ""
    
    # Show example if requested
    if [[ "${1:-}" == "--example" ]]; then
        log_banner "Example Log Banner"
        log_structured "INFO" "example" "This is an info message"
        log_structured "SUCCESS" "example" "This is a success message"
        log_structured "WARNING" "example" "This is a warning message" 
        log_structured "ERROR" "example" "This is an error message"
        log_summary "Example Summary" 5 2 1
    fi
fi
