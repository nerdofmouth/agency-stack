#!/bin/bash

# Quick fix script to make Traefik dashboard accessible from host
# Following the AgencyStack Repository Integrity Policy

# Cleanup any existing traefik containers
echo "Cleaning up existing Traefik containers..."
docker rm -f traefik_default 2>/dev/null || true

# Create necessary directories
TRAEFIK_DIR="/root/_repos/agency-stack/services/traefik/default"
mkdir -p $TRAEFIK_DIR/config
mkdir -p $TRAEFIK_DIR/dynamic

# Create config file
echo "Creating configuration file..."
cat > $TRAEFIK_DIR/config/traefik.yml <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8081"

providers:
  file:
    directory: "/etc/traefik/dynamic"

# Global configuration
global:
  checkNewVersion: false
  sendAnonymousUsage: false
EOF

# Start container with proper port mapping
echo "Starting Traefik container with proper port mapping..."
docker run -d --name traefik_default \
  -p 8081:8081 \
  -p 80:80 \
  -v $TRAEFIK_DIR/config/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v $TRAEFIK_DIR/dynamic:/etc/traefik/dynamic:ro \
  traefik:v2.6.3

# Verify container started
if [ "$(docker ps -q -f name=traefik_default)" ]; then
  echo "✅ Traefik container started successfully"
  echo "Dashboard accessible at: http://localhost:8081/dashboard/"
  
  # Test dashboard accessibility
  sleep 2
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/dashboard/)
  
  if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Dashboard test successful (HTTP $HTTP_CODE)"
    echo "You can open http://localhost:8081/dashboard/ in your browser"
  else
    echo "⚠️ Dashboard returned HTTP $HTTP_CODE - might need a moment to initialize"
    echo "Please try opening http://localhost:8081/dashboard/ manually in a few seconds"
  fi
else
  echo "❌ Failed to start Traefik container"
  docker logs traefik_default
fi
