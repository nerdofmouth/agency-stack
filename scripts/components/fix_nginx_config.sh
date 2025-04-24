#!/bin/bash
# fix_nginx_config.sh - Ensure Nginx config file is a file, not a directory, and create minimal config if missing
# AgencyStack Alpha/Beta: WSL2 & Docker prototype fix sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source common utilities if available
if [ -f "$REPO_ROOT/scripts/utils/common.sh" ]; then
  source "$REPO_ROOT/scripts/utils/common.sh"
fi

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Define paths
CLIENT_ID="${CLIENT_ID:-default}"
NGINX_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/nginx"
NGINX_CONFIG_FILE="${NGINX_CONFIG_DIR}/default.conf"

# Create directory if it doesn't exist
mkdir -p "$NGINX_CONFIG_DIR"

# CRITICAL: Remove any existing directory at the config file path (WSL2/Docker fix)
if [ -d "$NGINX_CONFIG_FILE" ]; then
  echo -e "${YELLOW}[WARN] Removing directory at $NGINX_CONFIG_FILE (should be a file)${NC}"
  rm -rf "$NGINX_CONFIG_FILE"
fi

# Create a minimal valid nginx config file if it doesn't exist
if [ ! -f "$NGINX_CONFIG_FILE" ]; then
  echo -e "${BLUE}[INFO] Creating minimal valid nginx config file at $NGINX_CONFIG_FILE${NC}"
  
  # Docker-compatible nginx configuration that doesn't rely on external snippets
  cat > "$NGINX_CONFIG_FILE" <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # PHP handling without external snippets
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }

    # Security: Deny access to hidden files
    location ~ /\. {
        deny all;
    }
    # Prevent PHP execution in uploads directory
    location ~* /(?:uploads|files)/.*.php$ {
        deny all;
    }

    error_log  /var/log/nginx/error.log warn;
    access_log /var/log/nginx/access.log;
}
EOF
fi

# Ensure proper permissions
chmod 644 "$NGINX_CONFIG_FILE"

echo -e "${GREEN}[SUCCESS] Nginx config file is now valid at $NGINX_CONFIG_FILE${NC}"
echo ""
echo "In your docker-compose.yml, use this volume mapping:"
echo "  - $NGINX_CONFIG_FILE:/etc/nginx/conf.d/default.conf:ro"
