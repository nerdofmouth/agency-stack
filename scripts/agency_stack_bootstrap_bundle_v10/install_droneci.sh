#!/bin/bash
# install_droneci.sh - Install DroneCI for AgencyStack
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

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  echo -e "${RED}Error: config.env file not found${NC}"
  exit 1
fi

# Load configuration
source /opt/agency_stack/config.env

# Set variables
DRONE_DOMAIN="drone.${PRIMARY_DOMAIN}"
DRONE_DATA_DIR="/opt/agency_stack/data/drone"
DRONE_CONFIG_DIR="/opt/agency_stack/config/drone"
DRONE_RPC_SECRET=$(openssl rand -hex 16)
DRONE_GITHUB_CLIENT_ID=${DRONE_GITHUB_CLIENT_ID:-"your-github-client-id"}
DRONE_GITHUB_CLIENT_SECRET=${DRONE_GITHUB_CLIENT_SECRET:-"your-github-client-secret"}

# Create directories
echo -e "${BLUE}Creating directories for DroneCI...${NC}"
mkdir -p ${DRONE_DATA_DIR}
mkdir -p ${DRONE_CONFIG_DIR}

# Create docker-compose file
echo -e "${BLUE}Creating docker-compose file for DroneCI...${NC}"
cat > ${DRONE_CONFIG_DIR}/docker-compose.yml << EOL
version: '3'

services:
  drone:
    image: drone/drone:2
    container_name: drone_server
    volumes:
      - ${DRONE_DATA_DIR}:/data
    environment:
      - DRONE_GITHUB_CLIENT_ID=${DRONE_GITHUB_CLIENT_ID}
      - DRONE_GITHUB_CLIENT_SECRET=${DRONE_GITHUB_CLIENT_SECRET}
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_SERVER_HOST=${DRONE_DOMAIN}
      - DRONE_SERVER_PROTO=https
      - DRONE_TLS_AUTOCERT=false
    restart: always
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.drone.rule=Host(\`${DRONE_DOMAIN}\`)"
      - "traefik.http.routers.drone.entrypoints=websecure"
      - "traefik.http.routers.drone.tls=true"
      - "traefik.http.routers.drone.tls.certresolver=letsencrypt"
      - "traefik.http.services.drone.loadbalancer.server.port=80"

  drone-runner:
    image: drone/drone-runner-docker:1
    container_name: drone_runner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_RPC_PROTO=https
      - DRONE_RPC_HOST=${DRONE_DOMAIN}
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_RUNNER_NAME=runner-1
    restart: always
    networks:
      - traefik_network
    depends_on:
      - drone

networks:
  traefik_network:
    external: true
EOL

# Start the services
echo -e "${BLUE}Starting DroneCI services...${NC}"
cd ${DRONE_CONFIG_DIR}
docker-compose up -d

# Check if services are running
if docker ps | grep -q "drone_server"; then
  echo -e "${GREEN}DroneCI server successfully installed and running!${NC}"
  echo -e "${CYAN}You can access DroneCI at: https://${DRONE_DOMAIN}${NC}"
  echo -e "${YELLOW}Note: You will need to configure GitHub OAuth for authentication.${NC}"
  echo -e "${YELLOW}Update the GitHub client ID and secret in /opt/agency_stack/config.env${NC}"
else
  echo -e "${RED}Error: DroneCI installation failed. Check the logs for details.${NC}"
  exit 1
fi

echo -e "\n${BLUE}${BOLD}DroneCI Installation Complete${NC}\n"
