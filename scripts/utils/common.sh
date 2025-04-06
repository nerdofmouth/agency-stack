#!/bin/bash
# =============================================================================
# common.sh
#
# Common utility functions for AgencyStack scripts
# =============================================================================

# Log levels: INFO, WARNING, ERROR, DEBUG
LOG_LEVEL="INFO"

# Get the log directory
LOG_DIR="/var/log/agency_stack"
mkdir -p "${LOG_DIR}"

# Log a message to stdout and optionally to a log file
# Usage: log "INFO" "Message"
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Define colors for different log levels
    local COLOR_INFO="\033[0;32m"    # Green
    local COLOR_WARNING="\033[0;33m" # Yellow
    local COLOR_ERROR="\033[0;31m"   # Red
    local COLOR_DEBUG="\033[0;36m"   # Cyan
    local COLOR_RESET="\033[0m"
    
    # Select color based on log level
    local color=""
    case "$level" in
        "INFO")     color="$COLOR_INFO" ;;
        "WARNING")  color="$COLOR_WARNING" ;;
        "ERROR")    color="$COLOR_ERROR" ;;
        "DEBUG")    color="$COLOR_DEBUG" ;;
        *)          color="$COLOR_RESET" ;;
    esac
    
    # Print to stdout with color
    echo -e "${color}[${timestamp}] [${level}] ${message}${COLOR_RESET}"
    
    # Log to file if a log file is specified
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a directory exists
dir_exists() {
    [[ -d "$1" ]]
}

# Check if a file exists
file_exists() {
    [[ -f "$1" ]]
}

# Get value from JSON file using jq
# Usage: get_json_value "file.json" ".key.subkey"
get_json_value() {
    local file="$1"
    local query="$2"
    
    if ! command_exists jq; then
        log "ERROR" "jq is not installed. Please install jq first."
        return 1
    fi
    
    if ! file_exists "$file"; then
        log "ERROR" "JSON file not found: $file"
        return 1
    fi
    
    jq -r "$query" "$file" 2>/dev/null
}

# Validate domain format
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Confirm action with user
# Usage: confirm "Are you sure?" && echo "User confirmed"
confirm() {
    local prompt="$1"
    local response
    
    echo -n "$prompt [y/N] "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Send an alert via the alerting system
# Usage: send_alert "ERROR" "Service XYZ is down"
send_alert() {
    local level="$1"
    local message="$2"
    
    log "$level" "ALERT: $message"
    
    # Placeholder for actual alerting mechanism
    # This would be replaced with actual alert implementation
}
