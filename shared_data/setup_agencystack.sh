#!/bin/bash
# setup_agencystack.sh - Script to set up AgencyStack inside the development container
# Follows the AgencyStack Alpha Phase directives for installation validation

set -e

# Output styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log function
log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${BOLD}$1${NC}"
}

# Clone a fresh copy of AgencyStack
log "Cloning AgencyStack repository"
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/nerdofmouth/agency-stack.git
cd agency-stack

# Set up required directories as per AgencyStack standards
log "Setting up AgencyStack directory structure"
sudo mkdir -p /opt/agency_stack/clients/default
sudo mkdir -p /var/log/agency_stack/components
sudo chown -R developer:developer /opt/agency_stack
sudo chown -R developer:developer /var/log/agency_stack

# Set environment variables required for installation
export DOMAIN="localhost.test"
export ADMIN_EMAIL="admin@localhost.test"
export CLIENT_ID="default"
export DEBIAN_FRONTEND=noninteractive
export GIT_TERMINAL_PROMPT=0
export APT_LISTCHANGES_FRONTEND=none
export APT_LISTBUGS_FRONTEND=none

# Test basic installation using Makefile as required by Alpha Phase
log "Testing AgencyStack installation using Makefile"
make help
echo -e "\n${GREEN}${BOLD}✅ AgencyStack is ready for component installation${NC}\n"
echo -e "${YELLOW}To install components, run commands like:${NC}"
echo -e "  make keycloak DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL"
echo -e "  make preflight DOMAIN=$DOMAIN"
echo -e "  make demo-core DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL"
echo -e "\n${YELLOW}Follow component installation with:${NC}"
echo -e "  make <component>-status"
echo -e "  make <component>-logs"

# Print help on how to validate installation
echo -e "\n${BLUE}${BOLD}🧪 Alpha Installation Validation${NC}"
echo -e "${YELLOW}To validate the full installation, run:${NC}"
echo -e "  make alpha-check DOMAIN=$DOMAIN"

# Create test script to verify component installation
cat > ~/test_keycloak.sh << 'EOL'
#!/bin/bash
# Test Keycloak installation
export DOMAIN="localhost.test"
export ADMIN_EMAIL="admin@localhost.test"
cd ~/projects/agency-stack

# Install Keycloak with complete options
make keycloak DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL WITH_DEPS=true

# Check status
make keycloak-status DOMAIN=$DOMAIN

# Tail logs to verify
make keycloak-logs
EOL

chmod +x ~/test_keycloak.sh

log "Setup complete. Your test script is ready at ~/test_keycloak.sh"
