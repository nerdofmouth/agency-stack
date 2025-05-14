#!/bin/bash

# PeaceFestivalUSA WordPress Installation Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Strict Containerization

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$WORDPRESS_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Setting up WordPress for ${CLIENT_ID}"

# Create WordPress directory structure
mkdir -p "${WORDPRESS_DIR}"
mkdir -p "${WORDPRESS_DIR}/wp-content"
mkdir -p "${WORDPRESS_DIR}/db_data"
mkdir -p "${WORDPRESS_DIR}/backup"

# Generate secure random passwords
generate_random_password() {
  local length=${1:-16}
  tr -dc A-Za-z0-9 </dev/urandom | head -c ${length}
}

# Set database credentials
DB_ROOT_PASSWORD=$(generate_random_password 32)
WP_DB_NAME="${CLIENT_ID}_wordpress"
WP_DB_USER="${CLIENT_ID}_wp"
WP_DB_PASSWORD=$(generate_random_password 16)
WP_ADMIN_PASSWORD=$(generate_random_password 12)

# Create .env file for WordPress
cat > "${WORDPRESS_DIR}/.env" << EOL
# WordPress Environment Variables
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_ADMIN_USER=admin
WORDPRESS_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
DOMAIN=${CLIENT_ID}.${DOMAIN}
EOL

# Save credentials to a secure location (following AgencyStack practices)
mkdir -p "${INSTALL_DIR}/.secrets"
chmod 700 "${INSTALL_DIR}/.secrets"
cat > "${INSTALL_DIR}/.secrets/wordpress_credentials.txt" << EOL
# WordPress Credentials - KEEP SECURE
# Generated on $(date)
WordPress Admin URL: http://${CLIENT_ID}.${DOMAIN}/wp-admin/
WordPress Admin Username: admin
WordPress Admin Password: ${WP_ADMIN_PASSWORD}
Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
Database Root Password: ${DB_ROOT_PASSWORD}
EOL
chmod 600 "${INSTALL_DIR}/.secrets/wordpress_credentials.txt"

# Create custom entrypoint script for WordPress
cat > "${WORDPRESS_DIR}/custom-entrypoint.sh" << 'EOL'
#!/bin/bash
set -e

# Wait for database to be ready
wait_for_db() {
  echo "Waiting for database connection..."
  for i in {1..30}; do
    if mysql -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
      echo "Database connection established"
      return 0
    fi
    echo "Waiting for database... $i/30"
    sleep 2
  done
  echo "Could not connect to database after 60 seconds"
  return 1
}

