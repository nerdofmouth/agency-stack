#!/bin/bash
# install_builderio.sh - Install Builder.io for AgencyStack
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
BUILDER_DOMAIN="builder.${PRIMARY_DOMAIN}"
BUILDER_DATA_DIR="/opt/agency_stack/data/builder"
BUILDER_CONFIG_DIR="/opt/agency_stack/config/builder"

# Check if Builder.io API key is set
if [ -z "${BUILDER_API_KEY}" ] || [ "${BUILDER_API_KEY}" == "" ]; then
  echo -e "${YELLOW}Warning: BUILDER_API_KEY is not set in config.env${NC}"
  echo -e "${YELLOW}You will need to sign up for a Builder.io account to get an API key.${NC}"
  echo -e "${YELLOW}Visit: https://builder.io to create an account and get an API key.${NC}"
  
  # Prompt for API key
  read -p "Would you like to enter a Builder.io API key now? (y/n): " ENTER_KEY
  if [[ "$ENTER_KEY" == "y" || "$ENTER_KEY" == "Y" ]]; then
    read -p "Enter your Builder.io API key: " BUILDER_API_KEY
    
    # Update config.env with the new API key
    sed -i "s/BUILDER_API_KEY=.*/BUILDER_API_KEY=${BUILDER_API_KEY}/" /opt/agency_stack/config.env
    echo -e "${GREEN}API key updated in config.env${NC}"
  else
    echo -e "${YELLOW}Continuing with installation, but you will need to set the API key later.${NC}"
    BUILDER_API_KEY="your-api-key-here"
  fi
fi

# Create directories
echo -e "${BLUE}Creating directories for Builder.io...${NC}"
mkdir -p ${BUILDER_DATA_DIR}
mkdir -p ${BUILDER_CONFIG_DIR}

# Create docker-compose file
echo -e "${BLUE}Creating docker-compose file for Builder.io integration...${NC}"
cat > ${BUILDER_CONFIG_DIR}/docker-compose.yml << EOL
version: '3'

services:
  builder-proxy:
    image: nginx:alpine
    container_name: builder_proxy
    volumes:
      - ${BUILDER_CONFIG_DIR}/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ${BUILDER_DATA_DIR}/html:/usr/share/nginx/html
    restart: always
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.builder.rule=Host(\`${BUILDER_DOMAIN}\`)"
      - "traefik.http.routers.builder.entrypoints=websecure"
      - "traefik.http.routers.builder.tls=true"
      - "traefik.http.routers.builder.tls.certresolver=letsencrypt"
      - "traefik.http.services.builder.loadbalancer.server.port=80"

networks:
  traefik_network:
    external: true
EOL

# Create nginx configuration
cat > ${BUILDER_CONFIG_DIR}/nginx.conf << EOL
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOL

# Create Builder.io integration example
mkdir -p ${BUILDER_DATA_DIR}/html
cat > ${BUILDER_DATA_DIR}/html/index.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Builder.io Integration</title>
    <script async src="https://cdn.builder.io/js/webcomponents"></script>
</head>
<body>
    <h1>Builder.io Integration Example</h1>
    <p>This is a simple example of Builder.io integration.</p>
    
    <!-- Builder.io Content Entry -->
    <builder-component model="page" api-key="${BUILDER_API_KEY}">
        <!-- Default content shown while Builder content is loading or if no matching content entry is found -->
        <div style="padding: 20px; text-align: center;">
            <p>No content has been published yet.</p>
            <p>Once you publish content at <a href="https://builder.io" target="_blank">builder.io</a>, it will display here.</p>
        </div>
    </builder-component>
    
    <script>
        // Optional JS for more advanced Builder.io usage
        var builder = document.querySelector('builder-component');
        builder.addEventListener('load', function(event) {
            console.log('Builder content loaded!');
        });
        builder.addEventListener('error', function(event) {
            console.error('Builder content error!', event.detail);
        });
    </script>
</body>
</html>
EOL

# Create README file with instructions
cat > ${BUILDER_CONFIG_DIR}/README.md << EOL
# Builder.io Integration for AgencyStack

This directory contains configuration for the Builder.io integration in AgencyStack.

## Getting Started

1. Sign up for a Builder.io account at https://builder.io
2. Get your API key from the Builder.io dashboard
3. Update your API key in /opt/agency_stack/config.env
4. Create content models in Builder.io
5. Publish content to see it on your site

## Integration Options

Builder.io can be integrated with various CMS and frontend frameworks:
- WordPress
- React
- Vue
- Angular
- And more!

For detailed integration guides, visit: https://www.builder.io/c/docs/getting-started

## Support

For help with Builder.io integration, visit: https://forum.builder.io
EOL

# Start the services
echo -e "${BLUE}Starting Builder.io proxy service...${NC}"
cd ${BUILDER_CONFIG_DIR}
docker-compose up -d

# Check if service is running
if docker ps | grep -q "builder_proxy"; then
  echo -e "${GREEN}Builder.io proxy successfully installed and running!${NC}"
  echo -e "${CYAN}You can access the Builder.io integration at: https://${BUILDER_DOMAIN}${NC}"
  echo -e "${YELLOW}Important: You will need to create content in Builder.io dashboard to see it on your site.${NC}"
  echo -e "${YELLOW}Visit: https://builder.io to manage your content.${NC}"
else
  echo -e "${RED}Error: Builder.io proxy installation failed. Check the logs for details.${NC}"
  exit 1
fi

echo -e "\n${BLUE}${BOLD}Builder.io Integration Complete${NC}\n"
echo -e "${YELLOW}Remember to set your API key in /opt/agency_stack/config.env if you haven't done so.${NC}"
