#!/bin/bash
# integrate_email.sh - Email Integration for AgencyStack
# https://stack.nerdofmouth.com

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/integrate_common.sh"

# Email Integration version
EMAIL_VERSION="1.0.1"

# Start logging
LOG_FILE="${INTEGRATION_LOG_DIR}/email-${CURRENT_DATE}.log"
log "${MAGENTA}${BOLD}📧 AgencyStack Email Integration${NC}"
log "========================================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Get installed components
get_installed_components

# Check if Mailu is installed
if ! is_component_installed "Mailu"; then
  log "${YELLOW}Warning: Mailu is not installed${NC}"
  log "Skipping email integration. Install Mailu for email capabilities."
  exit 1
fi

# WordPress Email Integration
integrate_wordpress_email() {
  if ! is_component_installed "WordPress"; then
    log "${YELLOW}WordPress not installed, skipping WordPress email integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up WordPress email integration with Mailu...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "email" "WordPress"; then
    log "${GREEN}WordPress email integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the WordPress email integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping WordPress email integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Check for WordPress WP-CLI wrapper
  WP_CLI="/opt/agency_stack/wordpress/wp.sh"
  if [ ! -f "$WP_CLI" ]; then
    log "${YELLOW}Warning: WordPress CLI not available at ${WP_CLI}${NC}"
    log "Manual configuration will be required:"
    log "1. Install the WP Mail SMTP plugin"
    log "2. Configure with Mailu SMTP settings"
    record_integration "email" "WordPress" "$EMAIL_VERSION" "Manual configuration required - WP-CLI not available"
    return 1
  fi
  
  # Install WP Mail SMTP plugin if not already installed
  if ! sudo $WP_CLI plugin is-installed wp-mail-smtp; then
    log "${BLUE}Installing WP Mail SMTP plugin...${NC}"
    sudo $WP_CLI plugin install wp-mail-smtp --activate
  elif ! sudo $WP_CLI plugin is-active wp-mail-smtp; then
    log "${BLUE}Activating WP Mail SMTP plugin...${NC}"
    sudo $WP_CLI plugin activate wp-mail-smtp
  fi
  
  # Configure SMTP settings
  log "${BLUE}Configuring WordPress SMTP settings...${NC}"
  
  # Get Mailu admin password from config or prompt
  MAILU_ADMIN_PASSWORD=${MAILU_ADMIN_PASSWORD:-""}
  if [ -z "$MAILU_ADMIN_PASSWORD" ]; then
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Enter Mailu admin password:${NC}"
      read -s MAILU_ADMIN_PASSWORD
      echo ""
    else
      log "${RED}Error: Mailu admin password not found in environment and auto mode is enabled${NC}"
      log "Cannot configure WordPress email without Mailu credentials"
      return 1
    fi
  fi
  
  # Create WordPress admin email if not set
  WP_ADMIN_EMAIL=$(sudo $WP_CLI option get admin_email)
  if [ -z "$WP_ADMIN_EMAIL" ] || [ "$WP_ADMIN_EMAIL" == "admin@example.com" ]; then
    WP_ADMIN_EMAIL="wordpress@${PRIMARY_DOMAIN}"
    sudo $WP_CLI option update admin_email "$WP_ADMIN_EMAIL"
  fi
  
  # Configure WP Mail SMTP plugin
  sudo $WP_CLI option update wp_mail_smtp '{
    "mail": {
      "from_email": "'$WP_ADMIN_EMAIL'",
      "from_name": "WordPress",
      "mailer": "smtp",
      "return_path": false,
      "from_email_force": true,
      "from_name_force": true
    },
    "smtp": {
      "host": "mailu",
      "port": "587",
      "encryption": "tls",
      "autotls": true,
      "auth": true,
      "user": "'$WP_ADMIN_EMAIL'",
      "pass": "'$MAILU_ADMIN_PASSWORD'"
    }
  }' --format=json
  
  # Test email configuration
  log "${BLUE}Testing WordPress email configuration...${NC}"
  TEST_RESULT=$(sudo $WP_CLI wp-mail-smtp test)
  
  if echo "$TEST_RESULT" | grep -q "Success"; then
    log "${GREEN}✅ WordPress email test successful${NC}"
  else
    log "${YELLOW}⚠️ WordPress email test failed${NC}"
    log "Please check the SMTP configuration manually"
    log "Error: $TEST_RESULT"
  fi
  
  log "${GREEN}✅ WordPress email integration with Mailu complete${NC}"
  
  # Record integration as applied
  record_integration "email" "WordPress" "$EMAIL_VERSION" "SMTP integration with Mailu via WP Mail SMTP plugin"
  
  return 0
}

