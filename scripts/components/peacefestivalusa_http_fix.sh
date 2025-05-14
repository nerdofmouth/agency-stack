#!/bin/bash

# PeaceFestivalUSA HTTP-Only Fix and Testing Script
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - TDD Protocol
# - Auditability & Documentation
# - Proper Change Workflow

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  # Minimal logging if common.sh is not available
  log_info() { echo "[INFO] $1"; }
  log_error() { echo "[ERROR] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
fi

# Constants
CLIENT_ID="peacefestivalusa"
CLIENT_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
WP_DIR="${CLIENT_DIR}/wordpress"
TRAEFIK_DIR="${CLIENT_DIR}/traefik"
TEST_LOG="${CLIENT_DIR}/deployment_test.log"

log_info "Starting PeaceFestivalUSA HTTP Fix and Testing..."

# Create a test directory for test artifacts
mkdir -p "${CLIENT_DIR}/tests"

# Step 1: Fix Traefik Configuration - HTTP Only for Local Dev
log_info "Configuring Traefik for HTTP-only mode (local dev)..."

cat > "${TRAEFIK_DIR}/config/traefik.yml" << 'EOL'
# Traefik Static Configuration (HTTP-only for local dev)
# Following AgencyStack Charter v1.0.3 principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: "INFO"
  filePath: "/logs/traefik.log"

api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-network
  
  file:
    directory: "/config/dynamic"
    watch: true
EOL

# Create clear file-based router configuration
mkdir -p "${TRAEFIK_DIR}/config/dynamic"
cat > "${TRAEFIK_DIR}/config/dynamic/routes.yml" << 'EOL'
http:
  routers:
    wordpress:
      rule: "Host(`peacefestivalusa.localhost`)"
      service: wordpress
      entryPoints:
        - web
    
    traefik:
      rule: "Host(`traefik.peacefestivalusa.localhost`)"
      service: api@internal
      entryPoints:
        - web
      middlewares:
        - auth

  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
          
  services:
    wordpress:
      loadBalancer:
        servers:
          - url: "http://peacefestivalusa_wordpress:80"
EOL

# Step 2: Update Traefik docker-compose.yml
log_info "Updating Traefik docker-compose.yml..."

cat > "${TRAEFIK_DIR}/docker-compose.yml" << 'EOL'
services:
  traefik:
    container_name: peacefestivalusa_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/agency_stack/clients/peacefestivalusa/traefik/config/traefik.yml:/etc/traefik/traefik.yml
      - /opt/agency_stack/clients/peacefestivalusa/traefik/config/dynamic:/etc/traefik/config/dynamic
      - /opt/agency_stack/clients/peacefestivalusa/traefik/logs:/logs
    networks:
      - traefik-network

networks:
  traefik-network:
    name: traefik-network
    driver: bridge
EOL

# Step 3: Update WordPress docker-compose.yml
log_info "Updating WordPress docker-compose.yml..."

cat > "${WP_DIR}/docker-compose.yml" << 'EOL'
services:
  mariadb:
    container_name: peacefestivalusa_mariadb
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/mariadb-data:/var/lib/mysql
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/init-scripts:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: laTOUff1wXPFPov5
      MYSQL_DATABASE: peacefestivalusa_wordpress
      MYSQL_USER: peacefestivalusa_wp
      MYSQL_PASSWORD: 5oOqapxbb98hQPov
      MYSQL_ALLOW_EMPTY_PASSWORD: "no"
      MYSQL_ROOT_HOST: "%"
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-plaTOUff1wXPFPov5"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wordpress_network
    ports:
      - "33060:3306"

  wordpress:
    container_name: peacefestivalusa_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
    depends_on:
      - mariadb
    volumes:
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/wp-content:/var/www/html/wp-content
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/wp-config/wp-config-agency.php:/tmp/wp-config-agency.php
    env_file:
      - /opt/agency_stack/clients/peacefestivalusa/wordpress/.env
    entrypoint: ["/usr/local/bin/custom-entrypoint.sh"]
    command: ["apache2-foreground"]
    environment:
      - WORDPRESS_CONFIG_EXTRA=define('WP_SITEURL', 'http://peacefestivalusa.localhost'); define('WP_HOME', 'http://peacefestivalusa.localhost');
    networks:
      - wordpress_network
      - traefik-network
    ports:
      - "8082:80"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.peacefestivalusa.rule=Host(`peacefestivalusa.localhost`)"
      - "traefik.http.routers.peacefestivalusa.entrypoints=web"
      - "traefik.http.services.peacefestivalusa.loadbalancer.server.port=80"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/wp-content/verify-deployment.php"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  wordpress_network:
    driver: bridge
  traefik-network:
    external: true
EOL

# Step 4: Create a comprehensive test script
log_info "Creating test script for automated deployment verification..."

cat > "${CLIENT_DIR}/tests/test_deployment.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Deployment Test Script
# Following AgencyStack Charter v1.0.3 principles:
# - TDD Protocol
# - Auditability & Documentation
# - Repository as Source of Truth

# Initialize test results
TEST_RESULTS=()
TEST_PASSED=0
TEST_FAILED=0
CLIENT_ID="peacefestivalusa"
TEST_LOG="/opt/agency_stack/clients/${CLIENT_ID}/tests/test_results.log"

# Clear previous test log
echo "# PeaceFestivalUSA Deployment Tests" > "$TEST_LOG"
echo "Date: $(date)" >> "$TEST_LOG"
echo "----------------------------" >> "$TEST_LOG"

# Function to run a test
run_test() {
  local test_name="$1"
  local test_command="$2"
  local expected_status="$3"
  
  echo -n "Running test: $test_name... "
  
  # Run the test command
  eval "$test_command" > /tmp/test_output 2>&1
  local status=$?
  
  # Check if test passed or failed
  if [[ "$status" -eq "$expected_status" ]]; then
    echo "PASSED"
    TEST_PASSED=$((TEST_PASSED + 1))
    TEST_RESULTS+=("✅ $test_name: PASSED")
    echo "✅ $test_name: PASSED" >> "$TEST_LOG"
  else
    echo "FAILED (expected: $expected_status, got: $status)"
    TEST_FAILED=$((TEST_FAILED + 1))
    TEST_RESULTS+=("❌ $test_name: FAILED (expected: $expected_status, got: $status)")
    echo "❌ $test_name: FAILED (expected: $expected_status, got: $status)" >> "$TEST_LOG"
    echo "Command output:" >> "$TEST_LOG"
    cat /tmp/test_output >> "$TEST_LOG"
    echo "----------------------------" >> "$TEST_LOG"
  fi
}

# Test 1: Check if Docker is running
run_test "Docker Running" "docker info" 0

# Test 2: Check if Traefik container is running
run_test "Traefik Container Running" "docker ps | grep -q peacefestivalusa_traefik" 0

# Test 3: Check if WordPress container is running
run_test "WordPress Container Running" "docker ps | grep -q peacefestivalusa_wordpress" 0

# Test 4: Check if MariaDB container is running
run_test "MariaDB Container Running" "docker ps | grep -q peacefestivalusa_mariadb" 0

# Test 5: Check if Traefik is accessible via HTTP
run_test "Traefik HTTP Access" "curl -s -o /dev/null -w '%{http_code}' http://traefik.peacefestivalusa.localhost/dashboard/ | grep -q 401" 0

# Test 6: Check if WordPress is accessible via HTTP
run_test "WordPress HTTP Access" "curl -s -o /dev/null -w '%{http_code}' http://peacefestivalusa.localhost/ | grep -q 200" 0

# Test 7: Check WordPress direct port access
run_test "WordPress Direct Port Access" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8082/ | grep -q 200" 0

# Test 8: Check WordPress database connection
run_test "WordPress Database Connection" "curl -s http://peacefestivalusa.localhost/wp-content/verify-deployment.php | grep -q 'database_connection.*pass'" 0

# Print test summary
echo ""
echo "==========================="
echo "TEST SUMMARY"
echo "==========================="
echo "Total tests: $((TEST_PASSED + TEST_FAILED))"
echo "Passed: $TEST_PASSED"
echo "Failed: $TEST_FAILED"
echo ""

# Print detailed results
echo "DETAILED RESULTS:"
for result in "${TEST_RESULTS[@]}"; do
  echo "$result"
done

# Add test summary to log
echo "" >> "$TEST_LOG"
echo "==========================" >> "$TEST_LOG"
echo "TEST SUMMARY" >> "$TEST_LOG"
echo "==========================" >> "$TEST_LOG"
echo "Total tests: $((TEST_PASSED + TEST_FAILED))" >> "$TEST_LOG"
echo "Passed: $TEST_PASSED" >> "$TEST_LOG"
echo "Failed: $TEST_FAILED" >> "$TEST_LOG"

# Exit with error if any test failed
if [[ "$TEST_FAILED" -gt 0 ]]; then
  exit 1
else
  exit 0
fi
EOL

# Make test script executable
chmod +x "${CLIENT_DIR}/tests/test_deployment.sh"

# Step 5: Deploy and restart services
log_info "Restarting Traefik and WordPress containers..."

# Stop and remove all containers
docker-compose -f "${TRAEFIK_DIR}/docker-compose.yml" down
docker-compose -f "${WP_DIR}/docker-compose.yml" down

# Start Traefik first
docker-compose -f "${TRAEFIK_DIR}/docker-compose.yml" up -d
# Give Traefik a moment to start
sleep 3

# Start WordPress
docker-compose -f "${WP_DIR}/docker-compose.yml" up -d

# Step 6: Update hosts file if needed (using echo to show the command)
log_info "Please ensure you have the following entries in your /etc/hosts file:"
echo "127.0.0.1 peacefestivalusa.localhost traefik.peacefestivalusa.localhost"

# Step 7: Wait for services to stabilize
log_info "Waiting for services to stabilize (30 seconds)..."
sleep 30

# Step 8: Run tests
log_info "Running deployment tests..."
"${CLIENT_DIR}/tests/test_deployment.sh"
TEST_STATUS=$?

if [ $TEST_STATUS -eq 0 ]; then
    log_success "All tests passed! PeaceFestivalUSA deployment is working correctly."
    log_info "Access WordPress at: http://peacefestivalusa.localhost or http://localhost:8082"
    log_info "Access Traefik dashboard at: http://traefik.peacefestivalusa.localhost"
    log_info "Traefik dashboard credentials: admin/admin123"
else
    log_error "Some tests failed. Please check test results at ${CLIENT_DIR}/tests/test_results.log"
fi

# Step 9: Integrate this testing into the deployment process
log_info "Adding test script to the deployment workflow..."

DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy_peacefestivalusa_full.sh"
if [ -f "$DEPLOY_SCRIPT" ]; then
    # Check if test integration is already added
    if ! grep -q "test_deployment.sh" "$DEPLOY_SCRIPT"; then
        # Add test step to deployment script before the success message
        sed -i '/log_success "Script completed successfully"/i \
# Run deployment tests\nlog_info "Running deployment tests..."\n"${CLIENT_DIR}/tests/test_deployment.sh"\nif [ $? -ne 0 ]; then\n  log_error "Deployment tests failed! Check test_results.log for details."\n  exit 1\nfi' "$DEPLOY_SCRIPT"
        log_success "Successfully added testing to deployment workflow."
    else
        log_info "Testing already integrated into deployment workflow."
    fi
else
    log_error "Deployment script not found at ${DEPLOY_SCRIPT}."
fi

log_success "HTTP fix and testing integration completed!"
