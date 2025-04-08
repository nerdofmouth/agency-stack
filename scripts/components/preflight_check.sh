#!/bin/bash
# AgencyStack Pre-Flight Check Component
# Verifies system readiness against pre-installation checklist requirements

# Determine script path and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set up logging
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/preflight.log"
REPORT_FILE="${PWD}/pre_installation_report.md"
ERRORS=0
WARNINGS=0

# Function to initialize log directory and file
initialize_log() {
  # Create log directory if it doesn't exist
  if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
  fi
  
  # Initialize log file with header
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================" > "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] AgencyStack Pre-Flight Check Started" >> "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================" >> "$LOG_FILE"
  
  # Log script parameters
  log_info "Parameters: DOMAIN=$DOMAIN, INTERACTIVE=$INTERACTIVE, SKIP_PORTS=$SKIP_PORTS, SKIP_DNS=$SKIP_DNS, SKIP_SYSTEM=$SKIP_SYSTEM, SKIP_NETWORK=$SKIP_NETWORK, SKIP_SSH=$SKIP_SSH"
}

# Function to handle critical errors in non-interactive mode
handle_critical_error() {
  local error_message="$1"
  
  log_error "CRITICAL ERROR: $error_message"
  
  if [ "$INTERACTIVE" = false ]; then
    log_error "Aborting installation in non-interactive mode due to critical error"
    echo -e "${RED}${BOLD}🚫 CRITICAL ERROR: $error_message${NC}"
    echo -e "${RED}Installation aborted in non-interactive mode${NC}"
    exit 2
  else
    log_warning "Prompting user to continue despite critical error"
    echo -e "${RED}${BOLD}🚫 CRITICAL ERROR: $error_message${NC}"
    echo -e "${YELLOW}This issue must be resolved for successful installation${NC}"
    read -p "Do you want to continue anyway? This is not recommended. [y/N] " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
      log_info "User chose to abort installation"
      exit 2
    fi
    log_warning "User chose to continue despite critical error"
  fi
}

# Generate a comprehensive installation report
generate_report() {
  log_info "Generating pre-installation report at $REPORT_FILE"
  
  cat > "$REPORT_FILE" << EOF
# AgencyStack Pre-Installation Report
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

## Summary
- **Status:** $([ $ERRORS -gt 0 ] && echo "❌ Failed - Critical issues found" || [ $WARNINGS -gt 0 ] && echo "⚠️ Warning - Potential issues detected" || echo "✅ Ready for installation")
- **Errors:** $ERRORS
- **Warnings:** $WARNINGS

## System Details
- **Hostname:** $(hostname)
- **IP Address:** $(curl -s https://ipinfo.io/ip)
- **OS:** $(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
- **Kernel:** $(uname -r)
- **RAM:** $(free -h | awk '/^Mem:/ {print $2}')
- **Disk Space:** $(df -h / | awk 'NR==2 {print $4}') available

## Check Results
$(cat "$LOG_FILE" | grep -E '\[(ERROR|WARNING|SUCCESS|INFO)\]' | sed 's/\[[0-9-]\+ [0-9:]\+\] \[\([A-Z]\+\)\] /\1: /' | sed 's/ERROR: /❌ /' | sed 's/WARNING: /⚠️ /' | sed 's/SUCCESS: /✅ /' | sed 's/INFO: /📌 /')

## Recommendations
$([ $ERRORS -gt 0 ] && echo "### Critical Issues (Must Fix)\n$(cat "$LOG_FILE" | grep -E '\[ERROR\]' | sed 's/\[[0-9-]\+ [0-9:]\+\] \[ERROR\] /- /')\n" || echo "")
$([ $WARNINGS -gt 0 ] && echo "### Warnings (Recommended to Address)\n$(cat "$LOG_FILE" | grep -E '\[WARNING\]' | sed 's/\[[0-9-]\+ [0-9:]\+\] \[WARNING\] /- /')\n" || echo "")
$([ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ] && echo "✅ **All checks passed!** Your system is ready for AgencyStack installation." || echo "")

## Next Steps
- $([ $ERRORS -gt 0 ] && echo "Address the critical issues above before proceeding with installation" || [ $WARNINGS -gt 0 ] && echo "Consider addressing the warnings before installation, or proceed with caution" || echo "Run 'make install' to begin the AgencyStack installation")
- Review the [full pre-installation checklist](./docs/PRE_INSTALLATION_CHECKLIST.md) for any manual checks
- For custom deployments, see [advanced configuration options](./docs/pages/advanced-config.md)

EOF

  log_success "Pre-installation report generated successfully at $REPORT_FILE"
  echo -e "${GREEN}✅ Pre-installation report generated at: $REPORT_FILE${NC}"
}

# Display welcome message and script purpose
welcome_message() {
  echo ""
  echo -e "${MAGENTA}${BOLD}🔍 AgencyStack Pre-Flight Verification${NC}"
  echo -e "${BLUE}This script will verify your system against the pre-installation checklist${NC}"
  echo -e "${BLUE}==============================================${NC}"
  echo ""
  
  log_info "Starting pre-flight verification with domain: $DOMAIN"
}

# Create our own logging functions
init_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting preflight_check.sh"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}

log_warning() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "$LOG_FILE"
}

log_section() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1: $2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
}

