#!/bin/bash
# test_peacefestivalusa_wordpress_direct.sh - Docker-in-Docker direct IP testing
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
# Following the Repository Integrity Policy and Host-to-Container Rule

set -e

# Client-specific variables
CLIENT_ID="peacefestivalusa"
WORDPRESS_CONTAINER="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER="${CLIENT_ID}_mariadb"

echo "=== Peace Festival USA WordPress Direct IP Test Suite ==="
echo "Testing container connection directly via IP addressing"

# Get container IP addresses 
WP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${WORDPRESS_CONTAINER})
DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MARIADB_CONTAINER})

echo "WordPress container IP: ${WP_IP}"
echo "MariaDB container IP: ${DB_IP}"

# Test 1: Verify WordPress is responding on port 80
echo "Test 1: WordPress HTTP response"
if curl -s -o /dev/null -w "%{http_code}" ${WP_IP}:80 | grep -q "200\|302\|301"; then
  echo "✅ PASS: WordPress is responding with successful HTTP status"
else
  echo "❌ FAIL: WordPress is not responding correctly"
  exit 1
fi

# Test 2: Verify database connectivity
echo "Test 2: Database connectivity"
# Get database credentials from the stored secrets
if [ -f "${HOME}/.agencystack/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt" ]; then
  DB_NAME=$(grep "Database Name:" "${HOME}/.agencystack/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt" | awk '{print $3}')
  DB_USER=$(grep "Database User:" "${HOME}/.agencystack/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt" | awk '{print $3}')
  DB_PASS=$(grep "Database Password:" "${HOME}/.agencystack/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt" | awk '{print $3}')
  
  # Test database connection using docker exec
  if docker exec ${MARIADB_CONTAINER} mysql -u"${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME}; SELECT 'Database connection successful' AS message;"; then
    echo "✅ PASS: Database connection successful"
  else
    echo "❌ FAIL: Could not connect to database"
    exit 1
  fi
else
  echo "⚠️ WARNING: Credentials file not found, skipping database connectivity test"
fi

# Test 3: Check WordPress configuration 
echo "Test 3: WordPress configuration"
if docker exec ${WORDPRESS_CONTAINER} test -f /var/www/html/wp-config.php; then
  echo "✅ PASS: WordPress configuration file exists"
else
  echo "❌ FAIL: WordPress configuration file not found"
  exit 1
fi

# Test 4: Verify WordPress content directory
echo "Test 4: WordPress content directory"
if docker exec ${WORDPRESS_CONTAINER} test -d /var/www/html/wp-content; then
  echo "✅ PASS: WordPress content directory exists"
else
  echo "❌ FAIL: WordPress content directory not found"
  exit 1
fi

# All tests passed
echo "=== All tests PASSED: WordPress is properly configured and running ==="
echo "To access WordPress:"
echo "1. From within container: http://${WP_IP}:80"
echo "2. Your WordPress is also available at the mapped port (typically 8082)"
echo "3. For dev access: open browser preview on http://localhost:8082"
