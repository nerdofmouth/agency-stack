#!/bin/bash
# setup_log_rotation.sh - Configure log rotation for AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up log rotation for AgencyStack...${NC}"

# Check if logrotate is installed
if ! command -v logrotate &> /dev/null; then
    echo -e "${YELLOW}Installing logrotate...${NC}"
    apt-get update -qq && apt-get install -y logrotate
fi

# Create logrotate configuration
cat > /etc/logrotate.d/agency_stack << EOL
/var/log/agency_stack/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    dateext
    dateformat -%Y%m%d
    sharedscripts
    postrotate
        systemctl reload rsyslog 2>/dev/null || true
    endscript
}
EOL

# Set proper permissions
chmod 644 /etc/logrotate.d/agency_stack

# Create log directory if it doesn't exist
mkdir -p /var/log/agency_stack
chmod 755 /var/log/agency_stack

# Run logrotate once to verify configuration
logrotate -d /etc/logrotate.d/agency_stack

echo -e "${GREEN}✅ Log rotation has been configured${NC}"
echo -e "Logs will be rotated daily and kept for 14 days"
echo -e "Configuration: /etc/logrotate.d/agency_stack"
