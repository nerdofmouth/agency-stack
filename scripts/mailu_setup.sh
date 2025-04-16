#!/bin/bash
# mailu_setup.sh - Configure Mailu email server for AgencyStack
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

# Improved error handling
function handle_error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  echo "Check logs at /var/log/agency_stack/ for details"
  
  # Log the error
  mkdir -p /var/log/agency_stack
  echo "[$(date)] ERROR: $1" >> /var/log/agency_stack/mailu-setup.log
  
  exit 1
}

# Check for non-interactive mode
NON_INTERACTIVE=false
if [ "$1" == "--non-interactive" ]; then
  NON_INTERACTIVE=true
  echo -e "${BLUE}Running in non-interactive mode with default values${NC}"
fi

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  handle_error "config.env file not found"
fi

# Load configuration
source /opt/agency_stack/config.env

# Set variables
MAILU_DATA_DIR="/opt/agency_stack/data/mailu"
MAILU_CONFIG_DIR="/opt/agency_stack/config/mailu"
MAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
WEBMAIL_DOMAIN="webmail.${PRIMARY_DOMAIN}"
ADMIN_DOMAIN="mailu.${PRIMARY_DOMAIN}"

# Check if Mailu is already installed
if [ -f "${MAILU_CONFIG_DIR}/docker-compose.yml" ]; then
  echo -e "${YELLOW}Mailu is already installed${NC}"
  echo -e "Would you like to reconfigure it? [y/N]"
  read -r reconfigure
  if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Skipping Mailu configuration${NC}"
    exit 0
  fi
fi

# Create directories
echo -e "${BLUE}Creating directories for Mailu...${NC}"
mkdir -p ${MAILU_DATA_DIR}
mkdir -p ${MAILU_CONFIG_DIR}

# Generate secrets
echo -e "${BLUE}Generating secrets for Mailu...${NC}"
SECRET_KEY=$(openssl rand -hex 16)
INITIAL_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Prompt for mail domain
echo -e "${BLUE}Configuring Mailu domains...${NC}"
if [ "$NON_INTERACTIVE" == true ]; then
  MAIL_DOMAIN=${MAIL_DOMAIN}
  WEBMAIL_DOMAIN=${WEBMAIL_DOMAIN}
  ADMIN_DOMAIN=${ADMIN_DOMAIN}
else
  read -p "Primary mail domain [$MAIL_DOMAIN]: " input_mail_domain
  MAIL_DOMAIN=${input_mail_domain:-$MAIL_DOMAIN}

  read -p "Webmail domain [$WEBMAIL_DOMAIN]: " input_webmail_domain
  WEBMAIL_DOMAIN=${input_webmail_domain:-$WEBMAIL_DOMAIN}

  read -p "Admin interface domain [$ADMIN_DOMAIN]: " input_admin_domain
  ADMIN_DOMAIN=${input_admin_domain:-$ADMIN_DOMAIN}
fi

# Configure initial admin account
echo -e "${BLUE}Configuring admin account...${NC}"
if [ "$NON_INTERACTIVE" == true ]; then
  ADMIN_USER="admin"
  ADMIN_EMAIL="admin@$MAIL_DOMAIN"
else
  read -p "Admin username [admin]: " ADMIN_USER
  ADMIN_USER=${ADMIN_USER:-admin}

  read -p "Admin email [admin@$MAIL_DOMAIN]: " ADMIN_EMAIL
  ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$MAIL_DOMAIN}
fi

echo -e "${BLUE}Generated admin password: ${GREEN}$INITIAL_ADMIN_PASSWORD${NC}"
echo -e "${YELLOW}Please save this password or change it after first login${NC}"

