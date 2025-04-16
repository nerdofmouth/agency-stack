#!/bin/bash
# AgencyStack Full Installation Script
# https://stack.nerdofmouth.com
#
# This script installs the complete AgencyStack system with all components
# It orchestrates the installation of core infrastructure, services,
# security features, and multi-tenancy setup
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CORE_DIR="${ROOT_DIR}/scripts/core"
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"
SECURITY_DIR="${ROOT_DIR}/scripts/security"
MULTI_TENANCY_DIR="${ROOT_DIR}/scripts/multi-tenancy"
ADMIN_DIR="${ROOT_DIR}/scripts/admin"
VERBOSE=false
DOMAIN=""
EMAIL=""

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Full Installation${NC}"
  echo -e "=============================="
  echo -e "This script installs the complete AgencyStack system with all components."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>   Primary domain for installation (required)"
  echo -e "  ${BOLD}--email${NC} <email>     Email for Let's Encrypt notifications (required)"
  echo -e "  ${BOLD}--verbose${NC}           Show detailed output during installation"
  echo -e "  ${BOLD}--minimal${NC}           Install only core components (no optional services)"
  echo -e "  ${BOLD}--help${NC}              Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain example.com --email admin@example.com --verbose"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Installation takes approximately 30-60 minutes depending on your system"
  exit 0
}

# Parse arguments
MINIMAL=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --email)
      EMAIL="$2"
      shift
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --minimal)
      MINIMAL=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$EMAIL" ]; then
  echo -e "${RED}Error: --email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Display header
echo -e "${MAGENTA}${BOLD}"
cat << "EOF"

 _______                                _______ __               __    
|   _   |.-----.-----.-----.----.--.--.|     __|  |_.---.-.----.|  |--.
|       ||  _  |  -__|     |  __|  |  ||__     |   _|  _  |  __||    < 
|___|___||___  |_____|__|__|____|___  ||_______|____|___._|____||__|__|
         |_____|                |_____|                                

EOF
echo -e "${NC}"

# Show motto
MOTTO_PATH="$ROOT_DIR/scripts/motto.sh"
if [ -f "$MOTTO_PATH" ]; then
  source "$MOTTO_PATH" && random_motto
  echo ""
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Initialize port management
echo -e "${CYAN}🔌 Initializing port management system...${NC}"
PORT_MANAGER="$ROOT_DIR/scripts/utils/port_manager.sh"
if [ -f "$PORT_MANAGER" ]; then
  source "$PORT_MANAGER"
  echo -e "${GREEN}✅ Port management system initialized.${NC}"
else
  echo -e "${YELLOW}⚠️ Port management system not found. Ports will not be automatically assigned.${NC}"
fi

echo -e "${BLUE}${BOLD}🚀 Starting AgencyStack installation...${NC}"
echo -e "${YELLOW}💡 Domain: ${DOMAIN}${NC}"
echo -e "${YELLOW}💡 Email: ${EMAIL}${NC}"
echo -e "${YELLOW}💡 Verbose: ${VERBOSE}${NC}"
echo -e "${YELLOW}💡 Minimal: ${MINIMAL}${NC}"
echo -e ""

# 1. Core Infrastructure
echo -e "${BLUE}${BOLD}🧱 Installing Core Infrastructure...${NC}"
if [ "$VERBOSE" = true ]; then
  bash "${CORE_DIR}/install_infrastructure.sh" --verbose
else
  bash "${CORE_DIR}/install_infrastructure.sh"
fi

# 2. Security Infrastructure
echo -e "${BLUE}${BOLD}🔒 Installing Security Infrastructure...${NC}"
if [ "$VERBOSE" = true ]; then
  bash "${CORE_DIR}/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$EMAIL" --verbose
else
  bash "${CORE_DIR}/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$EMAIL"
fi

# 3. Multi-Tenancy Setup
echo -e "${BLUE}${BOLD}🏢 Setting up Multi-Tenancy Infrastructure...${NC}"
if [ "$VERBOSE" = true ]; then
  bash "${MULTI_TENANCY_DIR}/install_multi_tenancy.sh" --verbose
else
  bash "${MULTI_TENANCY_DIR}/install_multi_tenancy.sh"
fi

# 4. Admin Dashboard
echo -e "${BLUE}${BOLD}📊 Installing Admin Dashboard...${NC}"
if [ -f "${ADMIN_DIR}/install_launchpad_dashboard.sh" ]; then
  if [ "$VERBOSE" = true ]; then
    bash "${ADMIN_DIR}/install_launchpad_dashboard.sh" --domain "dashboard.${DOMAIN}" --verbose
  else
    bash "${ADMIN_DIR}/install_launchpad_dashboard.sh" --domain "dashboard.${DOMAIN}"
  fi
else
  echo -e "${YELLOW}⚠️ Dashboard installation script not found. Skipping dashboard installation.${NC}"
fi

# 5. Essential Services
echo -e "${BLUE}${BOLD}🔧 Installing Essential Services...${NC}"

