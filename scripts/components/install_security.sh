#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: security.sh
# Path: /scripts/components/install_security.sh
#

# Enforce containerization (prevent host contamination)

# install_security.sh - Security hardening for AgencyStack
# https://stack.nerdofmouth.com
#
# This script implements security measures for AgencyStack, including:
# - Firewall configuration (UFW)
# - SSH hardening
# - System security settings
# - File permissions audit
# - Security monitoring
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="security"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
TEST_MODE=false

# Security specific configuration
ENABLE_UFW=true
ENABLE_SSH_HARDENING=true
ENABLE_SYSTEM_HARDENING=true
ENABLE_AUDIT=true
SSH_PORT=22
UFW_PORTS=("22" "80" "443")
ADDITIONAL_UFW_PORTS=()

# Show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Installs and configures security measures for AgencyStack"
  echo
  echo "Options:"
  echo "  --domain DOMAIN            Domain name for the installation"
  echo "  --admin-email EMAIL        Admin email for notifications"
  echo "  --client-id ID             Client ID for multi-tenant setup"
  echo "  --ssh-port PORT            SSH port (default: 22)"
  echo "  --allow-ports PORTS        Additional ports to allow (comma separated)"
  echo "  --no-ufw                   Skip UFW firewall configuration"
  echo "  --no-ssh-harden            Skip SSH hardening"
  echo "  --no-system-harden         Skip system hardening"
  echo "  --no-audit                 Skip security audit"
  echo "  --force                    Force reinstallation even if already installed"
  echo "  --with-deps                Install dependencies if missing"
  echo "  --verbose                  Enable verbose output"
  echo "  --enable-cloud             Enable cloud storage backends"
  echo "  --enable-openai            Enable OpenAI API integration"
  echo "  --use-github               Use GitHub for repository operations"
  echo "  --test-mode                Enable test mode (skips SSH hardening, maintains remote access)"
  echo "  -h, --help                 Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --allow-ports)
      IFS=',' read -ra ADDITIONAL_UFW_PORTS <<< "$2"
      shift 2
      ;;
    --no-ufw)
      ENABLE_UFW=false
      shift
      ;;
    --no-ssh-harden)
      ENABLE_SSH_HARDENING=false
      shift
      ;;
    --no-system-harden)
      ENABLE_SYSTEM_HARDENING=false
      shift
      ;;
    --no-audit)
      ENABLE_AUDIT=false
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      ENABLE_SSH_HARDENING=false
      log "WARNING" "Test mode enabled - SSH hardening disabled" "${YELLOW}⚠️ Test mode enabled - SSH hardening disabled${NC}"
      shift
      ;;
    -h|--help)
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

# Setup logging
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")"
exec &> >(tee -a "${COMPONENT_LOG_FILE}")

# Log function
log() {
  local level="$1"
  local message="$2"
  local display="$3"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${COMPONENT_LOG_FILE}"
  if [[ -n "${display}" ]]; then
    echo -e "${display}"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  local json_data="$2"
  
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"component\":\"${COMPONENT}\",\"message\":\"${message}\",\"data\":${json_data}}" >> "${AGENCY_LOG_DIR}/integration.log"
}

log "INFO" "Starting security configuration" "${BLUE}Starting security configuration...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"

# Create necessary directories
mkdir -p "${COMPONENT_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${COMPONENT_CONFIG_DIR}"
mkdir -p "${INSTALL_DIR}/audit"

# Update SSH port in UFW_PORTS if changed
if [[ "${SSH_PORT}" != "22" ]]; then
  UFW_PORTS=("${SSH_PORT}" "80" "443")

# Check for existing security installation
if [[ -f "${COMPONENT_INSTALLED_MARKER}" ]] && [[ "${FORCE}" != "true" ]]; then
  log "INFO" "Security component already installed" "${GREEN}✅ Security component already installed.${NC}"
  
  # Exit if we're not forcing reinstallation
  if [[ "${FORCE}" != "true" ]]; then
    log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
    exit 0
  fi

# Check dependencies
if [[ "${ENABLE_UFW}" == "true" ]] && ! command -v ufw &> /dev/null; then
  log "INFO" "Installing UFW package" "${CYAN}Installing UFW package...${NC}"
  apt-get update >> "${INSTALL_LOG}" 2>&1
  apt-get install -y ufw >> "${INSTALL_LOG}" 2>&1

