#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: verify_integration.sh
# Path: /scripts/components/verify_integration.sh
#

# Enforce containerization (prevent host contamination)


# Traefik-Keycloak Integration Verification Script
CLIENT_ID="default"
TRAEFIK_PORT="8090"
KEYCLOAK_PORT="8091"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== Traefik-Keycloak Integration Verification ==="

# Check if containers are running
echo -e "\n\033[0;33mChecking container status:\033[0m"
TRAEFIK_RUNNING=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
KEYCLOAK_RUNNING=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
OAUTH2_RUNNING=$(docker ps -q -f "name=oauth2_proxy_${CLIENT_ID}" 2>/dev/null)

if [ -n "$TRAEFIK_RUNNING" ]; then
  echo -e "\033[0;32m✓ Traefik is running\033[0m"
  echo -e "\033[0;31m✗ Traefik is not running\033[0m"

if [ -n "$KEYCLOAK_RUNNING" ]; then
  echo -e "\033[0;32m✓ Keycloak is running\033[0m"
  echo -e "\033[0;31m✗ Keycloak is not running\033[0m"

if [ -n "$OAUTH2_RUNNING" ]; then
  echo -e "\033[0;32m✓ OAuth2 Proxy is running\033[0m"
  echo -e "\033[0;31m✗ OAuth2 Proxy is not running\033[0m"

# Check network
echo -e "\n\033[0;33mChecking Docker network:\033[0m"
if docker network inspect traefik-net-${CLIENT_ID} &>/dev/null; then
  echo -e "\033[0;32m✓ Docker network exists\033[0m"
  
  # Check containers connected to network
  if docker network inspect traefik-net-${CLIENT_ID} | grep -q "$TRAEFIK_RUNNING"; then
    echo -e "\033[0;32m✓ Traefik is connected to the network\033[0m"
  else
    echo -e "\033[0;31m✗ Traefik is not connected to the network\033[0m"
  fi
  
  if docker network inspect traefik-net-${CLIENT_ID} | grep -q "$KEYCLOAK_RUNNING"; then
    echo -e "\033[0;32m✓ Keycloak is connected to the network\033[0m"
  else
    echo -e "\033[0;31m✗ Keycloak is not connected to the network\033[0m"
  fi
  
  if docker network inspect traefik-net-${CLIENT_ID} | grep -q "$OAUTH2_RUNNING"; then
    echo -e "\033[0;32m✓ OAuth2 Proxy is connected to the network\033[0m"
  else
    echo -e "\033[0;31m✗ OAuth2 Proxy is not connected to the network\033[0m"
  fi
  echo -e "\033[0;31m✗ Docker network doesn't exist\033[0m"

# Check endpoints
echo -e "\n\033[0;33mChecking service endpoints:\033[0m"

# Traefik dashboard
TRAEFIK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
if [ "$TRAEFIK_STATUS" = "401" ] || [ "$TRAEFIK_STATUS" = "302" ]; then
  echo -e "\033[0;32m✓ Traefik dashboard is protected (HTTP $TRAEFIK_STATUS)\033[0m"
elif [ "$TRAEFIK_STATUS" = "200" ]; then
  echo -e "\033[0;33m! Traefik dashboard is accessible without authentication\033[0m"
  echo -e "\033[0;31m✗ Traefik dashboard is not accessible (HTTP $TRAEFIK_STATUS)\033[0m"

# Keycloak
KEYCLOAK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth/" 2>/dev/null)
if [ "$KEYCLOAK_STATUS" = "200" ] || [ "$KEYCLOAK_STATUS" = "302" ] || [ "$KEYCLOAK_STATUS" = "303" ]; then
  echo -e "\033[0;32m✓ Keycloak is accessible (HTTP $KEYCLOAK_STATUS)\033[0m"
  echo -e "\033[0;31m✗ Keycloak is not accessible (HTTP $KEYCLOAK_STATUS)\033[0m"

# OAuth2 Proxy
OAUTH2_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/oauth2/auth" 2>/dev/null)
if [ "$OAUTH2_STATUS" = "302" ] || [ "$OAUTH2_STATUS" = "401" ]; then
  echo -e "\033[0;32m✓ OAuth2 Proxy is working (HTTP $OAUTH2_STATUS)\033[0m"
  echo -e "\033[0;31m✗ OAuth2 Proxy is not functioning properly (HTTP $OAUTH2_STATUS)\033[0m"

echo -e "\n\033[0;33mAccess Information:\033[0m"
echo "- Traefik Dashboard (requires auth): http://localhost:${TRAEFIK_PORT}/dashboard/"
echo "- Keycloak Admin Console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
echo "  Credentials: admin / admin"

echo -e "\n\033[0;33mIntegration Status:\033[0m"
if [ -n "$TRAEFIK_RUNNING" ] && [ -n "$KEYCLOAK_RUNNING" ] && [ -n "$OAUTH2_RUNNING" ] && [ "$TRAEFIK_STATUS" = "302" ] || [ "$TRAEFIK_STATUS" = "401" ]; then
  echo -e "\033[0;32m✓ Integration appears to be working correctly\033[0m"
  echo -e "\033[0;31m✗ Integration has issues that need to be addressed\033[0m"

echo -e "\nVerification complete."
