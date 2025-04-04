#!/bin/bash
# test_alert.sh - Test AgencyStack alerting channels
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/test_alert-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🔔 AgencyStack Alert Test${NC}"
log "=============================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  log "${RED}Error: config.env file not found${NC}"
  log "Please run the AgencyStack installation first"
  exit 1
fi

# Source the environment
source /opt/agency_stack/config.env

# Test subject and message
TEST_SUBJECT="[TEST] AgencyStack Alert Test"
TEST_MESSAGE="This is a test alert from AgencyStack.
If you received this alert, your alert configuration is working correctly.

Time: $(date)
Server: $(hostname)
IP: $(hostname -I | awk '{print $1}')

This is only a test and can be safely ignored."

# Test Email Alert
test_email_alert() {
  if [[ "$ALERT_EMAIL_ENABLED" != "true" ]]; then
    log "${YELLOW}Email alerts are not enabled${NC}"
    log "To enable, set ALERT_EMAIL_ENABLED=true in /opt/agency_stack/config.env"
    return 1
  fi
  
  if [[ "$SMTP_ENABLED" != "true" ]]; then
    log "${YELLOW}SMTP is not enabled${NC}"
    log "To enable, set SMTP_ENABLED=true in /opt/agency_stack/config.env"
    return 1
  fi
  
  if [ -z "$ALERT_EMAIL_RECIPIENT" ]; then
    log "${YELLOW}No email recipient configured${NC}"
    log "To set a recipient, add ALERT_EMAIL_RECIPIENT=your@email.com to /opt/agency_stack/config.env"
    return 1
  fi
  
  # Check if Mailu is installed and running
  if grep -q "Mailu" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    if ! docker ps | grep -q "mailu-front"; then
      log "${YELLOW}Mailu is installed but not running${NC}"
      log "Please start Mailu first: cd /opt/agency_stack/mailu && docker-compose up -d"
      return 1
    fi
    
    log "${BLUE}Using Mailu for email delivery${NC}"
  elif [[ "$SMTP_HOST" != "mailu" ]]; then
    # Check if SMTP host is reachable
    if ! nc -z -w5 "$SMTP_HOST" "$SMTP_PORT" 2>/dev/null; then
      log "${YELLOW}SMTP server $SMTP_HOST:$SMTP_PORT is not reachable${NC}"
      log "Please check your SMTP configuration"
      return 1
    fi
  else
    log "${YELLOW}Using SMTP but Mailu is not installed${NC}"
    log "Consider installing Mailu for reliable email delivery: make install (select Mailu component)"
  fi
  
  log "${BLUE}Sending test email to ${ALERT_EMAIL_RECIPIENT}...${NC}"
  
  # Create email content
  local email_file=$(mktemp)
  cat > "$email_file" << EOL
From: AgencyStack Monitoring <$SMTP_FROM>
To: $ALERT_EMAIL_RECIPIENT
Subject: $TEST_SUBJECT
Content-Type: text/plain; charset=UTF-8

$TEST_MESSAGE

---
AgencyStack Monitoring System
EOL
  
  # Send email using curl
  if curl --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
     --ssl-reqd \
     --mail-from "${SMTP_FROM}" \
     --mail-rcpt "${ALERT_EMAIL_RECIPIENT}" \
     --upload-file "$email_file" \
     --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
     --silent --show-error --fail; then
    log "${GREEN}✅ Test email sent successfully${NC}"
    
    # Check if we're using Mailu
    if [[ "$SMTP_HOST" == "mailu" || -d "/opt/agency_stack/data/mailu" ]]; then
      log "${CYAN}Mailu is configured for email delivery${NC}"
      log "You can check the Mailu admin panel at https://mailu.${PRIMARY_DOMAIN}"
    fi
    
    return 0
  else
    log "${RED}❌ Failed to send test email${NC}"
    log "Please check your SMTP configuration in /opt/agency_stack/config.env"
    return 1
  fi
  
  # Clean up
  rm -f "$email_file"
}

