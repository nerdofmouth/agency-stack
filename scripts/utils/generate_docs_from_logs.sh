#!/bin/bash
# generate_docs_from_logs.sh - Generate component documentation from installation logs
#
# Extracts useful information from component logs to generate or augment documentation
# Usage: ./generate_docs_from_logs.sh --component=NAME --log-file=PATH --output-file=PATH

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${SCRIPT_DIR}/common.sh"

# Default values
COMPONENT=""
LOG_FILE=""
OUTPUT_FILE=""
APPEND_MODE=false
TEMPLATE_DIR="${ROOT_DIR}/docs/templates"
CLIENT_ID="${CLIENT_ID:-default}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --component=*)
            COMPONENT="${1#*=}"
            shift
            ;;
        --log-file=*)
            LOG_FILE="${1#*=}"
            shift
            ;;
        --output-file=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --append)
            APPEND_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --component=NAME     Component name"
            echo "  --log-file=PATH      Path to component log file"
            echo "  --output-file=PATH   Path to output documentation file"
            echo "  --append             Append to existing documentation (default: overwrite)"
            echo "  --help               Show this help message"
            echo ""
            echo "Example:"
            echo "  $(basename "$0") --component=docker --log-file=/var/log/agency_stack/components/docker.log --output-file=docs/pages/components/docker.md"
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$COMPONENT" ]]; then
    log_error "Component name is required (--component=NAME)"
    exit 1
fi

if [[ -z "$LOG_FILE" ]]; then
    # Use default log file location if not specified
    LOG_FILE="/var/log/agency_stack/components/${COMPONENT}.log"
    log_info "Using default log file path: $LOG_FILE"
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    # Use default output file location if not specified
    OUTPUT_FILE="${ROOT_DIR}/docs/pages/components/${COMPONENT}.md"
    log_info "Using default output file path: $OUTPUT_FILE"
fi

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    log_warning "Log file not found: $LOG_FILE"
    log_info "Will generate documentation without log data"
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")" 2>/dev/null || true

# Function to extract installation path from logs
extract_install_path() {
    local log_file="$1"
    local component="$2"
    
    if [[ ! -f "$log_file" ]]; then
        echo "${INSTALL_DIR}/${component}"
        return
    fi
    
    # Look for installation directory in logs
    local install_path
    install_path=$(grep -E "INSTALL_DIR|Installing|installation directory" "$log_file" | grep -v "mkdir" | head -1 | grep -oE "/opt/[a-zA-Z0-9_/.-]+" || echo "")
    
    if [[ -z "$install_path" ]]; then
        # Fall back to default path
        echo "${INSTALL_DIR}/${component}"
    else
        echo "$install_path"
    fi
}

# Function to extract ports from logs
extract_ports() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "No port information available"
        return
    fi
    
    # Look for port assignments in logs
    local ports
    ports=$(grep -E "port |PORT |listening on|published|expose" "$log_file" | grep -oE "[0-9]{2,5}(/(tcp|udp))?" | sort -n | uniq)
    
    if [[ -z "$ports" ]]; then
        # Try to find docker-compose with port mappings
        local install_path
        install_path=$(extract_install_path "$log_file" "$COMPONENT")
        
        if [[ -f "${install_path}/config/docker-compose.yml" ]]; then
            ports=$(grep -E "ports|PORT" "${install_path}/config/docker-compose.yml" | grep -oE "[0-9]{2,5}:[0-9]{2,5}" | sort -n | uniq)
        fi
    fi
    
    if [[ -z "$ports" ]]; then
        echo "No port information available"
    else
        echo "$ports"
    fi
}

# Function to extract common errors from logs
extract_common_errors() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "No error information available"
        return
    fi
    
    # Look for error messages in logs
    local errors
    errors=$(grep -E "ERROR|failed|warning|could not|unable to|permission denied" "$log_file" | sort | uniq -c | sort -nr | head -5)
    
    if [[ -z "$errors" ]]; then
        echo "No common errors found"
    else
        echo "$errors"
    fi
}

# Function to extract restart methods from logs
extract_restart_methods() {
    local log_file="$1"
    local component="$2"
    
    if [[ ! -f "$log_file" ]]; then
        echo "make ${component}-restart"
        return
    fi
    
    # Look for restart commands in logs
    local restart_cmds
    restart_cmds=$(grep -E "restart|starting|docker-compose" "$log_file" | grep -E "docker|systemctl|service" | sort | uniq)
    
    if [[ -z "$restart_cmds" ]]; then
        # Default restart commands
        echo "make ${component}-restart"
        echo "cd \$(INSTALL_DIR) && docker-compose restart"
    else
        echo "$restart_cmds"
    fi
}

