#!/bin/bash
# deploy_alpha.sh
# Alpha Deployment Script for AgencyStack on fresh VM
# Following AgencyStack Alpha Phase Repository Integrity Policy

# Define colors for output
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# Default values
CLIENT_ID="default"
DOMAIN="$(hostname -f)"
ADMIN_EMAIL="admin@example.com"
REPO_URL="https://github.com/nerdofmouth/agency-stack.git"
BRANCH="demo-core-test"
INSTALL_DIR="/opt/agency_stack"
LOG_FILE="/var/log/agency_stack_deploy.log"
DEBUG=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --client-id ID       Set client ID (default: default)"
            echo "  --domain DOMAIN      Set domain name (default: hostname)"
            echo "  --admin-email EMAIL  Set admin email (default: admin@example.com)"
            echo "  --repo-url URL       Set repository URL (default: GitHub AgencyStack)"
            echo "  --branch BRANCH      Set repository branch (default: demo-core-test)"
            echo "  --install-dir DIR    Set installation directory (default: /opt/agency_stack)"
            echo "  --debug              Enable debug output"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO")
            echo -e "[${timestamp}] [${CYAN}INFO${RESET}] ${message}"
            ;;
        "SUCCESS")
            echo -e "[${timestamp}] [${GREEN}SUCCESS${RESET}] ${message}"
            ;;
        "WARNING")
            echo -e "[${timestamp}] [${YELLOW}WARNING${RESET}] ${message}"
            ;;
        "ERROR")
            echo -e "[${timestamp}] [${RED}ERROR${RESET}] ${message}"
            ;;
        *)
            echo -e "[${timestamp}] [$level] ${message}"
            ;;
    esac
    
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Function to execute commands and log output
execute_cmd() {
    local cmd="$1"
    local msg="$2"
    local exit_on_error="${3:-true}"
    
    log "INFO" "Executing: $msg"
    if $DEBUG; then
        log "DEBUG" "Command: $cmd"
    fi
    
    # Execute command and capture output
    local output
    if ! output=$(eval "$cmd" 2>&1); then
        log "ERROR" "Command failed: $msg"
        log "ERROR" "Output: $output"
        if $exit_on_error; then
            exit 1
        else
            return 1
        fi
    fi
    
    if $DEBUG; then
        log "DEBUG" "Output: $output"
    fi
    
    log "SUCCESS" "$msg completed"
    return 0
}

# Function to check for required commands
check_required_commands() {
    log "INFO" "Checking for required commands..."
    
    local missing_commands=()
    for cmd in git curl sudo apt-get; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log "ERROR" "Missing required commands: ${missing_commands[*]}"
        log "INFO" "Installing required packages..."
        
        # Try to install missing commands if possible
        if command -v apt-get &> /dev/null; then
            execute_cmd "sudo apt-get update && sudo apt-get install -y git curl sudo" "Installing required packages" false
        else
            log "ERROR" "Cannot automatically install missing commands. Please install them manually."
            exit 1
        fi
        
        # Check again after installation attempt
        for cmd in "${missing_commands[@]}"; do
            if ! command -v "$cmd" &> /dev/null; then
                log "ERROR" "Command still missing after installation attempt: $cmd"
                exit 1
            fi
        done
    fi
    
    log "SUCCESS" "All required commands are available"
}

# Function to check if user has sudo access
check_sudo_access() {
    log "INFO" "Checking sudo access..."
    
    if ! sudo -n true 2>/dev/null; then
        log "WARNING" "You may be prompted for your sudo password during installation"
    else
        log "SUCCESS" "Sudo access confirmed"
    fi
}

# Function to clone/update repository
setup_repository() {
    log "INFO" "Setting up repository at $INSTALL_DIR..."
    
    # Create install directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        execute_cmd "sudo mkdir -p $INSTALL_DIR" "Creating installation directory"
        execute_cmd "sudo chown $(id -u):$(id -g) $INSTALL_DIR" "Setting directory permissions"
    fi
    
    # Check if repo already exists
    if [ -d "${INSTALL_DIR}/repo/.git" ]; then
        log "INFO" "Repository already exists, updating..."
        execute_cmd "cd ${INSTALL_DIR}/repo && git fetch origin && git checkout $BRANCH && git pull origin $BRANCH" "Updating repository to branch $BRANCH"
    else
        log "INFO" "Cloning repository..."
        execute_cmd "git clone $REPO_URL ${INSTALL_DIR}/repo" "Cloning repository"
        execute_cmd "cd ${INSTALL_DIR}/repo && git checkout $BRANCH" "Checking out branch $BRANCH"
    fi
    
    log "SUCCESS" "Repository setup completed"
}