log_section_end() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
}

# Default values
INTERACTIVE=true
DOMAIN=""
SKIP_PORTS=false
SKIP_DNS=false
SKIP_SYSTEM=false
SKIP_NETWORK=false
SKIP_SSH=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --non-interactive)
      INTERACTIVE=false
      shift
      ;;
    --skip-ports)
      SKIP_PORTS=true
      shift
      ;;
    --skip-dns)
      SKIP_DNS=true
      shift
      ;;
    --skip-system)
      SKIP_SYSTEM=true
      shift
      ;;
    --skip-network)
      SKIP_NETWORK=true
      shift
      ;;
    --skip-ssh)
      SKIP_SSH=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Initialize logging
initialize_log

# Create the report file
echo "# AgencyStack Pre-Installation Verification Report" > "$REPORT_FILE"
echo "Date: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Track verification status
CRITICAL_ISSUES=0
WARNINGS=0

# Verify system requirements
check_system_requirements() {
  log_info "Checking system requirements..."
  echo "## System Requirements" >> "$REPORT_FILE"
  
  # Check OS type
  OS=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
  VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
  PRETTY_NAME=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
  
  if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    echo "✅ OS: $PRETTY_NAME (Recommended)" >> "$REPORT_FILE"
    log_success "OS check passed: $PRETTY_NAME"
  else
    echo "⚠️ OS: $PRETTY_NAME (Not officially supported)" >> "$REPORT_FILE"
    log_warning "OS check warning: $PRETTY_NAME is not officially supported"
    ((WARNINGS++))
  fi
  
  # Check RAM
  TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
  if [ "$TOTAL_RAM" -lt 8 ]; then
    echo "❌ RAM: ${TOTAL_RAM}GB (Minimum 8GB required, 16GB+ recommended)" >> "$REPORT_FILE"
    log_error "RAM check failed: Only ${TOTAL_RAM}GB available"
    ((CRITICAL_ISSUES++))
    handle_critical_error "Insufficient RAM (${TOTAL_RAM}GB) - Cannot proceed with installation"
  elif [ "$TOTAL_RAM" -lt 16 ]; then
    echo "⚠️ RAM: ${TOTAL_RAM}GB (16GB+ recommended for full stack)" >> "$REPORT_FILE"
    log_warning "RAM check warning: Only ${TOTAL_RAM}GB available"
    ((WARNINGS++))
  else
    echo "✅ RAM: ${TOTAL_RAM}GB" >> "$REPORT_FILE"
    log_success "RAM check passed: ${TOTAL_RAM}GB available"
  fi
  
  # Check disk space
  DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
  if (( $(echo "$DISK_SPACE < 50" | bc -l) )); then
    echo "❌ Disk Space: ${DISK_SPACE}GB (Minimum 50GB required, 100GB+ recommended)" >> "$REPORT_FILE"
    log_error "Disk space check failed: Only ${DISK_SPACE}GB available"
    ((CRITICAL_ISSUES++))
    handle_critical_error "Insufficient disk space (${DISK_SPACE}GB) - Cannot proceed with installation"
  elif (( $(echo "$DISK_SPACE < 100" | bc -l) )); then
    echo "⚠️ Disk Space: ${DISK_SPACE}GB (100GB+ recommended for full stack)" >> "$REPORT_FILE"
    log_warning "Disk space check warning: Only ${DISK_SPACE}GB available"
    ((WARNINGS++))
  else
    echo "✅ Disk Space: ${DISK_SPACE}GB" >> "$REPORT_FILE"
    log_success "Disk space check passed: ${DISK_SPACE}GB available"
  fi
  
  # Check sudo access
  if sudo -v &>/dev/null; then
    echo "✅ Root/sudo access: Available" >> "$REPORT_FILE"
    log_success "Sudo access check passed"
  else
    echo "❌ Root/sudo access: Not available" >> "$REPORT_FILE"
    log_error "Sudo access check failed"
    ((CRITICAL_ISSUES++))
    handle_critical_error "No root/sudo access - Cannot proceed with installation"
  fi
}

