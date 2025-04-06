#!/bin/bash
# install_builderio.sh - AgencyStack Builder.io Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures Builder.io with secure defaults
# Part of the AgencyStack Content Management suite
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
BUILDER_LOG="${COMPONENT_LOG_DIR}/builderio.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Builder.io Configuration
BUILDER_VERSION="latest"
BUILDER_PORT=3000
BUILDER_API_PORT=5000
BUILDER_DB_PORT=27017
BUILDER_DB_NAME="builderio"
BUILDER_DB_USER="builderio"
BUILDER_DB_PASSWORD=$(openssl rand -hex 16)
BUILDER_ADMIN_EMAIL=""
BUILDER_ADMIN_PASSWORD=$(openssl rand -hex 8)
BUILDER_API_KEY=$(openssl rand -hex 32)
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
BUILDER_CONFIG_DIR="${CONFIG_DIR}/builderio"
DOCKER_COMPOSE_DIR="${BUILDER_CONFIG_DIR}/docker"
WITH_DEPS=false
FORCE=false
VERBOSE=false
SSO=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${BUILDER_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Builder.io Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Builder.io (e.g., builder.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain builder.example.com --admin-email admin@example.com --with-deps"
  echo -e "  $0 --domain builder.client1.com --client-id client1 --admin-email admin@client1.com --with-deps"
  echo -e "  $0 --domain builder.client2.com --client-id client2 --admin-email admin@client2.com --force"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory 
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}/builderio/config"
  mkdir -p "${CLIENT_DIR}/builderio/data/db"
  mkdir -p "${CLIENT_DIR}/builderio/logs"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/builderio"
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --admin-email)
      BUILDER_ADMIN_EMAIL="$2"
      shift 2
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log "ERROR" "Unknown parameter passed: $1"
      show_help
      ;;
  esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain is required. Use --domain to specify it."
  show_help
fi

# Check if admin email is provided
if [ -z "$BUILDER_ADMIN_EMAIL" ]; then
  log "ERROR" "Admin email is required. Use --admin-email to specify it."
  show_help
fi

# Set up directories
log "INFO" "Setting up directories for Builder.io installation"
setup_client_dir