# First run configuration
first_run_setup() {
  if [ ! -f /var/www/html/wp-config.php ]; then
    echo "First run - installing WordPress..."
  else
    echo "WordPress already installed, skipping setup"
    return 0
  fi
  
  # Original docker-entrypoint.sh logic first
  docker-entrypoint.sh apache2 &
  
  # Wait for WordPress setup to complete
  for i in {1..30}; do
    if [ -f /var/www/html/wp-config.php ]; then
      break
    fi
    echo "Waiting for wp-config.php... $i/30"
    sleep 2
  done
  
  # Configure WordPress via WP-CLI
  if wp core is-installed --allow-root; then
    echo "WordPress is already installed"
  else
    echo "Setting up WordPress with WP-CLI..."
    wp core install --url="http://$DOMAIN" --title="Peace Festival USA" \
      --admin_user="$WORDPRESS_ADMIN_USER" --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
      --admin_email="admin@example.com" --allow-root
    
    # Install necessary plugins
    wp plugin install wordpress-seo --activate --allow-root
    wp theme install twentytwentythree --activate --allow-root
    
    # Configure settings
    wp option update blogdescription "Celebrating Peace and Unity" --allow-root
    wp rewrite structure '/%postname%/' --allow-root
    wp option update timezone_string "America/Chicago" --allow-root
  fi
  
  # Create health check file
  cat > /var/www/html/wp-content/agencystack-health.php << 'EOPHP'
<?php
/**
 * PeaceFestivalUSA WordPress Health Check
 * Following AgencyStack Charter v1.0.3 Principles
 */

header('Content-Type: application/json');

$results = array(
    'status' => 'error',
    'message' => 'Unchecked status',
    'details' => array()
);

// Check if WordPress is properly loaded
if (file_exists(dirname(dirname(__FILE__)) . '/wp-config.php')) {
    include_once(dirname(dirname(__FILE__)) . '/wp-config.php');
    $results['details']['wp_config'] = 'found';
    
    // Try database connection
    try {
        $db = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
        if ($db->connect_errno) {
            $results['details']['database'] = "Connection failed: " . $db->connect_error;
        } else {
            $results['details']['database'] = "Connected successfully";
            
            // Check WordPress tables
            $tables_query = $db->query("SHOW TABLES LIKE 'wp\\_%'");
            $results['details']['tables_count'] = $tables_query->num_rows;
            
            if ($tables_query->num_rows > 0) {
                $results['status'] = 'ok';
                $results['message'] = 'WordPress is properly installed and database is accessible';
            } else {
                $results['message'] = 'Database connection successful but WordPress tables not found';
            }
            $db->close();
        }
    } catch (Exception $e) {
        $results['details']['database_exception'] = $e->getMessage();
        $results['message'] = 'Database connection failed';
    }
} else {
    $results['details']['wp_config'] = 'not found';
    $results['message'] = 'WordPress config file not found';
}

echo json_encode($results, JSON_PRETTY_PRINT);
EOPHP

  # Create verification script
  cat > /var/www/html/wp-content/verify-deployment.php << 'EOPHP'
<?php
/**
 * PeaceFestivalUSA WordPress Deployment Verification
 * Following AgencyStack Charter v1.0.3 Principles
 */

header('Content-Type: application/json');

$tests = array();
$passed = 0;
$failed = 0;
$overall_status = 'unknown';

// Unit Tests
// Test 1: WordPress Files
$tests['wp_core_files'] = array('status' => 'failed');
if (file_exists(ABSPATH . 'wp-config.php') && file_exists(ABSPATH . 'wp-load.php')) {
    $tests['wp_core_files']['status'] = 'passed';
    $tests['wp_core_files']['message'] = 'WordPress core files exist';
    $passed++;
} else {
    $tests['wp_core_files']['message'] = 'Missing WordPress core files';
    $failed++;
}

// Test 2: Database Configuration
$tests['db_config'] = array('status' => 'failed');
if (defined('DB_NAME') && defined('DB_USER') && defined('DB_PASSWORD') && defined('DB_HOST')) {
    $tests['db_config']['status'] = 'passed';
    $tests['db_config']['message'] = 'Database configuration found';
    $passed++;
} else {
    $tests['db_config']['message'] = 'Missing database configuration constants';
    $failed++;
}

// Integration Tests
// Test 3: Database Connection
$tests['db_connection'] = array('status' => 'failed');
try {
    if (defined('DB_HOST') && defined('DB_USER') && defined('DB_PASSWORD') && defined('DB_NAME')) {
        $db = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
        if ($db->connect_errno) {
            $tests['db_connection']['message'] = "Connection failed: " . $db->connect_error;
            $failed++;
        } else {
            $tests['db_connection']['status'] = 'passed';
            $tests['db_connection']['message'] = "Connected successfully to database";
            $passed++;
            $db->close();
        }
    } else {
        $tests['db_connection']['message'] = "Database constants not defined";
        $failed++;
    }
} catch (Exception $e) {
    $tests['db_connection']['message'] = "Exception: " . $e->getMessage();
    $failed++;
}

// Test 4: WordPress Tables
$tests['wp_tables'] = array('status' => 'failed');
try {
    if (defined('DB_HOST') && defined('DB_USER') && defined('DB_PASSWORD') && defined('DB_NAME')) {
        $db = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
        if (!$db->connect_errno) {
            $tables_query = $db->query("SHOW TABLES LIKE 'wp\\_%'");
            $table_count = $tables_query->num_rows;
            if ($table_count > 0) {
                $tests['wp_tables']['status'] = 'passed';
                $tests['wp_tables']['message'] = "Found $table_count WordPress tables";
                $passed++;
            } else {
                $tests['wp_tables']['message'] = "No WordPress tables found";
                $failed++;
            }
            $db->close();
        }
    }
} catch (Exception $e) {
    $tests['wp_tables']['message'] = "Exception: " . $e->getMessage();
    $failed++;
}

// Test 5: Environment Variables
$tests['env_variables'] = array('status' => 'failed');
$required_env = array('WORDPRESS_DB_HOST', 'WORDPRESS_DB_NAME', 'WORDPRESS_DB_USER', 'WORDPRESS_DB_PASSWORD');
$missing_env = array();
foreach ($required_env as $env) {
    if (!getenv($env)) {
        $missing_env[] = $env;
    }
}
if (empty($missing_env)) {
    $tests['env_variables']['status'] = 'passed';
    $tests['env_variables']['message'] = "All required environment variables found";
    $passed++;
} else {
    $tests['env_variables']['message'] = "Missing environment variables: " . implode(', ', $missing_env);
    $failed++;
}

// Overall status
if ($failed == 0 && $passed > 0) {
    $overall_status = 'success';
} elseif ($passed > 0) {
    $overall_status = 'partial';
} else {
    $overall_status = 'failure';
}

// Output results
$result = array(
    'status' => $overall_status,
    'summary' => array(
        'passed' => $passed,
        'failed' => $failed,
        'total' => $passed + $failed
    ),
    'tests' => $tests,
    'timestamp' => date('Y-m-d H:i:s')
);

echo json_encode($result, JSON_PRETTY_PRINT);
EOPHP
}

# Main entry point logic
wait_for_db
first_run_setup

# Execute the original entrypoint
exec docker-entrypoint.sh "$@"
EOL

chmod +x "${WORDPRESS_DIR}/custom-entrypoint.sh"

# Create WordPress docker-compose.yml with Traefik integration
cat > "${WORDPRESS_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  wordpress:
    container_name: ${CLIENT_ID}_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
    env_file:
      - .env
    volumes:
      - ${WORDPRESS_DIR}/wp-content:/var/www/html/wp-content
      - ${WORDPRESS_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
    command: ["custom-entrypoint.sh", "apache2-foreground"]
    networks:
      - traefik_network
      - wordpress_network
    depends_on:
      - mariadb
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(\`${CLIENT_ID}.${DOMAIN}\`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
      - "traefik.docker.network=${CLIENT_ID}_traefik_network"
  
  mariadb:
    container_name: ${CLIENT_ID}_mariadb
    image: mariadb:10.5
    restart: always
    env_file:
      - .env
    environment:
      - MYSQL_DATABASE=\${WORDPRESS_DB_NAME}
      - MYSQL_USER=\${WORDPRESS_DB_USER}
      - MYSQL_PASSWORD=\${WORDPRESS_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
    volumes:
      - ${WORDPRESS_DIR}/db_data:/var/lib/mysql
    networks:
      - wordpress_network

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
  wordpress_network:
    name: ${CLIENT_ID}_wordpress_network
EOL

log_info "WordPress configuration complete"