# Verify network requirements
check_network_requirements() {
  if [ "$SKIP_NETWORK" = true ]; then
    return 0
  fi
  
  log_info "Checking network requirements..."
  echo "" >> "$REPORT_FILE"
  echo "## Network Requirements" >> "$REPORT_FILE"
  
  # Check if there's a public static IP
  PUBLIC_IP=$(curl -s https://ipinfo.io/ip)
  if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Public IP: Could not detect" >> "$REPORT_FILE"
    log_error "Public IP check failed: Could not detect"
    ((CRITICAL_ISSUES++))
    handle_critical_error "No public IP detected - Cannot proceed with installation"
  else
    echo "✅ Public IP: $PUBLIC_IP" >> "$REPORT_FILE"
    log_success "Public IP check passed: $PUBLIC_IP"
  fi
  
  # Verify domain configuration if provided
  if [ -n "$DOMAIN" ] && [ "$SKIP_DNS" = false ]; then
    DOMAIN_IP=$(dig +short "$DOMAIN" | head -n1)
    if [ -z "$DOMAIN_IP" ]; then
      echo "❌ Domain: $DOMAIN does not resolve to any IP" >> "$REPORT_FILE"
      log_error "Domain check failed: $DOMAIN does not resolve to any IP"
      ((CRITICAL_ISSUES++))
      handle_critical_error "Domain $DOMAIN does not resolve to any IP - Cannot proceed with installation"
    elif [ "$DOMAIN_IP" = "$PUBLIC_IP" ]; then
      echo "✅ Domain: $DOMAIN correctly points to $PUBLIC_IP" >> "$REPORT_FILE"
      log_success "Domain check passed: $DOMAIN points to $PUBLIC_IP"
    else
      echo "❌ Domain: $DOMAIN points to $DOMAIN_IP, not to this server's IP ($PUBLIC_IP)" >> "$REPORT_FILE"
      log_error "Domain check failed: $DOMAIN points to $DOMAIN_IP, not to $PUBLIC_IP"
      ((CRITICAL_ISSUES++))
      handle_critical_error "Domain $DOMAIN points to $DOMAIN_IP, not to $PUBLIC_IP - Cannot proceed with installation"
    fi
  elif [ -z "$DOMAIN" ]; then
    echo "❌ Domain: Not provided" >> "$REPORT_FILE"
    log_error "Domain check failed: No domain provided"
    ((CRITICAL_ISSUES++))
    handle_critical_error "No domain provided - Cannot proceed with installation"
  fi
  
  # Check required ports if requested
  if [ "$SKIP_PORTS" = false ]; then
    echo "" >> "$REPORT_FILE"
    echo "### Port Availability" >> "$REPORT_FILE"
    
    REQUIRED_PORTS=(80 443 22 9443)
    for PORT in "${REQUIRED_PORTS[@]}"; do
      # Check if port is currently in use
      if netstat -tuln | grep -q ":$PORT "; then
        echo "⚠️ Port $PORT: Already in use" >> "$REPORT_FILE"
        log_warning "Port $PORT is already in use"
        ((WARNINGS++))
      else
        echo "✅ Port $PORT: Available" >> "$REPORT_FILE"
        log_success "Port $PORT is available"
      fi
    done
    
    # Check if ports are blocked by firewall
    if command -v nmap &>/dev/null; then
      if [ -n "$PUBLIC_IP" ]; then
        for PORT in "${REQUIRED_PORTS[@]}"; do
          if nmap -p "$PORT" "$PUBLIC_IP" | grep -q "open"; then
            echo "✅ Port $PORT: Open from external" >> "$REPORT_FILE"
            log_success "Port $PORT is open from external"
          else
            echo "⚠️ Port $PORT: Not accessible from external" >> "$REPORT_FILE"
            log_warning "Port $PORT is not accessible from external"
            ((WARNINGS++))
          fi
        done
      fi
    else
      echo "⚠️ Cannot verify external port access (nmap not installed)" >> "$REPORT_FILE"
      log_warning "Cannot verify external port access (nmap not installed)"
      ((WARNINGS++))
    fi
  fi
}

# Check SSH configuration
check_ssh_configuration() {
  if [ "$SKIP_SSH" = true ]; then
    return 0
  fi
  
  log_info "Checking SSH configuration..."
  echo "" >> "$REPORT_FILE"
  echo "## SSH Configuration" >> "$REPORT_FILE"
  
  # Check if SSH is using key-based authentication
  if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
    echo "⚠️ Password-based SSH authentication is enabled (consider disabling)" >> "$REPORT_FILE"
    log_warning "SSH check warning: Password-based SSH authentication is enabled"
    ((WARNINGS++))
  else
    echo "✅ Password-based SSH authentication is properly disabled" >> "$REPORT_FILE"
    log_success "SSH check passed: Password-based authentication is disabled"
  fi
  
  # Check if SSH keys are configured for the current user
  if [ ! -f "$HOME/.ssh/authorized_keys" ] || [ ! -s "$HOME/.ssh/authorized_keys" ]; then
    echo "⚠️ No SSH authorized keys found for current user" >> "$REPORT_FILE"
    log_warning "SSH check warning: No authorized keys found for current user"
    ((WARNINGS++))
  else
    echo "✅ SSH key-based authentication is configured" >> "$REPORT_FILE"
    log_success "SSH check passed: Key-based authentication is configured"
  fi
}

# Function to check dashboard accessibility and Traefik integration
check_dashboard_accessibility() {
  log_section "Dashboard Accessibility & Traefik Integration" "Verifying dashboard access and Traefik configuration"
  
  # Check if Traefik is installed and running
  if command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q 'traefik'; then
    log_success "Traefik container is running"
    
    # Check if Traefik is exposing port 80/443
    if docker ps --format '{{.Ports}}' | grep -q '80->80/tcp' && docker ps --format '{{.Ports}}' | grep -q '443->443/tcp'; then
      log_success "Traefik is properly exposing HTTP/HTTPS ports"
    else
      log_warning "Traefik may not be properly exposing HTTP/HTTPS ports"
      ((WARNINGS++))
    fi
    
    # Try to get Traefik dashboard status if configured
    if [ -n "$DOMAIN" ]; then
      # Check if dashboard domain is accessible
      if curl -s -o /dev/null -w "%{http_code}" "https://dashboard.$DOMAIN" &>/dev/null; then
        log_success "Dashboard domain is accessible at https://dashboard.$DOMAIN"
      else
        log_warning "Dashboard domain (https://dashboard.$DOMAIN) is not accessible"
        ((WARNINGS++))
      fi
    else
      log_info "Domain not specified - skipping dashboard domain accessibility check"
    fi
    
    # Check Traefik configuration files
    if [ -f "/opt/agency_stack/clients/default/traefik/traefik.yml" ]; then
      log_success "Traefik configuration file exists"
      
      # Check if dashboard is enabled in config
      if grep -q "dashboard: true" "/opt/agency_stack/clients/default/traefik/traefik.yml"; then
        log_success "Traefik dashboard is enabled in configuration"
      else
        log_warning "Traefik dashboard may not be enabled in configuration"
        ((WARNINGS++))
      fi
    else
      log_info "Traefik configuration file not found - may not be installed yet"
    fi
  else
    log_info "Traefik is not installed yet - skipping dashboard integration check"
  fi
  
  log_section_end
}

# Verify preparation tasks
check_preparation_tasks() {
  log_info "Checking preparation tasks..."
  echo "" >> "$REPORT_FILE"
  echo "## Preparation Tasks" >> "$REPORT_FILE"
  
  # Check if system is up to date
  log_info "Checking if system packages are up to date..."
  
  # Get update time for apt package lists
  APT_UPDATE_TIME=$(stat -c %Y /var/lib/apt/lists 2>/dev/null || echo 0)
  CURRENT_TIME=$(date +%s)
  DAYS_SINCE_UPDATE=$(( (CURRENT_TIME - APT_UPDATE_TIME) / 86400 ))
  
  if [ "$DAYS_SINCE_UPDATE" -gt 7 ]; then
    echo "⚠️ System updates: Last apt update was $DAYS_SINCE_UPDATE days ago" >> "$REPORT_FILE"
    log_warning "System updates check warning: Last apt update was $DAYS_SINCE_UPDATE days ago"
    ((WARNINGS++))
  else
    echo "✅ System updates: apt update ran within the last week" >> "$REPORT_FILE"
    log_success "System updates check passed: apt update ran recently"
  fi
  
  # Check hostname configuration
  HOSTNAME=$(hostname)
  if [[ "$HOSTNAME" == "localhost" ]]; then
    echo "⚠️ Hostname: Set to default ($HOSTNAME)" >> "$REPORT_FILE"
    log_warning "Hostname check warning: Using default hostname"
    ((WARNINGS++))
  else
    echo "✅ Hostname: Configured ($HOSTNAME)" >> "$REPORT_FILE"
    log_success "Hostname check passed: $HOSTNAME"
  fi
  
  # Check timezone configuration
  TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
  if [ -z "$TIMEZONE" ]; then
    echo "⚠️ Timezone: Not configured" >> "$REPORT_FILE"
    log_warning "Timezone check warning: Not configured"
    ((WARNINGS++))
  else
    echo "✅ Timezone: Configured ($TIMEZONE)" >> "$REPORT_FILE"
    log_success "Timezone check passed: $TIMEZONE"
  fi
}

# Main function
main() {
  log_info "Starting pre-installation verification..."
  
  if [ "$SKIP_SYSTEM" = false ]; then
    check_system_requirements
  fi
  
  check_network_requirements
  check_ssh_configuration
  check_preparation_tasks
  check_dashboard_accessibility
  
  # Add summary to report
  echo "" >> "$REPORT_FILE"
  echo "## Summary" >> "$REPORT_FILE"
  echo "- Critical Issues: $CRITICAL_ISSUES" >> "$REPORT_FILE"
  echo "- Warnings: $WARNINGS" >> "$REPORT_FILE"
  
  if [ "$CRITICAL_ISSUES" -gt 0 ]; then
    echo "" >> "$REPORT_FILE"
    echo "⚠️ **Critical issues detected that may prevent successful installation.**" >> "$REPORT_FILE"
    echo "Please resolve these issues before proceeding with installation." >> "$REPORT_FILE"
    
    log_error "Pre-installation verification completed with $CRITICAL_ISSUES critical issues and $WARNINGS warnings"
    log_info "See report at $REPORT_FILE"
    
    if [ "$INTERACTIVE" = true ]; then
      echo ""
      echo "Pre-installation verification completed with critical issues."
      echo "Please review the report at $REPORT_FILE and resolve issues before proceeding."
      read -p "Continue anyway? [y/N] " continue_anyway
      if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
      fi
    else
      exit 1
    fi
  elif [ "$WARNINGS" -gt 0 ]; then
    echo "" >> "$REPORT_FILE"
    echo "⚠️ **Warnings detected that should be addressed for optimal operation.**" >> "$REPORT_FILE"
    echo "Consider resolving these issues before proceeding with installation." >> "$REPORT_FILE"
    
    log_warning "Pre-installation verification completed with $WARNINGS warnings"
    log_info "See report at $REPORT_FILE"
    
    if [ "$INTERACTIVE" = true ]; then
      echo ""
      echo "Pre-installation verification completed with warnings."
      echo "Please review the report at $REPORT_FILE."
      read -p "Continue with installation? [Y/n] " continue_install
      if [[ "$continue_install" =~ ^[Nn]$ ]]; then
        exit 0
      fi
    fi
  else
    echo "" >> "$REPORT_FILE"
    echo "✅ **All checks passed. System is ready for AgencyStack installation.**" >> "$REPORT_FILE"
    
    log_success "Pre-installation verification completed successfully"
    log_info "See report at $REPORT_FILE"
    
    echo ""
    echo "Pre-installation verification completed successfully."
    echo "System is ready for AgencyStack installation."
  fi
  
  return 0
}

# Run main function
main
exit $?