# Function to prepare directories
prepare_directories() {
    log "INFO" "Preparing required directories..."
    
    execute_cmd "cd ${INSTALL_DIR}/repo && make prep-dirs" "Creating required directories"
    
    log "SUCCESS" "Directory preparation completed"
}

# Function to install prerequisites
install_prerequisites() {
    log "INFO" "Installing prerequisites..."
    
    execute_cmd "cd ${INSTALL_DIR}/repo && sudo make prerequisites DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL CLIENT_ID=$CLIENT_ID" "Installing system prerequisites"
    
    log "SUCCESS" "Prerequisites installation completed"
}

# Function to install core components
install_core_components() {
    log "INFO" "Installing core components..."
    
    execute_cmd "cd ${INSTALL_DIR}/repo && sudo make demo-core DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL CLIENT_ID=$CLIENT_ID" "Installing demo-core components"
    
    log "SUCCESS" "Core components installation completed"
}

# Function to verify installation
verify_installation() {
    log "INFO" "Verifying installation..."
    
    execute_cmd "cd ${INSTALL_DIR}/repo && sudo make demo-core-status" "Checking demo-core status" false
    
    # Check for installed_ok markers
    local total_components=$(find ${INSTALL_DIR}/clients/${CLIENT_ID} -name ".installed_ok" | wc -l)
    log "INFO" "Found $total_components components with .installed_ok markers"
    
    # Generate a summary report
    local report_file="${INSTALL_DIR}/alpha_deployment_report.md"
    echo "# AgencyStack Alpha Deployment Report" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    echo "## Deployment Summary" >> "$report_file"
    echo "" >> "$report_file"
    echo "- **Domain**: $DOMAIN" >> "$report_file"
    echo "- **Client ID**: $CLIENT_ID" >> "$report_file"
    echo "- **Installation Directory**: $INSTALL_DIR" >> "$report_file"
    echo "- **Deployment Time**: $(date)" >> "$report_file"
    echo "- **Components Installed**: $total_components" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check dashboard accessibility
    if [[ -f "${INSTALL_DIR}/clients/${CLIENT_ID}/dashboard/.installed_ok" ]]; then
        log "INFO" "Dashboard installed, checking accessibility..."
        if command -v curl &>/dev/null; then
            if curl -s -I "https://${DOMAIN}/dashboard/" &>/dev/null; then
                log "SUCCESS" "Dashboard is accessible at https://${DOMAIN}/dashboard/"
                echo "- **Dashboard**: [Accessible](https://${DOMAIN}/dashboard/)" >> "$report_file"
            else
                log "WARNING" "Dashboard might not be accessible at https://${DOMAIN}/dashboard/"
                echo "- **Dashboard**: Installed but not accessible via HTTPS" >> "$report_file"
            fi
        else
            log "WARNING" "curl not available, skipping dashboard accessibility check"
            echo "- **Dashboard**: Installed but accessibility not verified" >> "$report_file"
        fi
    else
        log "WARNING" "Dashboard not installed or .installed_ok marker missing"
        echo "- **Dashboard**: Not installed or marker missing" >> "$report_file"
    fi
    
    log "SUCCESS" "Verification completed, summary saved to $report_file"
}

# Main function
main() {
    echo -e "${BOLD}${CYAN}AgencyStack Alpha Deployment${RESET}"
    echo -e "Following AgencyStack Alpha Phase Repository Integrity Policy\n"
    
    log "INFO" "Starting AgencyStack deployment on $DOMAIN (Client ID: $CLIENT_ID)"
    
    check_required_commands
    check_sudo_access
    setup_repository
    prepare_directories
    install_prerequisites
    install_core_components
    verify_installation
    
    log "SUCCESS" "AgencyStack deployment completed successfully!"
    echo -e "\n${GREEN}${BOLD}✅ AgencyStack deployment completed!${RESET}"
    echo -e "${CYAN}Domain:${RESET} $DOMAIN"
    echo -e "${CYAN}Client ID:${RESET} $CLIENT_ID"
    echo -e "${CYAN}Installation directory:${RESET} $INSTALL_DIR"
    echo -e "\n${CYAN}Run 'sudo make demo-core-status' to check component status${RESET}"
    
    return 0
}

# Run main function
main
exit $?