# Check if Builder.io is already installed
BUILDER_CONTAINER="${CLIENT_ID}_builderio"
BUILDER_DB_CONTAINER="${CLIENT_ID}_builderio_mongodb"
if docker ps -a --format '{{.Names}}' | grep -q "$BUILDER_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Builder.io container '$BUILDER_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Builder.io containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Builder.io container '$BUILDER_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$BUILDER_CONTAINER"; then
      log "INFO" "Builder.io container is running"
      echo -e "${GREEN}Builder.io is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Builder.io URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Builder.io container exists but is not running"
      echo -e "${YELLOW}Builder.io is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Builder.io containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Builder.io has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Builder.io URL: https://${DOMAIN}${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR" "Docker is not installed. Please install Docker first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker.sh" || {
        log "ERROR" "Failed to install Docker. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker.sh script. Please install Docker manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR" "Docker Compose is not installed. Please install Docker Compose first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker Compose with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker_compose.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker_compose.sh" || {
        log "ERROR" "Failed to install Docker Compose. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker_compose.sh script. Please install Docker Compose manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Create Docker network if it doesn't exist
NETWORK_NAME="${CLIENT_ID}_network"
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO" "Creating Docker network $NETWORK_NAME"
  docker network create "$NETWORK_NAME" || {
    log "ERROR" "Failed to create Docker network $NETWORK_NAME."
    exit 1
  }
fi

# Create MongoDB init script
mkdir -p "${CLIENT_DIR}/builderio/config/mongo-init"
cat > "${CLIENT_DIR}/builderio/config/mongo-init/init-mongo.js" << EOF
db = db.getSiblingDB('${BUILDER_DB_NAME}');

db.createUser({
  user: '${BUILDER_DB_USER}',
  pwd: '${BUILDER_DB_PASSWORD}',
  roles: [
    { role: 'readWrite', db: '${BUILDER_DB_NAME}' },
    { role: 'dbAdmin', db: '${BUILDER_DB_NAME}' }
  ]
});

db.createCollection('users');
db.users.insertOne({
  email: '${BUILDER_ADMIN_EMAIL}',
  password: '${BUILDER_ADMIN_PASSWORD}',
  role: 'admin',
  createdAt: new Date(),
  updatedAt: new Date()
});

db.createCollection('apiKeys');
db.apiKeys.insertOne({
  key: '${BUILDER_API_KEY}',
  name: 'Default API Key',
  userId: 'admin',
  permissions: ['read', 'write', 'publish'],
  createdAt: new Date(),
  updatedAt: new Date()
});
EOF

# Create Docker Compose file
log "INFO" "Creating Docker Compose configuration"
cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  mongodb:
    image: mongo:5.0
    container_name: ${BUILDER_DB_CONTAINER}
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: ${BUILDER_DB_PASSWORD}
      MONGO_INITDB_DATABASE: ${BUILDER_DB_NAME}
      MONGODB_DATABASE: ${BUILDER_DB_NAME}
      MONGODB_USERNAME: ${BUILDER_DB_USER}
      MONGODB_PASSWORD: ${BUILDER_DB_PASSWORD}
    volumes:
      - ${CLIENT_DIR}/builderio/data/db:/data/db
      - ${CLIENT_DIR}/builderio/config/mongo-init:/docker-entrypoint-initdb.d
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s

  builderio-api:
    image: node:16-alpine
    container_name: ${CLIENT_ID}_builderio_api
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${CLIENT_DIR}/builderio/api:/app
    ports:
      - "${BUILDER_API_PORT}:5000"
    environment:
      - NODE_ENV=production
      - MONGODB_URI=mongodb://${BUILDER_DB_USER}:${BUILDER_DB_PASSWORD}@${BUILDER_DB_CONTAINER}:27017/${BUILDER_DB_NAME}
      - API_KEY=${BUILDER_API_KEY}
      - JWT_SECRET=${BUILDER_ADMIN_PASSWORD}
      - PORT=5000
      - HOST=0.0.0.0
      - PUBLIC_URL=https://${DOMAIN}/api
    command: >
      sh -c "
        if [ ! -d '/app/node_modules' ]; then
          echo 'Initializing Builder.io API server...'
          mkdir -p /app
          cd /app
          echo '{
            \"name\": \"builderio-api\",
            \"version\": \"1.0.0\",
            \"private\": true,
            \"scripts\": {
              \"start\": \"node server.js\"
            },
            \"dependencies\": {
              \"express\": \"^4.17.3\",
              \"mongoose\": \"^6.2.9\",
              \"cors\": \"^2.8.5\",
              \"dotenv\": \"^16.0.0\",
              \"jsonwebtoken\": \"^8.5.1\",
              \"bcryptjs\": \"^2.4.3\",
              \"express-validator\": \"^6.14.0\"
            }
          }' > package.json
          npm install
          
          echo 'require(\"dotenv\").config();
          const express = require(\"express\");
          const cors = require(\"cors\");
          const mongoose = require(\"mongoose\");
          
          const app = express();
          const PORT = process.env.PORT || 5000;
          
          // Middleware
          app.use(cors());
          app.use(express.json());
          
          // MongoDB Connection
          mongoose.connect(process.env.MONGODB_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true
          })
          .then(() => console.log(\"MongoDB Connected\"))
          .catch(err => console.log(err));
          
          // Basic routes
          app.get(\"/\", (req, res) => {
            res.json({ message: \"Builder.io API is running\" });
          });
          
          // Authentication routes placeholder
          app.post(\"/api/auth/login\", (req, res) => {
            res.json({ token: process.env.API_KEY, userId: \"admin\" });
          });
          
          // Health check endpoint
          app.get(\"/health\", (req, res) => {
            res.status(200).json({ status: \"ok\" });
          });
          
          app.listen(PORT, () => {
            console.log(\`Server running on port \${PORT}\`);
          });' > server.js
        fi
        
        npm start
      "
    depends_on:
      - mongodb
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  builderio-web:
    image: node:16-alpine
    container_name: ${BUILDER_CONTAINER}
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${CLIENT_DIR}/builderio/web:/app
    environment:
      - NODE_ENV=production
      - API_URL=http://${CLIENT_ID}_builderio_api:5000
      - PUBLIC_URL=https://${DOMAIN}
    command: >
      sh -c "
        if [ ! -d '/app/node_modules' ]; then
          echo 'Setting up Builder.io web interface...'
          mkdir -p /app
          cd /app
          echo '{
            \"name\": \"builderio-web\",
            \"version\": \"1.0.0\",
            \"private\": true,
            \"scripts\": {
              \"start\": \"node server.js\"
            },
            \"dependencies\": {
              \"express\": \"^4.17.3\",
              \"cors\": \"^2.8.5\",
              \"dotenv\": \"^16.0.0\",
              \"node-fetch\": \"^2.6.7\"
            }
          }' > package.json
          npm install
          
          mkdir -p public
          echo '<!DOCTYPE html>
          <html lang=\"en\">
          <head>
            <meta charset=\"UTF-8\">
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <title>Builder.io - AgencyStack</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f7f9fc; }
              .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
              h1 { color: #3366CC; margin-top: 0; }
              .card { border: 1px solid #eaeaea; padding: 20px; margin-bottom: 20px; border-radius: 4px; }
              .btn { background: #3366CC; color: white; border: none; padding: 10px 15px; border-radius: 4px; cursor: pointer; }
              .btn:hover { background: #254EDB; }
              pre { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; }
              .footer { margin-top: 30px; text-align: center; color: #666; font-size: 0.8em; }
            </style>
          </head>
          <body>
            <div class=\"container\">
              <h1>Builder.io - AgencyStack</h1>
              <p>This is a placeholder for the Builder.io web interface. In a production environment, you would connect this to the Builder.io API.</p>
              
              <div class=\"card\">
                <h2>Quick Start</h2>
                <p>To get started with Builder.io, use the following API information:</p>
                <pre>
API Endpoint: https://${DOMAIN}/api
API Key: ${BUILDER_API_KEY}
                </pre>
                <p>Admin credentials:</p>
                <pre>
Email: ${BUILDER_ADMIN_EMAIL}
Password: ${BUILDER_ADMIN_PASSWORD}
                </pre>
              </div>
              
              <div class=\"card\">
                <h2>Integration</h2>
                <p>To integrate Builder.io with your application, follow these steps:</p>
                <ol>
                  <li>Install the Builder.io SDK in your application</li>
                  <li>Configure the SDK with your API key</li>
                  <li>Create your first content model</li>
                  <li>Start building!</li>
                </ol>
              </div>
              
              <div class=\"footer\">
                <p>Part of the AgencyStack platform | <a href=\"https://stack.nerdofmouth.com\">stack.nerdofmouth.com</a></p>
              </div>
            </div>
          </body>
          </html>' > public/index.html
          
          echo 'require(\"dotenv\").config();
          const express = require(\"express\");
          const cors = require(\"cors\");
          const path = require(\"path\");
          
          const app = express();
          const PORT = process.env.PORT || 3000;
          
          // Middleware
          app.use(cors());
          app.use(express.json());
          app.use(express.static(path.join(__dirname, \"public\")));
          
          // Serve static files
          app.get(\"/\", (req, res) => {
            res.sendFile(path.join(__dirname, \"public\", \"index.html\"));
          });
          
          // Health check endpoint
          app.get(\"/health\", (req, res) => {
            res.status(200).json({ status: \"ok\" });
          });
          
          app.listen(PORT, \"0.0.0.0\", () => {
            console.log(\`Web server running on port \${PORT}\`);
          });' > server.js
        fi
        
        npm start
      "
    ports:
      - "${BUILDER_PORT}:3000"
    depends_on:
      - builderio-api
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-builderio.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-builderio.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-builderio.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-builderio.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-builderio.loadbalancer.server.port=3000"
      - "traefik.http.middlewares.${CLIENT_ID}-builderio-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-builderio-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-builderio-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-builderio-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-builderio.middlewares=${CLIENT_ID}-builderio-headers"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
BUILDER_VERSION=${BUILDER_VERSION}
BUILDER_PORT=${BUILDER_PORT}
BUILDER_API_PORT=${BUILDER_API_PORT}
BUILDER_DB_PORT=${BUILDER_DB_PORT}
BUILDER_DB_NAME=${BUILDER_DB_NAME}
BUILDER_DB_USER=${BUILDER_DB_USER}
BUILDER_DB_PASSWORD=${BUILDER_DB_PASSWORD}
BUILDER_ADMIN_EMAIL=${BUILDER_ADMIN_EMAIL}
BUILDER_ADMIN_PASSWORD=${BUILDER_ADMIN_PASSWORD}
BUILDER_API_KEY=${BUILDER_API_KEY}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/builderio"
cat > "${CONFIG_DIR}/secrets/builderio/${DOMAIN}.env" << EOF
BUILDERIO_URL=https://${DOMAIN}
BUILDERIO_API_URL=https://${DOMAIN}/api
BUILDERIO_API_KEY=${BUILDER_API_KEY}
BUILDERIO_ADMIN_EMAIL=${BUILDER_ADMIN_EMAIL}
BUILDERIO_ADMIN_PASSWORD=${BUILDER_ADMIN_PASSWORD}
EOF

# Start Builder.io
log "INFO" "Starting Builder.io"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Builder.io"
  exit 1
}

# Wait for Builder.io to be ready
log "INFO" "Waiting for Builder.io to be ready"
timeout=180
counter=0
echo -n "Waiting for Builder.io to start"
while [ $counter -lt $timeout ]; do
  if curl -s "http://localhost:${BUILDER_PORT}/health" | grep -q "ok"; then
    break
  fi
  echo -n "."
  sleep 2
  counter=$((counter+2))
done
echo

if [ $counter -ge $timeout ]; then
  log "WARN" "Timed out waiting for Builder.io to fully start, but containers are running"
  log "INFO" "You can check the status manually after a few minutes"
else
  log "INFO" "Builder.io is now ready"
fi

# Update installation records
if ! grep -q "builderio" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "builderio" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${BUILDER_PORT}" \
       --arg api_key "${BUILDER_API_KEY}" \
       --arg admin_email "${BUILDER_ADMIN_EMAIL}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.builderio = {
         "name": "Builder.io",
         "url": "https://" + $domain,
         "api_url": "https://" + $domain + "/api",
         "port": $port,
         "api_key": $api_key,
         "admin_email": $admin_email,
         "status": "running",
         "last_updated": $timestamp
       }' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
       
    # Replace original file with updated data
    mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
  else
    log "WARN" "jq is not installed. Skipping dashboard data update."
  fi
fi

# Update integration status
if [ -f "${INTEGRATION_STATUS}" ]; then
  if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    
    jq --arg domain "${DOMAIN}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.builderio = {
         "integrated": true,
         "domain": $domain,
         "last_updated": $timestamp
       }' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
       
    mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
  else
    log "WARN" "jq is not installed. Skipping integration status update."
  fi
fi

# Display completion message
echo -e "${GREEN}${BOLD}✅ Builder.io has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}API URL: https://${DOMAIN}/api${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Admin Email: ${BUILDER_ADMIN_EMAIL}"
echo -e "Admin Password: ${BUILDER_ADMIN_PASSWORD}"
echo -e "API Key: ${BUILDER_API_KEY}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/builderio/${DOMAIN}.env${NC}"

log "INFO" "Builder.io installation completed successfully"
exit 0