# Create .env.mail file
echo -e "${BLUE}Creating Mailu configuration...${NC}"
cat > ${MAILU_CONFIG_DIR}/.env.mail << EOL
# Mailu main configuration
SECRET_KEY=$SECRET_KEY
DOMAIN=$MAIL_DOMAIN
HOSTNAMES=$MAIL_DOMAIN,$WEBMAIL_DOMAIN,$ADMIN_DOMAIN
POSTMASTER=admin
SUBNET=192.168.203.0/24
TRAEFIK_NETWORK=traefik-public

# Features
WEBMAIL=roundcube
ANTISPAM=rspamd
ANTIVIRUS=clamav
WEBDAV=none
FULL_TEXT_SEARCH=off

# Mail settings
MESSAGE_SIZE_LIMIT=50000000
RELAYNETS=172.16.0.0/12, 192.168.0.0/16, 10.0.0.0/8
RELAYHOST=
RELAY_DOMAINS=
DMARC_RUA=admin@$MAIL_DOMAIN
DMARC_RUF=admin@$MAIL_DOMAIN
FETCHMAIL_DELAY=600
RECIPIENT_DELIMITER=+
WELCOME=true
WELCOME_TEMPLATE=

# Web settings
TLS_FLAVOR=letsencrypt
ADMIN=$ADMIN_DOMAIN
WEBMAIL=$WEBMAIL_DOMAIN
API=false
WEB_ADMIN=/admin
API_TOKEN_LIFETIME=3600
RATELIMIT_STORAGE=redis
DISABLE_STATISTICS=False

# Advanced settings
LOG_DRIVER=json-file
COMPOSE_PROJECT_NAME=mailu
EOL