# Install Keycloak
if [ -f "${COMPONENTS_DIR}/install_keycloak.sh" ]; then
  echo -e "${CYAN}🔑 Installing Keycloak...${NC}"
  if [ "$VERBOSE" = true ]; then
    bash "${COMPONENTS_DIR}/install_keycloak.sh" --domain "auth.${DOMAIN}" --verbose
  else
    bash "${COMPONENTS_DIR}/install_keycloak.sh" --domain "auth.${DOMAIN}"
  fi
else
  echo -e "${YELLOW}⚠️ Keycloak installation script not found. Skipping Keycloak installation.${NC}"
fi

# Install Mailu
if [ -f "${COMPONENTS_DIR}/install_mailu.sh" ]; then
  echo -e "${CYAN}📧 Installing Mailu Email Server...${NC}"
  if [ "$VERBOSE" = true ]; then
    bash "${COMPONENTS_DIR}/install_mailu.sh" --domain "mail.${DOMAIN}" --email-domain "${DOMAIN}" --admin-email "${EMAIL}" --verbose
  else
    bash "${COMPONENTS_DIR}/install_mailu.sh" --domain "mail.${DOMAIN}" --email-domain "${DOMAIN}" --admin-email "${EMAIL}"
  fi
else
  echo -e "${YELLOW}⚠️ Mailu installation script not found. Skipping Mailu installation.${NC}"
fi

# 6. Optional Services (skip if minimal installation)
if [ "$MINIMAL" = false ]; then
  echo -e "${BLUE}${BOLD}🧩 Installing Optional Services...${NC}"
  
  # Array of optional components
  declare -a OPTIONAL_COMPONENTS=(
    "install_portainer.sh"
    "install_erpnext.sh"
    "install_peertube.sh"
    "install_wordpress_module.sh"
    "install_focalboard.sh"
    "install_listmonk.sh"
    "install_calcom.sh"
    "install_n8n.sh"
    "install_openintegrationhub.sh"
    "install_taskwarrior_calcure.sh"
    "install_posthog.sh"
    "install_killbill.sh"
    "install_seafile.sh"
    "install_documenso.sh"
    "install_webpush.sh"
    "install_markdown_lexical.sh"
  )
  
  # Install each optional component if the script exists
  for component in "${OPTIONAL_COMPONENTS[@]}"; do
    if [ -f "${COMPONENTS_DIR}/${component}" ]; then
      component_name=$(echo "$component" | sed 's/install_//;s/\.sh//')
      echo -e "${CYAN}🔧 Installing ${component_name}...${NC}"
      if [ "$VERBOSE" = true ]; then
        bash "${COMPONENTS_DIR}/${component}" --domain "${component_name}.${DOMAIN}" --verbose
      else
        bash "${COMPONENTS_DIR}/${component}" --domain "${component_name}.${DOMAIN}"
      fi
    fi
  done
fi

# 7. Setup Monitoring
echo -e "${BLUE}${BOLD}📈 Setting up Monitoring...${NC}"
if [ -f "${COMPONENTS_DIR}/install_monitoring.sh" ]; then
  if [ "$VERBOSE" = true ]; then
    bash "${COMPONENTS_DIR}/install_monitoring.sh" --domain "monitoring.${DOMAIN}" --verbose
  else
    bash "${COMPONENTS_DIR}/install_monitoring.sh" --domain "monitoring.${DOMAIN}"
  fi
else
  echo -e "${YELLOW}⚠️ Monitoring installation script not found. Skipping monitoring installation.${NC}"
fi

# 8. Setup Backup System
echo -e "${BLUE}${BOLD}💾 Setting up Backup System...${NC}"
if [ -f "${COMPONENTS_DIR}/install_backup_strategy.sh" ]; then
  if [ "$VERBOSE" = true ]; then
    bash "${COMPONENTS_DIR}/install_backup_strategy.sh" --verbose
  else
    bash "${COMPONENTS_DIR}/install_backup_strategy.sh"
  fi
else
  echo -e "${YELLOW}⚠️ Backup strategy script not found. Skipping backup setup.${NC}"
fi

# 9. Final Security Audit
echo -e "${BLUE}${BOLD}🛡️ Running Final Security Audit...${NC}"
if [ -f "${SECURITY_DIR}/audit_stack.sh" ]; then
  bash "${SECURITY_DIR}/audit_stack.sh"
else
  echo -e "${YELLOW}⚠️ Security audit script not found. Skipping security audit.${NC}"
fi

# Print installation summary
echo -e "${GREEN}${BOLD}✅ AgencyStack installation completed!${NC}"
echo -e "${CYAN}🚀 Access your services through the Launchpad Dashboard: https://dashboard.${DOMAIN}${NC}"

# Show port allocation if port manager exists
if [ -f "$PORT_MANAGER" ]; then
  echo -e ""
  echo -e "${YELLOW}📊 Port allocation summary:${NC}"
  "$PORT_MANAGER" list
fi

# Show final motto after successful installation
if [ -f "$MOTTO_PATH" ]; then
  echo ""
  source "$MOTTO_PATH" && random_motto
  echo -e "\n${CYAN}Thank you for choosing AgencyStack!${NC}"
fi

exit 0
