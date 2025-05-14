#!/bin/bash

# PeaceFestivalUSA Component Integration Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Component Consistency

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$TRAEFIK_DIR" || -z "$WORDPRESS_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Integrating components for ${CLIENT_ID}"

# Ensure networks are properly connected
log_info "Setting up Docker networks"

# Create the shared network if it doesn't exist
if ! docker network inspect ${CLIENT_ID}_traefik_network >/dev/null 2>&1; then
  log_info "Creating shared traefik network"
  docker network create ${CLIENT_ID}_traefik_network
else
  log_info "Traefik network already exists"
fi

# Ensure docker-compose files have the correct network configuration
log_info "Validating network configuration in docker-compose files"

# Check Traefik docker-compose.yml
if ! grep -q "${CLIENT_ID}_traefik_network" "${TRAEFIK_DIR}/docker-compose.yml"; then
  log_error "Traefik docker-compose.yml is missing the correct network configuration"
  return 1
fi

# Check WordPress docker-compose.yml
if ! grep -q "${CLIENT_ID}_traefik_network" "${WORDPRESS_DIR}/docker-compose.yml"; then
  log_error "WordPress docker-compose.yml is missing the correct network configuration"
  return 1
fi

# Ensure Traefik can route to WordPress
log_info "Configuring Traefik to route to WordPress"

# Check if dynamic configuration exists for WordPress
if [[ ! -f "${TRAEFIK_DIR}/config/dynamic/wordpress.yml" ]]; then
  log_error "Traefik configuration for WordPress not found"
  return 1
fi

# Create proper host entries
log_info "Creating host entries in /etc/hosts"
if ! grep -q "${CLIENT_ID}.${DOMAIN}" /etc/hosts; then
  log_info "Adding ${CLIENT_ID}.${DOMAIN} to /etc/hosts"
  echo "127.0.0.1 ${CLIENT_ID}.${DOMAIN}" >> /etc/hosts
fi

if ! grep -q "traefik.${CLIENT_ID}.${DOMAIN}" /etc/hosts; then
  log_info "Adding traefik.${CLIENT_ID}.${DOMAIN} to /etc/hosts"
  echo "127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN}" >> /etc/hosts
fi

# Start Traefik and WordPress services
log_info "Starting services"

# Start Traefik first
log_info "Starting Traefik service"
cd "${TRAEFIK_DIR}" && docker-compose down || true
cd "${TRAEFIK_DIR}" && docker-compose up -d

# Wait for Traefik to be ready
log_info "Waiting for Traefik to be ready..."
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 >/dev/null; then
    log_info "Traefik is up and running"
    break
  fi
  if [ $i -eq 30 ]; then
    log_warning "Traefik may not be fully ready, but continuing..."
  fi
  echo -n "."
  sleep 2
done

# Start WordPress
log_info "Starting WordPress and MariaDB services"
cd "${WORDPRESS_DIR}" && docker-compose down || true
cd "${WORDPRESS_DIR}" && docker-compose up -d

# Wait for WordPress to be ready
log_info "Waiting for WordPress to be ready..."
for i in {1..60}; do
  if curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.${DOMAIN}" http://localhost:80 >/dev/null; then
    log_info "WordPress is up and running"
    break
  fi
  if [ $i -eq 60 ]; then
    log_warning "WordPress may not be fully ready, but continuing..."
  fi
  echo -n "."
  sleep 2
done

log_info "Creating verification scripts"

# Create a verification script that confirms proper integration
cat > "${INSTALL_DIR}/verify-integration.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Integration Verification Script
# Following AgencyStack Charter v1.0.3 Principles

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_ID=$(basename "$SCRIPT_DIR")
DOMAIN="${DOMAIN:-localhost}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
  local level="$1"
  local message="$2"
  local color="$NC"
  
  case "$level" in
    INFO)  color="$GREEN" ;;
    WARN)  color="$YELLOW" ;;
    ERROR) color="$RED" ;;
  esac
  
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Test function
run_test() {
  local name="$1"
  local command="$2"
  local expected_result="$3"
  
  echo -n "Testing $name... "
  
  local result
  result=$($command)
  
  if [[ "$result" == *"$expected_result"* ]]; then
    echo -e "${GREEN}PASSED${NC}"
    return 0
  else
    echo -e "${RED}FAILED${NC}"
    echo "  Expected: $expected_result"
    echo "  Got: $result"
    return 1
  fi
}

# Start testing
log "INFO" "Starting integration verification for $CLIENT_ID"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  log "ERROR" "Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if Traefik container is running
traefik_running=$(docker ps --filter "name=${CLIENT_ID}_traefik" --format "{{.Status}}" | grep -c "Up")
if [ "$traefik_running" -eq 0 ]; then
  log "ERROR" "Traefik container is not running"
  exit 1
else
  log "INFO" "Traefik container is running"
fi

# Check if WordPress container is running
wp_running=$(docker ps --filter "name=${CLIENT_ID}_wordpress" --format "{{.Status}}" | grep -c "Up")
if [ "$wp_running" -eq 0 ]; then
  log "ERROR" "WordPress container is not running"
  exit 1
else
  log "INFO" "WordPress container is running"
fi

# Check if MariaDB container is running
db_running=$(docker ps --filter "name=${CLIENT_ID}_mariadb" --format "{{.Status}}" | grep -c "Up")
if [ "$db_running" -eq 0 ]; then
  log "ERROR" "MariaDB container is not running"
  exit 1
else
  log "INFO" "MariaDB container is running"
fi

# Check Traefik HTTP endpoint
run_test "Traefik HTTP endpoint" "curl -s -o /dev/null -w '%{http_code}' http://localhost:80" "200"

# Check WordPress through Traefik
run_test "WordPress through Traefik" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80" "200"

# Check WordPress health endpoint
run_test "WordPress health check" "curl -s -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80/wp-content/agencystack-health.php | grep -c 'status'" "1"

# Check Traefik dashboard
run_test "Traefik dashboard" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: traefik.${CLIENT_ID}.${DOMAIN}' http://localhost:80" "401"

log "INFO" "Integration verification completed"
exit 0
EOL

chmod +x "${INSTALL_DIR}/verify-integration.sh"

# Run verification
log_info "Running integration verification"
"${INSTALL_DIR}/verify-integration.sh"

log_info "Integration completed"