# Function to extract success messages from logs
extract_success_messages() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "No success messages available"
        return
    fi
    
    # Look for success messages in logs
    local success_msgs
    success_msgs=$(grep -E "SUCCESS|successfully|completed|ready|running" "$log_file" | sort | uniq | tail -5)
    
    if [[ -z "$success_msgs" ]]; then
        echo "No success messages found"
    else
        echo "$success_msgs"
    fi
}

# Generate documentation
generate_documentation() {
    local component="$1"
    local log_file="$2"
    local output_file="$3"
    local install_path
    local ports
    local common_errors
    local restart_methods
    local success_messages
    
    # Extract information from logs
    install_path=$(extract_install_path "$log_file" "$component")
    ports=$(extract_ports "$log_file")
    common_errors=$(extract_common_errors "$log_file")
    restart_methods=$(extract_restart_methods "$log_file" "$component")
    success_messages=$(extract_success_messages "$log_file")
    
    # Get component registry information
    local description=""
    if command -v "${SCRIPT_DIR}/registry_parser.sh" &>/dev/null; then
        description=$("${SCRIPT_DIR}/registry_parser.sh" --component "$component" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$description" ]]; then
        description="$component component for AgencyStack"
    fi
    
    # Check if template exists
    local template="${TEMPLATE_DIR}/component_template.md"
    local doc_content=""
    
    if [[ -f "$template" ]]; then
        # Use template
        doc_content=$(cat "$template")
        
        # Replace placeholders
        doc_content="${doc_content//COMPONENT_NAME/$component}"
        doc_content="${doc_content//COMPONENT_DESCRIPTION/$description}"
        doc_content="${doc_content//INSTALL_PATH/$install_path}"
        doc_content="${doc_content//COMPONENT_PORTS/$ports}"
        doc_content="${doc_content//COMMON_ERRORS/$common_errors}"
        doc_content="${doc_content//RESTART_METHODS/$restart_methods}"
        doc_content="${doc_content//SUCCESS_MESSAGES/$success_messages}"
    else
        # Create basic documentation
        doc_content="# ${component^}

## Overview

${description}

## Installation

The installation is handled by the \`install_${component}.sh\` script, which can be executed using:

\`\`\`bash
make ${component}
\`\`\`

## Paths

- Installation directory: \`${install_path}\`
- Configuration: \`${install_path}/config\`
- Data: \`${install_path}/data\`
- Logs: \`/var/log/agency_stack/components/${component}.log\`

## Ports

\`\`\`
${ports}
\`\`\`

## Common Issues and Troubleshooting

\`\`\`
${common_errors}
\`\`\`

## Restart Methods

\`\`\`bash
${restart_methods}
\`\`\`

## Usage

\`\`\`bash
# Install the component
make ${component}

# Check status
make ${component}-status

# View logs
make ${component}-logs

# Restart the component
make ${component}-restart
\`\`\`

## Successful Operation Signs

\`\`\`
${success_messages}
\`\`\`
"
    fi
    
    # Write documentation to output file
    if [[ "$APPEND_MODE" == "true" && -f "$output_file" ]]; then
        # Append to existing file
        log_info "Appending to existing documentation: $output_file"
        echo -e "\n\n<!-- Generated from logs on $(date) -->\n" >> "$output_file"
        echo "$doc_content" >> "$output_file"
    else
        # Create new file
        log_info "Creating new documentation: $output_file"
        echo "<!-- Generated from logs on $(date) -->" > "$output_file"
        echo "$doc_content" >> "$output_file"
    fi
    
    log_success "Documentation generated successfully: $output_file"
    return 0
}

# Main function
main() {
    log_info "Generating documentation for component: $COMPONENT"
    log_info "Log file: $LOG_FILE"
    log_info "Output file: $OUTPUT_FILE"
    
    # Create documentation templates directory if needed
    mkdir -p "$TEMPLATE_DIR" 2>/dev/null || true
    
    # Generate documentation
    generate_documentation "$COMPONENT" "$LOG_FILE" "$OUTPUT_FILE"
    
    log_success "Documentation generation completed successfully"
    return 0
}

# Execute main function
main
