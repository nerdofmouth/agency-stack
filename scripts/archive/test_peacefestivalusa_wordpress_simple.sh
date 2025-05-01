#!/bin/bash
# test_peacefestivalusa_wordpress_simple.sh - Simple localhost testing for Peace Festival USA WordPress
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
# Following the Repository Integrity Policy and Host-to-Container Rule

# Set error handling
set -e

# Client-specific variables
CLIENT_ID="peacefestivalusa"
CONTAINER_NAME="${CLIENT_ID}_wordpress"
DB_CONTAINER="${CLIENT_ID}_mariadb"
WP_PORT=8082
DB_PORT=33060

echo "=== Peace Festival USA WordPress Simple Localhost Test Suite ==="
echo "WordPress Port: $WP_PORT"
echo "MariaDB Port: $DB_PORT"

# Function to test Docker container status
test_container_status() {
  local container_name=$1
  echo "Testing container: $container_name"
  
  if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
    echo "✅ PASS: Container $container_name is running"
    return 0
  else
    echo "❌ FAIL: Container $container_name is not running"
    return 1
  fi
}

# Function to test port availability
test_port_availability() {
  local port=$1
  local service_name=$2
  echo "Testing port availability: $port for $service_name"
  
  if docker ps | grep -q "0.0.0.0:$port"; then
    echo "✅ PASS: Port $port is mapped for $service_name"
    return 0
  else
    echo "❌ FAIL: Port $port is not mapped for $service_name"
    return 1
  fi
}

# Function to test HTTP response (with retry logic)
test_http_response() {
  local url=$1
  local max_retries=$2
  local retry_count=0
  local http_status
  
  echo "Testing HTTP response from: $url (max $max_retries attempts)"
  
  while [ $retry_count -lt $max_retries ]; do
    retry_count=$((retry_count + 1))
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    echo "  Attempt $retry_count/$max_retries - Status: $http_status"
    
    if [[ "$http_status" == "200" || "$http_status" == "302" || "$http_status" == "301" ]]; then
      echo "✅ PASS: URL $url returned successful status: $http_status"
      return 0
    fi
    
    sleep 2
  done
  
  echo "❌ FAIL: URL $url did not return successful status after $max_retries attempts"
  return 1
}

# Function to test database connection
test_db_connection() {
  echo "Testing database connection from WordPress container"
  
  if docker exec $CONTAINER_NAME bash -c "mysql -h database -u$WP_DB_USER -p$WP_DB_PASSWORD -D$WP_DB_NAME -e 'SELECT 1'" &>/dev/null; then
    echo "✅ PASS: WordPress container can connect to the database"
    return 0
  else
    echo "❌ FAIL: WordPress container cannot connect to the database"
    return 1
  fi
}

# Main test script
echo "=== Running Peace Festival USA WordPress Simple Tests ==="

# Test container status
echo "1. Container Status Tests:"
test_container_status "$CONTAINER_NAME" || exit 1
test_container_status "$DB_CONTAINER" || exit 1
echo ""

# Test port availability
echo "2. Port Availability Tests:"
test_port_availability "$WP_PORT" "WordPress" || exit 1
test_port_availability "$DB_PORT" "MariaDB" || exit 1
echo ""

# Test HTTP response
echo "3. HTTP Response Test:"
test_http_response "http://localhost:$WP_PORT" 10 || {
  echo "  Checking WordPress container logs:"
  docker logs $CONTAINER_NAME | tail -20
  exit 1
}
echo ""

# Test container health
echo "4. Container Health Tests:"
if docker inspect "$DB_CONTAINER" --format='{{.State.Health.Status}}' | grep -q "healthy"; then
  echo "✅ PASS: Database container is healthy"
else
  echo "❌ FAIL: Database container is not healthy"
  exit 1
fi
echo ""

echo "=== All tests passed! Peace Festival USA WordPress is functioning correctly ==="
echo "WordPress is accessible at: http://localhost:$WP_PORT"
