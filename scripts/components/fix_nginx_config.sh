#!/bin/bash
# fix_nginx_config.sh - Ensure Nginx config file is a file, not a directory, and create minimal config if missing
# AgencyStack Alpha/Beta: WSL2 & Docker prototype fix sequence

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLIENT_ID="${CLIENT_ID:-default}"
NGINX_CONFIG_FILE="/opt/agency_stack/clients/${CLIENT_ID}/nginx/default.conf"

# Ensure parent directory exists
mkdir -p "$(dirname "$NGINX_CONFIG_FILE")"

if [ -d "$NGINX_CONFIG_FILE" ]; then
  echo -e "${YELLOW}[WARN] Removing directory at $NGINX_CONFIG_FILE (should be a file)${NC}"
  rm -rf "$NGINX_CONFIG_FILE"
fi

if [ ! -f "$NGINX_CONFIG_FILE" ]; then
  echo -e "${GREEN}[INFO] Creating minimal default.conf at $NGINX_CONFIG_FILE${NC}"
  cat > "$NGINX_CONFIG_FILE" <<EOL
server {
    listen 80;
    server_name _;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOL
fi

echo -e "${GREEN}[SUCCESS] Nginx config file is now valid at $NGINX_CONFIG_FILE${NC}"

# Compose volume mapping guidance
echo -e "\n${YELLOW}In your docker-compose.yml, use this volume mapping:${NC}"
echo -e "  - /opt/agency_stack/clients/${CLIENT_ID}/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro"
