#!/bin/bash
# test_peacefestivalusa_wordpress.sh - Test Peace Festival USA WordPress installation
# Following TDD Protocol and AgencyStack Charter

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

if [ -f "${SCRIPTS_DIR}/utils/common.sh" ]; then
  source "${SCRIPTS_DIR}/utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Client-specific variables
CLIENT_ID="peacefestivalusa"
DOMAIN="${DOMAIN:-peacefestivalusa.nerdofmouth.com}"
CONTAINER_NAME="peacefestivalusa_wordpress"

echo "=== Peace Festival USA WordPress TDD Test Suite ==="
echo "Domain: $DOMAIN"
echo "Client ID: $CLIENT_ID"
echo "Container: $CONTAINER_NAME"
echo ""

# Function for unit tests
run_unit_tests() {
  echo "📋 Running Unit Tests..."
  
  # Test 1: WordPress container exists
  echo "🧪 Test 1: WordPress container exists"
  if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "✅ PASS: WordPress container exists"
  else
    echo "❌ FAIL: WordPress container does not exist"
    return 1
  fi
  
  # Test 2: WordPress container is running
  echo "🧪 Test 2: WordPress container is running"
  if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ PASS: WordPress container is running"
  else
    echo "❌ FAIL: WordPress container is not running"
    return 1
  fi
  
  # Test 3: WordPress container health
  echo "🧪 Test 3: WordPress container health"
  CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
  if [ "$CONTAINER_STATUS" = "running" ]; then
    echo "✅ PASS: WordPress container is healthy"
  else
    echo "❌ FAIL: WordPress container is not healthy ($CONTAINER_STATUS)"
    return 1
  fi
  
  echo "✅ All unit tests passed!"
  return 0
}

# Function for integration tests
run_integration_tests() {
  echo "🔄 Running Integration Tests..."
  
  # Test 1: Database container is running
  echo "🧪 Test 1: Database container is running"
  if docker ps | grep -q "peacefestivalusa_mariadb"; then
    echo "✅ PASS: Database container is running"
  else
    echo "❌ FAIL: Database container is not running"
    return 1
  fi
  
  # Test 2: Database connection from WordPress container
  echo "🧪 Test 2: Database connection from WordPress container"
  echo "Debugging Database Configuration:"
  echo "================================="
  echo "🔍 WordPress environment variables:"
  docker exec "$CONTAINER_NAME" bash -c "echo WORDPRESS_DB_HOST=\$WORDPRESS_DB_HOST; echo WORDPRESS_DB_USER=\$WORDPRESS_DB_USER; echo WORDPRESS_DB_NAME=\$WORDPRESS_DB_NAME"
  
  echo "🔍 Attempting to ping database from WordPress container:"
  docker exec "$CONTAINER_NAME" bash -c "ping -c 1 mariadb || echo 'Network connectivity issue'"
  
  echo "🔍 Attempting database connection from WordPress container:"
  if docker exec "$CONTAINER_NAME" bash -c "mysql -h mariadb -u \$WORDPRESS_DB_USER -p\$WORDPRESS_DB_PASSWORD \$WORDPRESS_DB_NAME -e 'SELECT 1;' 2>/dev/null"; then
    echo "✅ PASS: MySQL client connection successful"
  else
    echo "❌ FAIL: MySQL client connection failed"
    echo "🔍 Let's check if we can connect to the database container directly:"
    docker exec peacefestivalusa_mariadb bash -c "mysql -u peacefestivalusa_wp -pc76d1XvmPYHZsLEF peacefestivalusa_wordpress -e 'SELECT 1;' 2>/dev/null" || echo "❌ Direct connection to database failed too"
  fi
  
  if docker exec "$CONTAINER_NAME" bash -c "php -r \"try { \\\$conn = new mysqli('mariadb', getenv('WORDPRESS_DB_USER'), getenv('WORDPRESS_DB_PASSWORD'), getenv('WORDPRESS_DB_NAME')); echo \\\$conn ? 'PHP mysqli connection successful' : 'Failed'; \\\$conn->close(); } catch (Exception \\\$e) { echo 'Error: ' . \\\$e->getMessage(); }\"" | grep -q "successful"; then
    echo "✅ PASS: WordPress can connect to the database"
    return 0
  else
    echo "❌ FAIL: WordPress cannot connect to the database"
    echo "      Debug info:"
    echo "      - Check database credentials in MariaDB container"
    echo "      - Verify database user is created with correct permissions"
    return 1
  fi
}

# Function for system tests
run_system_tests() {
  echo "🌐 Running System Tests..."
  
  # Test 1: WordPress frontend is accessible
  echo "🧪 Test 1: WordPress frontend is accessible"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8082" 2>/dev/null)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ PASS: WordPress frontend is accessible (HTTP 200)"
  else
    echo "❌ FAIL: WordPress frontend is not accessible (HTTP $HTTP_CODE)"
    return 1
  fi
  
  # Test 2: WordPress admin page is accessible (including redirects)
  echo "🧪 Test 2: WordPress admin page is accessible"
  HTTP_CODE=$(curl -s -L -o /dev/null -w "%{http_code}" "http://localhost:8082/wp-admin/" 2>/dev/null)
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    echo "✅ PASS: WordPress admin page is accessible (HTTP $HTTP_CODE)"
  else
    echo "❌ FAIL: WordPress admin page is not accessible (HTTP $HTTP_CODE)"
    echo "      Debug info:"
    echo "      - Check custom-entrypoint.sh for proper configuration"
    echo "      - Verify WORDPRESS_CONFIG_EXTRA in .env file"
    echo "      - Ensure FORCE_SSL_ADMIN and FORCE_SSL_LOGIN are set to false"
    return 1
  fi
  
  # Test 3: WordPress REST API is accessible
  echo "🧪 Test 3: WordPress REST API is accessible"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8082/wp-json/" 2>/dev/null)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ PASS: WordPress REST API is accessible (HTTP 200)"
  else
    echo "❌ FAIL: WordPress REST API is not accessible (HTTP $HTTP_CODE)"
    return 1
  fi
  
  # Test 4: Health check endpoint is accessible
  echo "🧪 Test 4: Health check endpoint is accessible"
  if curl -s "http://localhost:8082/agencystack-health.php" | grep -q '"db_connected":true'; then
    echo "✅ PASS: Health check endpoint confirms database connectivity"
  else
    echo "❌ FAIL: Health check endpoint does not confirm database connectivity"
    echo "      Response:"
    curl -s "http://localhost:8082/agencystack-health.php" || echo "    No response"
    return 1
  fi
}

# Run all tests
echo "🚀 Starting Peace Festival USA WordPress Test Suite..."
echo "--------------------------------------------------"

# Run unit tests
if run_unit_tests; then
  echo "✅ Unit Tests: PASSED"
else
  echo "❌ Unit Tests: FAILED"
  exit 1
fi

echo "--------------------------------------------------"

# Run integration tests
if run_integration_tests; then
  echo "✅ Integration Tests: PASSED"
else
  echo "❌ Integration Tests: FAILED"
  exit 1
fi

echo "--------------------------------------------------"

# Run system tests
if run_system_tests; then
  echo "✅ System Tests: PASSED"
else
  echo "❌ System Tests: FAILED"
  exit 1
fi

echo "--------------------------------------------------"
echo "✅ ALL TESTS PASSED! The Peace Festival USA WordPress installation is working correctly."
echo "--------------------------------------------------"

exit 0