# Create Traefik labels file
echo -e "${BLUE}Creating Traefik configuration...${NC}"
cat > ${MAILU_CONFIG_DIR}/traefik.yml << EOL
labels:
  # Admin UI
  - traefik.enable=true
  - traefik.http.routers.mailu-admin.rule=Host(\`$ADMIN_DOMAIN\`)
  - traefik.http.routers.mailu-admin.entrypoints=websecure
  - traefik.http.routers.mailu-admin.tls=true
  - traefik.http.routers.mailu-admin.tls.certresolver=letsencrypt
  - traefik.http.routers.mailu-admin.service=mailu-admin
  - traefik.http.services.mailu-admin.loadbalancer.server.port=80
  
  # Webmail
  - traefik.http.routers.mailu-webmail.rule=Host(\`$WEBMAIL_DOMAIN\`)
  - traefik.http.routers.mailu-webmail.entrypoints=websecure
  - traefik.http.routers.mailu-webmail.tls=true
  - traefik.http.routers.mailu-webmail.tls.certresolver=letsencrypt
  - traefik.http.routers.mailu-webmail.service=mailu-webmail
  - traefik.http.services.mailu-webmail.loadbalancer.server.port=80
EOL

# Create docker-compose.yml
echo -e "${BLUE}Creating docker-compose configuration...${NC}"
cat > ${MAILU_CONFIG_DIR}/docker-compose.yml << EOL
version: '3.8'

services:
  # Core services
  admin:
    image: ${DOCKER_ORG:-mailu}/admin:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - redis
    networks:
      - default
      - traefik-public
    labels:
      - traefik.enable=true
      - traefik.http.routers.mailu-admin.rule=Host(\`${ADMIN_DOMAIN}\`)
      - traefik.http.routers.mailu-admin.entrypoints=websecure
      - traefik.http.routers.mailu-admin.tls=true
      - traefik.http.routers.mailu-admin.tls.certresolver=letsencrypt
      - traefik.http.services.mailu-admin.loadbalancer.server.port=80

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - "${MAILU_DATA_DIR}/redis:/data"
    networks:
      - default

  front:
    image: ${DOCKER_ORG:-mailu}/nginx:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "110:110"
      - "143:143"
      - "993:993"
      - "995:995"
    networks:
      - default
      - traefik-public
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - admin

  imap:
    image: ${DOCKER_ORG:-mailu}/dovecot:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - front
    networks:
      - default

  smtp:
    image: ${DOCKER_ORG:-mailu}/postfix:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - front
    networks:
      - default

  antispam:
    image: ${DOCKER_ORG:-mailu}/rspamd:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - front
    networks:
      - default

  antivirus:
    image: ${DOCKER_ORG:-mailu}/clamav:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}:/data"
      - "/opt/agency_stack/secrets:/secrets"
    depends_on:
      - front
    networks:
      - default

  webmail:
    image: ${DOCKER_ORG:-mailu}/roundcube:${MAILU_VERSION:-1.9}
    restart: always
    env_file: .env.mail
    volumes:
      - "${MAILU_DATA_DIR}/webmail:/data"
    depends_on:
      - front
    networks:
      - default
      - traefik-public
    labels:
      - traefik.enable=true
      - traefik.http.routers.mailu-webmail.rule=Host(\`${WEBMAIL_DOMAIN}\`)
      - traefik.http.routers.mailu-webmail.entrypoints=websecure
      - traefik.http.routers.mailu-webmail.tls=true
      - traefik.http.routers.mailu-webmail.tls.certresolver=letsencrypt
      - traefik.http.services.mailu-webmail.loadbalancer.server.port=80

networks:
  default:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.203.0/24
  traefik-public:
    external: true
EOL

# Create DNS guide file
echo -e "${BLUE}Creating DNS configuration guide...${NC}"
cat > ${MAILU_CONFIG_DIR}/dns_setup.txt << EOL
# DNS RECORDS FOR MAILU EMAIL SERVER
# =================================
# Add these DNS records to your domain's DNS configuration

# MX RECORD
${MAIL_DOMAIN}.    IN MX 10 ${MAIL_DOMAIN}.

# A RECORDS
${MAIL_DOMAIN}.    IN A <YOUR_SERVER_IP>
${WEBMAIL_DOMAIN}. IN A <YOUR_SERVER_IP>
${ADMIN_DOMAIN}.   IN A <YOUR_SERVER_IP>

# SPF RECORD
${MAIL_DOMAIN}.    IN TXT "v=spf1 mx ip4:<YOUR_SERVER_IP> -all"

# DKIM RECORD
# After Mailu is running, get your DKIM key with:
# docker-compose -f ${MAILU_CONFIG_DIR}/docker-compose.yml exec admin dkim_export

# DMARC RECORD
_dmarc.${MAIL_DOMAIN}. IN TXT "v=DMARC1; p=reject; rua=mailto:admin@${MAIL_DOMAIN}; ruf=mailto:admin@${MAIL_DOMAIN}; fo=1"

# Optional records for better deliverability:
# ===========================================
# Autodiscover for Outlook
autodiscover.${MAIL_DOMAIN}. IN CNAME ${MAIL_DOMAIN}.
_autodiscover._tcp.${MAIL_DOMAIN}. IN SRV 0 1 443 ${MAIL_DOMAIN}.

# Autoconfig for Thunderbird
autoconfig.${MAIL_DOMAIN}. IN CNAME ${MAIL_DOMAIN}.
EOL

# Create first admin user
echo -e "${BLUE}Creating initial admin user configuration...${NC}"
mkdir -p ${MAILU_DATA_DIR}/first-user
cat > ${MAILU_DATA_DIR}/first-user/setup.json << EOL
{
  "username": "${ADMIN_USER}",
  "domain": "${MAIL_DOMAIN}",
  "password": "${INITIAL_ADMIN_PASSWORD}",
  "email": "${ADMIN_EMAIL}"
}
EOL

# Create mailu_test_email.sh script
echo -e "${BLUE}Creating test email script...${NC}"
cat > /opt/agency_stack/scripts/mailu_test_email.sh << EOL
#!/bin/bash
# mailu_test_email.sh - Test Mailu email sending
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  echo -e "\${RED}Error: config.env file not found\${NC}"
  exit 1
fi

# Load configuration
source /opt/agency_stack/config.env

# Check if Mailu is running
if ! docker ps --format '{{.Names}}' | grep -q "mailu"; then
  echo -e "\${RED}Error: Mailu containers are not running\${NC}"
  echo -e "Start Mailu first with: cd /opt/agency_stack/config/mailu && docker-compose up -d"
  exit 1
fi

# Prompt for recipient email
echo -e "\${BLUE}Enter recipient email address:\${NC}"
read -r RECIPIENT_EMAIL

if [ -z "\$RECIPIENT_EMAIL" ]; then
  echo -e "\${RED}Error: No recipient email provided\${NC}"
  exit 1
fi

# Send test email using Docker
echo -e "\${BLUE}Sending test email to \${RECIPIENT_EMAIL}...\${NC}"
docker exec \$(docker ps --filter name=mailu_smtp --format "{{.ID}}") sendmail -t << EOF
From: AgencyStack Mailu <admin@${MAIL_DOMAIN}>
To: \${RECIPIENT_EMAIL}
Subject: AgencyStack Mailu Test Email

This is a test email from your AgencyStack Mailu installation.
If you received this email, your email server is working correctly.

Time sent: \$(date)
Server: \$(hostname)

For help and documentation, visit:
https://stack.nerdofmouth.com
EOF

if [ \$? -eq 0 ]; then
  echo -e "\${GREEN}✅ Email sent successfully!\${NC}"
  echo -e "Please check \${RECIPIENT_EMAIL} for the test email"
else
  echo -e "\${RED}❌ Failed to send email\${NC}"
  echo -e "Please check the logs: docker logs \$(docker ps --filter name=mailu_smtp --format "{{.ID}}")"
fi
EOF

chmod +x /opt/agency_stack/scripts/mailu_test_email.sh

# Update SMTP config in config.env
echo -e "${BLUE}Updating SMTP configuration in config.env...${NC}"
sed -i '/SMTP_ENABLED/d' /opt/agency_stack/config.env
sed -i '/SMTP_HOST/d' /opt/agency_stack/config.env
sed -i '/SMTP_PORT/d' /opt/agency_stack/config.env
sed -i '/SMTP_USERNAME/d' /opt/agency_stack/config.env
sed -i '/SMTP_PASSWORD/d' /opt/agency_stack/config.env
sed -i '/SMTP_FROM/d' /opt/agency_stack/config.env

cat >> /opt/agency_stack/config.env << EOL

# SMTP Configuration (Mailu)
SMTP_ENABLED=true
SMTP_HOST=mailu
SMTP_PORT=25
SMTP_USERNAME=admin@${MAIL_DOMAIN}
SMTP_PASSWORD=${INITIAL_ADMIN_PASSWORD}
SMTP_FROM=noreply@${MAIL_DOMAIN}
EOL

echo -e "${GREEN}✅ Mailu configuration complete!${NC}"
echo -e "${BLUE}To start Mailu, run:${NC}"
echo -e "  cd ${MAILU_CONFIG_DIR} && docker-compose up -d"
echo -e ""
echo -e "${BLUE}Admin interface:${NC} https://${ADMIN_DOMAIN}"
echo -e "${BLUE}Webmail:${NC} https://${WEBMAIL_DOMAIN}"
echo -e "${BLUE}Admin username:${NC} ${ADMIN_USER}@${MAIL_DOMAIN}"
echo -e "${BLUE}Admin password:${NC} ${INITIAL_ADMIN_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Set up your DNS records according to:${NC}"
echo -e "  ${MAILU_CONFIG_DIR}/dns_setup.txt"
echo -e ""
echo -e "${GREEN}After Mailu is running, you can export your DKIM keys with:${NC}"
echo -e "  docker-compose -f ${MAILU_CONFIG_DIR}/docker-compose.yml exec admin dkim_export"