# ERPNext Email Integration
integrate_erpnext_email() {
  if ! is_component_installed "ERPNext"; then
    log "${YELLOW}ERPNext not installed, skipping ERPNext email integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up ERPNext email integration with Mailu...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "email" "ERPNext"; then
    log "${GREEN}ERPNext email integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the ERPNext email integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping ERPNext email integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Check for ERPNext bench tool
  BENCH_CLI="/opt/agency_stack/erpnext/bench.sh"
  if [ ! -f "$BENCH_CLI" ]; then
    log "${YELLOW}Warning: ERPNext bench not available at ${BENCH_CLI}${NC}"
    log "Manual configuration will be required for ERPNext email"
    record_integration "email" "ERPNext" "$EMAIL_VERSION" "Manual configuration required - bench tool not available"
    return 1
  fi
  
  # Get site name
  SITE_NAME="${ERPNEXT_SITE_NAME:-erp.${PRIMARY_DOMAIN}}"
  
  # Configure email in ERPNext
  log "${BLUE}Configuring ERPNext email settings...${NC}"
  
  # Get Mailu admin password from config or prompt
  MAILU_ADMIN_PASSWORD=${MAILU_ADMIN_PASSWORD:-""}
  if [ -z "$MAILU_ADMIN_PASSWORD" ]; then
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Enter Mailu admin password:${NC}"
      read -s MAILU_ADMIN_PASSWORD
      echo ""
    else
      log "${RED}Error: Mailu admin password not found in environment and auto mode is enabled${NC}"
      log "Cannot configure ERPNext email without Mailu credentials"
      return 1
    fi
  fi
  
  # Configure SMTP settings
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g smtp_server "mailu"
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g smtp_port "587"
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g smtp_use_tls "1"
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g email_sender_name "ERPNext"
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g auto_email_id "erpnext@${PRIMARY_DOMAIN}"
  
  # Create Email Domain if it doesn't exist
  log "${BLUE}Setting up ERPNext Email Domain...${NC}"
  
  # Check if email domain already exists
  EMAIL_DOMAIN_EXISTS=$(sudo $BENCH_CLI --site "$SITE_NAME" execute "frappe.db.exists('Email Domain', '${PRIMARY_DOMAIN}')" 2>/dev/null)
  
  if [ "$EMAIL_DOMAIN_EXISTS" != "True" ]; then
    # Create email domain
    sudo $BENCH_CLI --site "$SITE_NAME" execute frappe.client.insert --args '{
      "doctype": "Email Domain",
      "domain_name": "'${PRIMARY_DOMAIN}'",
      "email_server": "mailu",
      "use_imap": 1,
      "use_ssl": 0,
      "use_tls": 1,
      "attachment_limit": 10240000,
      "smtp_server": "mailu",
      "smtp_port": 587,
      "use_ssl_for_outgoing": 0,
      "use_tls_for_outgoing": 1,
      "smtp_username": "erpnext@'${PRIMARY_DOMAIN}'",
      "smtp_password": "'$MAILU_ADMIN_PASSWORD'"
    }'
  else
    log "${YELLOW}Email domain already exists, updating settings...${NC}"
    
    # Update email domain settings
    sudo $BENCH_CLI --site "$SITE_NAME" execute "
    doc = frappe.get_doc('Email Domain', '${PRIMARY_DOMAIN}')
    doc.email_server = 'mailu'
    doc.use_imap = 1
    doc.use_ssl = 0
    doc.use_tls = 1
    doc.smtp_server = 'mailu'
    doc.smtp_port = 587
    doc.use_ssl_for_outgoing = 0
    doc.use_tls_for_outgoing = 1
    doc.smtp_username = 'erpnext@${PRIMARY_DOMAIN}'
    doc.smtp_password = '${MAILU_ADMIN_PASSWORD}'
    doc.save()
    "
  fi
  
  # Create Email Account if it doesn't exist
  log "${BLUE}Setting up ERPNext Email Account...${NC}"
  
  # Check if email account already exists
  EMAIL_ACCOUNT_EXISTS=$(sudo $BENCH_CLI --site "$SITE_NAME" execute "frappe.db.exists('Email Account', 'ERPNext Notifications')" 2>/dev/null)
  
  if [ "$EMAIL_ACCOUNT_EXISTS" != "True" ]; then
    # Create email account
    sudo $BENCH_CLI --site "$SITE_NAME" execute frappe.client.insert --args '{
      "doctype": "Email Account",
      "email_account_name": "ERPNext Notifications",
      "domain": "'${PRIMARY_DOMAIN}'",
      "email_id": "erpnext@'${PRIMARY_DOMAIN}'",
      "password": "'$MAILU_ADMIN_PASSWORD'",
      "enable_outgoing": 1,
      "default_outgoing": 1,
      "enable_incoming": 0,
      "use_imap": 1,
      "use_ssl": 0,
      "use_tls": 1,
      "smtp_server": "mailu",
      "smtp_port": 587
    }'
  else
    log "${YELLOW}Email account already exists, updating settings...${NC}"
    
    # Update email account settings
    sudo $BENCH_CLI --site "$SITE_NAME" execute "
    doc = frappe.get_doc('Email Account', 'ERPNext Notifications')
    doc.domain = '${PRIMARY_DOMAIN}'
    doc.email_id = 'erpnext@${PRIMARY_DOMAIN}'
    doc.password = '${MAILU_ADMIN_PASSWORD}'
    doc.enable_outgoing = 1
    doc.default_outgoing = 1
    doc.smtp_server = 'mailu'
    doc.smtp_port = 587
    doc.use_ssl = 0
    doc.use_tls = 1
    doc.save()
    "
  fi
  
  log "${GREEN}✅ ERPNext email integration with Mailu complete${NC}"
  
  # Record integration as applied
  record_integration "email" "ERPNext" "$EMAIL_VERSION" "SMTP integration with Mailu for notifications and transactional emails"
  
  return 0
}

# Main function
main() {
  log "${BLUE}Starting Email integrations...${NC}"
  
  # Integrate WordPress with Mailu
  integrate_wordpress_email
  
  # Integrate ERPNext with Mailu
  integrate_erpnext_email
  
  # Additional integrations can be added here
  
  # Generate integration report
  generate_integration_report
  
  log ""
  log "${GREEN}${BOLD}Email integration complete!${NC}"
  log "See integration log for details: ${LOG_FILE}"
  log "See integration report for summary and recommended actions."
}

# Run main function
main