if [[ "${ENABLE_SYSTEM_HARDENING}" == "true" ]]; then
  log "INFO" "Installing security packages" "${CYAN}Installing security packages...${NC}"
  apt-get update >> "${INSTALL_LOG}" 2>&1
  apt-get install -y \
    unattended-upgrades \
    apt-listchanges \
    apticron \
    rkhunter \
    auditd \
    libpam-pwquality \
    debsums \
    needrestart >> "${INSTALL_LOG}" 2>&1

# Configure UFW
if [[ "${ENABLE_UFW}" == "true" ]]; then
  log "INFO" "Configuring UFW firewall" "${CYAN}Configuring UFW firewall...${NC}"
  
  # Reset UFW to default state
  log "INFO" "Resetting UFW to default state" "${CYAN}Resetting UFW to default state...${NC}"
  ufw --force reset >> "${INSTALL_LOG}" 2>&1
  
  # Set default policies
  log "INFO" "Setting default UFW policies" "${CYAN}Setting default UFW policies...${NC}"
  ufw default deny incoming >> "${INSTALL_LOG}" 2>&1
  ufw default allow outgoing >> "${INSTALL_LOG}" 2>&1
  
  # Allow required ports
  log "INFO" "Allowing required ports" "${CYAN}Allowing required ports...${NC}"
  for port in "${UFW_PORTS[@]}"; do
    if [[ "${port}" == "${SSH_PORT}" ]]; then
      log "INFO" "Allowing SSH on port ${port}" "${CYAN}Allowing SSH on port ${port}...${NC}"
      ufw allow "${port}"/tcp comment 'SSH' >> "${INSTALL_LOG}" 2>&1
    elif [[ "${port}" == "80" ]]; then
      log "INFO" "Allowing HTTP on port 80" "${CYAN}Allowing HTTP on port 80...${NC}"
      ufw allow 80/tcp comment 'HTTP' >> "${INSTALL_LOG}" 2>&1
    elif [[ "${port}" == "443" ]]; then
      log "INFO" "Allowing HTTPS on port 443" "${CYAN}Allowing HTTPS on port 443...${NC}"
      ufw allow 443/tcp comment 'HTTPS' >> "${INSTALL_LOG}" 2>&1
    else
      log "INFO" "Allowing custom port ${port}" "${CYAN}Allowing custom port ${port}...${NC}"
      ufw allow "${port}"/tcp comment 'Custom' >> "${INSTALL_LOG}" 2>&1
    fi
  done
  
  # Allow additional ports if specified
  if [[ ${#ADDITIONAL_UFW_PORTS[@]} -gt 0 ]]; then
    log "INFO" "Allowing additional ports" "${CYAN}Allowing additional ports...${NC}"
    for port in "${ADDITIONAL_UFW_PORTS[@]}"; do
      log "INFO" "Allowing additional port ${port}" "${CYAN}Allowing additional port ${port}...${NC}"
      ufw allow "${port}"/tcp comment 'Additional' >> "${INSTALL_LOG}" 2>&1
    done
  fi
  
  # Enable UFW
  log "INFO" "Enabling UFW" "${CYAN}Enabling UFW...${NC}"
  ufw --force enable >> "${INSTALL_LOG}" 2>&1
  
  # Verify UFW is active
  if ufw status | grep -q "Status: active"; then
    log "SUCCESS" "UFW is active" "${GREEN}✅ UFW is active.${NC}"
  else
    log "ERROR" "UFW failed to activate" "${RED}❌ UFW failed to activate.${NC}"
    exit 1
  fi
  
  # Save UFW rules to component directory
  ufw status verbose > "${COMPONENT_CONFIG_DIR}/ufw_rules.txt"

# SSH Hardening
if [[ "${ENABLE_SSH_HARDENING}" == "true" ]]; then
  log "INFO" "Hardening SSH configuration" "${CYAN}Hardening SSH configuration...${NC}"
  
  if [[ "${TEST_MODE}" == "true" ]]; then
    log "WARNING" "Test mode: Skipping SSH hardening" "${YELLOW}⚠️ Test mode: Skipping SSH hardening to maintain access${NC}"
  else
    # Backup original SSH config
    cp /etc/ssh/sshd_config "${COMPONENT_CONFIG_DIR}/sshd_config.original"
    
    # Create hardened SSH config
    cat > /etc/ssh/sshd_config.d/00-hardened.conf <<EOL
# Hardened SSH Configuration for AgencyStack
# Generated on $(date)

# Basic SSH Settings
Port ${SSH_PORT}
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication Settings
LoginGraceTime 30
PermitRootLogin prohibit-password
StrictModes yes
MaxAuthTries 4
MaxSessions 10

# Key-based Authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password Authentication
PasswordAuthentication yes
PermitEmptyPasswords no

# Other Security Settings
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection Settings
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3

# Logging Settings
SyslogFacility AUTH
LogLevel VERBOSE
EOL

    # Change permissions on SSH config
    chmod 644 /etc/ssh/sshd_config.d/00-hardened.conf
    
    # Restart SSH to apply changes
    log "INFO" "Restarting SSH service" "${CYAN}Restarting SSH service...${NC}"
    systemctl restart ssh >> "${INSTALL_LOG}" 2>&1
    
    # Check SSH service status
    if systemctl is-active --quiet ssh; then
      log "SUCCESS" "SSH service restarted with hardened configuration" "${GREEN}✅ SSH service restarted with hardened configuration.${NC}"
    else
      log "ERROR" "SSH service failed to restart" "${RED}❌ SSH service failed to restart. Reverting changes...${NC}"
      
      # Revert changes if SSH failed to restart
      rm /etc/ssh/sshd_config.d/00-hardened.conf
      systemctl restart ssh
      
      log "INFO" "SSH configuration restored to original" "${YELLOW}⚠️ SSH configuration restored to original.${NC}"
    fi
    
    # Save SSH configuration to component directory
    cp /etc/ssh/sshd_config.d/00-hardened.conf "${COMPONENT_CONFIG_DIR}/sshd_config.hardened"
  fi

# System Hardening
if [[ "${ENABLE_SYSTEM_HARDENING}" == "true" ]]; then
  log "INFO" "Applying system hardening measures" "${CYAN}Applying system hardening measures...${NC}"
  
  # Configure automatic security updates
  log "INFO" "Configuring automatic security updates" "${CYAN}Configuring automatic security updates...${NC}"
  
  # Create unattended-upgrades configuration
  cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOL
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

// List of packages to not upgrade
Unattended-Upgrade::Package-Blacklist {
};

// Send email to this address for problems or packages upgrades
Unattended-Upgrade::Mail "${ADMIN_EMAIL}";

// Always send email when there are errors
Unattended-Upgrade::MailOnlyOnError "false";

// Remove unused automatically installed kernel-related packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused automatically installed dependency packages
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot if required
Unattended-Upgrade::Automatic-Reboot "true";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOL

  # Enable unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOL

  # Configure sysctl security settings
  log "INFO" "Configuring sysctl security settings" "${CYAN}Configuring sysctl security settings...${NC}"
  
  cat > /etc/sysctl.d/99-security.conf <<EOL
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 0
EOL

  # Apply sysctl settings
  sysctl -p /etc/sysctl.d/99-security.conf >> "${INSTALL_LOG}" 2>&1
  
  # Configure password policies
  log "INFO" "Configuring password policies" "${CYAN}Configuring password policies...${NC}"
  
  # Create password quality configuration
  cat > /etc/security/pwquality.conf <<EOL
# Password quality configuration
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
retry = 3
enforce_for_root
EOL

  # Configure system limits
  log "INFO" "Configuring system limits" "${CYAN}Configuring system limits...${NC}"
  
  cat > /etc/security/limits.d/99-security.conf <<EOL
# Limit resources that can be consumed by processes
*               soft    core            0
*               hard    core            0
*               hard    nproc           10000
*               soft    nproc           10000
*               hard    nofile          64000
*               soft    nofile          64000
root            hard    nproc           10000
root            soft    nproc           10000
root            hard    nofile          64000
root            soft    nofile          64000
EOL

  # Check and configure auditd if installed
  if command -v auditd &> /dev/null; then
    log "INFO" "Configuring auditd" "${CYAN}Configuring auditd...${NC}"
    
    # Configure basic audit rules
    cat > /etc/audit/rules.d/99-agencystack.rules <<EOL
# AgencyStack security audit rules
# Generated on $(date)

# Delete all existing rules
-D

# Increase the buffers to survive stress events
-b 8192

# Monitor for changes in authentication configuration
-w /etc/pam.d/ -p wa -k auth_changes
-w /etc/nsswitch.conf -p wa -k auth_changes
-w /etc/ssh/sshd_config -p wa -k auth_changes
-w /etc/ssh/sshd_config.d/ -p wa -k auth_changes

# Monitor important files
-w /etc/passwd -p wa -k user_changes
-w /etc/shadow -p wa -k user_changes
-w /etc/group -p wa -k user_changes
-w /etc/gshadow -p wa -k user_changes
-w /etc/security/opasswd -p wa -k user_changes

# Monitor changes to network configuration
-w /etc/network/ -p wa -k network_changes
-w /etc/sysctl.conf -p wa -k network_changes
-w /etc/sysctl.d/ -p wa -k network_changes

# Monitor changes to firewall
-w /etc/ufw/ -p wa -k firewall_changes
-w /etc/ufw.conf -p wa -k firewall_changes

# Monitor changes to AgencyStack
-w ${AGENCY_ROOT} -p wa -k agencystack_changes

# Make the configuration immutable until reboot
-e 2
EOL

    # Restart auditd to apply changes
    log "INFO" "Restarting auditd" "${CYAN}Restarting auditd...${NC}"
    systemctl restart auditd >> "${INSTALL_LOG}" 2>&1
  fi
  
  # Enable and configure rkhunter if installed
  if command -v rkhunter &> /dev/null; then
    log "INFO" "Configuring rkhunter" "${CYAN}Configuring rkhunter...${NC}"
    
    # Update rkhunter database
    rkhunter --update >> "${INSTALL_LOG}" 2>&1
    rkhunter --propupd >> "${INSTALL_LOG}" 2>&1
    
    # Schedule daily checks
    cat > /etc/cron.daily/rkhunter-check <<EOL
#!/bin/bash
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only | mail -s "RKHunter Daily Scan Report for \$(hostname)" ${ADMIN_EMAIL}
EOL
    chmod +x /etc/cron.daily/rkhunter-check
  fi
  
  # Copy hardening configurations to component directory
  cp /etc/apt/apt.conf.d/50unattended-upgrades "${COMPONENT_CONFIG_DIR}/unattended-upgrades.conf"
  cp /etc/sysctl.d/99-security.conf "${COMPONENT_CONFIG_DIR}/sysctl-security.conf"
  cp /etc/security/pwquality.conf "${COMPONENT_CONFIG_DIR}/pwquality.conf"
  cp /etc/security/limits.d/99-security.conf "${COMPONENT_CONFIG_DIR}/limits-security.conf"
  
  if [ -f /etc/audit/rules.d/99-agencystack.rules ]; then
    cp /etc/audit/rules.d/99-agencystack.rules "${COMPONENT_CONFIG_DIR}/audit-rules.conf"
  fi

# Run Security Audit
if [[ "${ENABLE_AUDIT}" == "true" ]]; then
  log "INFO" "Running security audit" "${CYAN}Running security audit...${NC}"
  
  # Create security audit script
  cat > "${INSTALL_DIR}/security-audit.sh" <<EOL
#!/bin/bash
# Security audit script for AgencyStack
# Generated on $(date)

AUDIT_DIR="${INSTALL_DIR}/audit"
AUDIT_FILE="\${AUDIT_DIR}/security-audit-\$(date +%Y-%m-%d-%H%M%S).log"
HOSTNAME=\$(hostname)
ADMIN_EMAIL="${ADMIN_EMAIL}"

# Create audit directory if it doesn't exist
mkdir -p "\${AUDIT_DIR}"

# Start audit log
echo "Security Audit for \${HOSTNAME} - \$(date)" > "\${AUDIT_FILE}"
echo "=================================================" >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check UFW status
echo "Firewall Status:" >> "\${AUDIT_FILE}"
echo "----------------" >> "\${AUDIT_FILE}"
if command -v ufw &> /dev/null; then
  ufw status verbose >> "\${AUDIT_FILE}" 2>&1
  echo "UFW not installed" >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check SSH configuration
echo "SSH Configuration:" >> "\${AUDIT_FILE}"
echo "------------------" >> "\${AUDIT_FILE}"
if [ -f /etc/ssh/sshd_config.d/00-hardened.conf ]; then
  echo "Hardened SSH configuration found." >> "\${AUDIT_FILE}"
  grep -v "^#" /etc/ssh/sshd_config.d/00-hardened.conf | grep -v "^$" >> "\${AUDIT_FILE}"
  echo "Hardened SSH configuration not found." >> "\${AUDIT_FILE}"
  grep -v "^#" /etc/ssh/sshd_config | grep -v "^$" >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check system updates
echo "System Updates:" >> "\${AUDIT_FILE}"
echo "---------------" >> "\${AUDIT_FILE}"
if command -v apt &> /dev/null; then
  apt list --upgradable 2>/dev/null >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check for listening ports
echo "Open Ports:" >> "\${AUDIT_FILE}"
echo "-----------" >> "\${AUDIT_FILE}"
if command -v ss &> /dev/null; then
  ss -tuln >> "\${AUDIT_FILE}"
elif command -v netstat &> /dev/null; then
  netstat -tuln >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check for running services
echo "Running Services:" >> "\${AUDIT_FILE}"
echo "-----------------" >> "\${AUDIT_FILE}"
systemctl list-units --type=service --state=running >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check for failed login attempts
echo "Failed Login Attempts:" >> "\${AUDIT_FILE}"
echo "----------------------" >> "\${AUDIT_FILE}"
grep "Failed password" /var/log/auth.log | tail -10 >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Check for unauthorized sudo usage
echo "Sudo Usage:" >> "\${AUDIT_FILE}"
echo "-----------" >> "\${AUDIT_FILE}"
grep "sudo:" /var/log/auth.log | tail -10 >> "\${AUDIT_FILE}"
echo "" >> "\${AUDIT_FILE}"

# Create symlink to latest audit
ln -sf "\${AUDIT_FILE}" "\${AUDIT_DIR}/latest-audit.log"

# Send email notification if requested
if [ -n "\${ADMIN_EMAIL}" ]; then
  cat "\${AUDIT_FILE}" | mail -s "Security Audit Report for \${HOSTNAME}" "\${ADMIN_EMAIL}"

echo "Security audit completed. Results saved to \${AUDIT_FILE}"
EOL

  chmod +x "${INSTALL_DIR}/security-audit.sh"
  
  # Run initial security audit
  "${INSTALL_DIR}/security-audit.sh" >> "${INSTALL_LOG}" 2>&1
  
  # Schedule daily security audit
  cat > /etc/cron.daily/security-audit <<EOL
#!/bin/bash
${INSTALL_DIR}/security-audit.sh
EOL
  chmod +x /etc/cron.daily/security-audit
  
  log "SUCCESS" "Security audit setup completed" "${GREEN}✅ Security audit setup completed.${NC}"

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Security component installed" "{\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\",\"ufw_enabled\":${ENABLE_UFW},\"ssh_hardened\":${ENABLE_SSH_HARDENING},\"system_hardened\":${ENABLE_SYSTEM_HARDENING}}"

log "SUCCESS" "Security installation completed" "${GREEN}✅ Security installation completed!${NC}"
echo
log "INFO" "Security overview" "${CYAN}Security overview:${NC}"

# UFW Status
if [[ "${ENABLE_UFW}" == "true" ]]; then
  echo -e "${GREEN}✅ Firewall (UFW) configured and enabled${NC}"
  echo -e "   - Default: deny incoming, allow outgoing"
  echo -e "   - Allowed ports: ${UFW_PORTS[*]} ${ADDITIONAL_UFW_PORTS[*]}"
  echo -e "${YELLOW}⚠️ Firewall (UFW) configuration was skipped${NC}"

# SSH Status
if [[ "${ENABLE_SSH_HARDENING}" == "true" ]]; then
  echo -e "${GREEN}✅ SSH hardening applied${NC}"
  echo -e "   - SSH running on port ${SSH_PORT}"
  echo -e "   - Root login: prohibit-password"
  echo -e "   - Password authentication: enabled"
  echo -e "${YELLOW}⚠️ SSH hardening was skipped${NC}"

# System Hardening Status
if [[ "${ENABLE_SYSTEM_HARDENING}" == "true" ]]; then
  echo -e "${GREEN}✅ System hardening applied${NC}"
  echo -e "   - Automatic security updates enabled"
  echo -e "   - Sysctl security settings applied"
  echo -e "   - Password policies enforced"
  echo -e "   - System limits configured"
  
  if command -v auditd &> /dev/null; then
    echo -e "   - Audit daemon configured"
  fi
  
  if command -v rkhunter &> /dev/null; then
    echo -e "   - RKHunter rootkit scanner configured"
  fi
  echo -e "${YELLOW}⚠️ System hardening was skipped${NC}"

# Audit Status
if [[ "${ENABLE_AUDIT}" == "true" ]]; then
  echo -e "${GREEN}✅ Security audit enabled${NC}"
  echo -e "   - Initial security audit completed"
  echo -e "   - Daily security audits scheduled"
  echo -e "   - Audit reports saved to ${INSTALL_DIR}/audit/"
  echo -e "${YELLOW}⚠️ Security audit was skipped${NC}"

echo
echo -e "${GREEN}Security hardening is complete. The system is now better protected against common attacks.${NC}"
echo -e "${CYAN}You can run a manual security audit at any time with: ${INSTALL_DIR}/security-audit.sh${NC}"

exit 0
