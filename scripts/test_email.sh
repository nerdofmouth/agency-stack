#!/bin/bash
# test_email.sh - Test email sending from AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  echo -e "${RED}Error: config.env file not found${NC}"
  echo -e "Run this script after installation or from the installation directory"
  exit 1
fi

# Load configuration
source /opt/agency_stack/config.env

# Check parameters
RECIPIENT=$1
if [ -z "$RECIPIENT" ]; then
  echo -e "${RED}Error: Recipient email address required${NC}"
  echo -e "Usage: $0 recipient@example.com"
  exit 1
fi

# Check if SMTP is enabled
if [ "$SMTP_ENABLED" != "true" ]; then
  echo -e "${RED}Error: SMTP is not enabled in config.env${NC}"
  echo -e "Please set SMTP_ENABLED=true in /opt/agency_stack/config.env"
  exit 1
fi

echo -e "${BLUE}Testing email configuration...${NC}"
echo -e "SMTP Host: $SMTP_HOST"
echo -e "SMTP Port: $SMTP_PORT"
echo -e "SMTP Username: $SMTP_USERNAME"
echo -e "SMTP From: $SMTP_FROM"
echo -e "Sending to: $RECIPIENT"

# Create a temporary email file
TMP_EMAIL=$(mktemp)
cat > $TMP_EMAIL << EOL
From: AgencyStack <$SMTP_FROM>
To: $RECIPIENT
Subject: AgencyStack Email Test

This is a test email from your AgencyStack installation.
If you received this email, your SMTP configuration is working correctly.

Time sent: $(date)
Server: $(hostname)
Configuration:
- SMTP Host: $SMTP_HOST
- SMTP Port: $SMTP_PORT
- SMTP From: $SMTP_FROM

For help and documentation, visit:
https://stack.nerdofmouth.com
EOL

# Send email using curl and SMTP
if command -v curl > /dev/null; then
  # Using curl for SMTP
  response=$(curl --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
    --ssl-reqd \
    --mail-from "${SMTP_FROM}" \
    --mail-rcpt "${RECIPIENT}" \
    --upload-file $TMP_EMAIL \
    --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    --silent --show-error --fail 2>&1)
  
  status=$?
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}✅ Email sent successfully!${NC}"
    echo -e "Please check ${RECIPIENT} for the test email"
  else
    echo -e "${RED}❌ Failed to send email${NC}"
    echo -e "Error: $response"
    echo -e "Please check your SMTP configuration in /opt/agency_stack/config.env"
  fi
else
  # Fallback to mail command if curl is not available
  echo -e "${YELLOW}Warning: curl not found, falling back to mail command${NC}"
  cat $TMP_EMAIL | mail -s "AgencyStack Email Test" $RECIPIENT
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Email sent successfully!${NC}"
    echo -e "Please check ${RECIPIENT} for the test email"
  else
    echo -e "${RED}❌ Failed to send email${NC}"
    echo -e "Please check your SMTP configuration in /opt/agency_stack/config.env"
  fi
fi

# Clean up
rm $TMP_EMAIL