# Test Telegram Alert
test_telegram_alert() {
  if [[ "$ALERT_TELEGRAM_ENABLED" != "true" ]]; then
    log "${YELLOW}Telegram alerts are not enabled${NC}"
    log "To enable, set ALERT_TELEGRAM_ENABLED=true in /opt/agency_stack/config.env"
    return 1
  fi
  
  if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    log "${YELLOW}No Telegram bot token configured${NC}"
    log "To set a token, add TELEGRAM_BOT_TOKEN=your-bot-token to /opt/agency_stack/config.env"
    return 1
  fi
  
  if [ -z "$TELEGRAM_CHAT_ID" ]; then
    log "${YELLOW}No Telegram chat ID configured${NC}"
    log "To set a chat ID, add TELEGRAM_CHAT_ID=your-chat-id to /opt/agency_stack/config.env"
    return 1
  fi
  
  log "${BLUE}Sending test Telegram message...${NC}"
  
  # Format message
  local formatted_message="*${TEST_SUBJECT}*\n\n${TEST_MESSAGE}"
  
  # Send to Telegram
  response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
     -d chat_id="${TELEGRAM_CHAT_ID}" \
     -d text="${formatted_message}" \
     -d parse_mode="Markdown")
  
  if echo "$response" | grep -q '"ok":true'; then
    log "${GREEN}✅ Test Telegram message sent successfully${NC}"
    return 0
  else
    log "${RED}❌ Failed to send test Telegram message${NC}"
    log "Response: $response"
    log "Please check your Telegram configuration in /opt/agency_stack/config.env"
    return 1
  fi
}

# Test Webhook Alert
test_webhook_alert() {
  if [[ "$ALERT_WEBHOOK_ENABLED" != "true" ]]; then
    log "${YELLOW}Webhook alerts are not enabled${NC}"
    log "To enable, set ALERT_WEBHOOK_ENABLED=true in /opt/agency_stack/config.env"
    return 1
  fi
  
  if [ -z "$WEBHOOK_URL" ]; then
    log "${YELLOW}No webhook URL configured${NC}"
    log "To set a URL, add WEBHOOK_URL=your-webhook-url to /opt/agency_stack/config.env"
    return 1
  fi
  
  log "${BLUE}Sending test webhook notification...${NC}"
  
  # Create JSON payload
  local json_payload=$(cat << EOL
{
  "title": "${TEST_SUBJECT}",
  "message": $(echo "${TEST_MESSAGE}" | jq -Rs .),
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hostname": "$(hostname)",
  "severity": "info",
  "test": true
}
EOL
)
  
  # Send to webhook
  response=$(curl -s -X POST "${WEBHOOK_URL}" \
     -H "Content-Type: application/json" \
     -d "${json_payload}")
  
  if [ $? -eq 0 ]; then
    log "${GREEN}✅ Test webhook notification sent successfully${NC}"
    if [ -n "$response" ]; then
      log "Response: $response"
    fi
    return 0
  else
    log "${RED}❌ Failed to send test webhook notification${NC}"
    log "Please check your webhook configuration in /opt/agency_stack/config.env"
    return 1
  fi
}

# Run all tests
run_all_tests() {
  local success=0
  local failed=0
  
  log "${BLUE}Testing all configured alert channels...${NC}"
  
  # Test email alerts
  if [[ "$ALERT_EMAIL_ENABLED" == "true" ]]; then
    if test_email_alert; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  else
    log "${YELLOW}Skipping email alert test (not enabled)${NC}"
  fi
  
  # Test Telegram alerts
  if [[ "$ALERT_TELEGRAM_ENABLED" == "true" ]]; then
    if test_telegram_alert; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  else
    log "${YELLOW}Skipping Telegram alert test (not enabled)${NC}"
  fi
  
  # Test webhook alerts
  if [[ "$ALERT_WEBHOOK_ENABLED" == "true" ]]; then
    if test_webhook_alert; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  else
    log "${YELLOW}Skipping webhook alert test (not enabled)${NC}"
  fi
  
  log ""
  log "${CYAN}${BOLD}Alert Test Summary:${NC}"
  log "Successful tests: ${GREEN}$success${NC}"
  log "Failed tests: ${RED}$failed${NC}"
  
  if [ $success -eq 0 ] && [ $failed -eq 0 ]; then
    log "${YELLOW}No alert channels are enabled${NC}"
    log "To enable alerts, edit /opt/agency_stack/config.env and set at least one of:"
    log "- ALERT_EMAIL_ENABLED=true"
    log "- ALERT_TELEGRAM_ENABLED=true"
    log "- ALERT_WEBHOOK_ENABLED=true"
  fi
}

# Main
main() {
  local channel="$1"
  
  case "$channel" in
    email)
      test_email_alert
      ;;
    telegram)
      test_telegram_alert
      ;;
    webhook)
      test_webhook_alert
      ;;
    *)
      run_all_tests
      ;;
  esac
}

main "$@"
