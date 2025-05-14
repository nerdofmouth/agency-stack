<?php
/**
 * AgencyStack WordPress Health Check
 * 
 * This file provides a basic health check endpoint for WordPress
 * installations in the AgencyStack platform, following Charter v1.0.3
 * principles of Auditability & Documentation and TDD Protocol.
 * 
 * Usage: Place this file in the root of your WordPress installation
 * and access it via /agencystack-health.php
 */

// Set content type to JSON
header('Content-Type: application/json');

// Disable error display but enable logging
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Basic server information
$server_info = [
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
    'php_version' => phpversion(),
    'server_time' => date('Y-m-d H:i:s'),
    'request_time' => date('Y-m-d H:i:s', $_SERVER['REQUEST_TIME'] ?? time()),
];

// WordPress checks
$wp_loaded = false;
$wp_config_exists = false;
$wp_version = 'unknown';

// Check if wp-config.php exists
if (file_exists(dirname(__FILE__) . '/wp-config.php')) {
    $wp_config_exists = true;
    
    // Try to load WordPress without triggering the full application
    try {
        // Get database credentials from wp-config.php
        $wp_config_content = file_get_contents(dirname(__FILE__) . '/wp-config.php');
        
        preg_match("/define\(\s*'DB_NAME',\s*'(.+?)'\s*\)/", $wp_config_content, $db_name_matches);
        preg_match("/define\(\s*'DB_USER',\s*'(.+?)'\s*\)/", $wp_config_content, $db_user_matches);
        preg_match("/define\(\s*'DB_PASSWORD',\s*'(.+?)'\s*\)/", $wp_config_content, $db_pass_matches);
        preg_match("/define\(\s*'DB_HOST',\s*'(.+?)'\s*\)/", $wp_config_content, $db_host_matches);
        
        $db_name = $db_name_matches[1] ?? getenv('WORDPRESS_DB_NAME');
        $db_user = $db_user_matches[1] ?? getenv('WORDPRESS_DB_USER');
        $db_pass = $db_pass_matches[1] ?? getenv('WORDPRESS_DB_PASSWORD');
        $db_host = $db_host_matches[1] ?? getenv('WORDPRESS_DB_HOST');
        
        if (empty($db_host) && !empty(getenv('WORDPRESS_DB_HOST'))) {
            $db_host = getenv('WORDPRESS_DB_HOST');
        }
        
        if (empty($db_name) && !empty(getenv('WORDPRESS_DB_NAME'))) {
            $db_name = getenv('WORDPRESS_DB_NAME');
        }
        
        if (empty($db_user) && !empty(getenv('WORDPRESS_DB_USER'))) {
            $db_user = getenv('WORDPRESS_DB_USER');
        }
        
        if (empty($db_pass) && !empty(getenv('WORDPRESS_DB_PASSWORD'))) {
            $db_pass = getenv('WORDPRESS_DB_PASSWORD');
        }
        
        // Check for wp-version
        if (file_exists(dirname(__FILE__) . '/wp-includes/version.php')) {
            include_once(dirname(__FILE__) . '/wp-includes/version.php');
            if (isset($wp_version)) {
                $wp_version = $wp_version;
                $wp_loaded = true;
            }
        }
    } catch (Exception $e) {
        $error = $e->getMessage();
    }
}

// Database connection check
$db_connected = false;
$db_info = [];
$db_error = '';

if (!empty($db_host) && !empty($db_user) && !empty($db_name)) {
    try {
        $mysqli = new mysqli($db_host, $db_user, $db_pass, $db_name);
        
        if ($mysqli->connect_errno) {
            $db_error = "Failed to connect to MySQL: " . $mysqli->connect_error;
        } else {
            $db_connected = true;
            $db_info = [
                'server_info' => $mysqli->server_info,
                'protocol_version' => $mysqli->protocol_version,
                'db_name' => $db_name,
                'db_host' => $db_host,
                'db_user' => $db_user
            ];
            
            // Check for WordPress tables
            $result = $mysqli->query("SHOW TABLES LIKE 'wp_%'");
            $db_info['wp_tables_count'] = $result ? $result->num_rows : 0;
            
            $mysqli->close();
        }
    } catch (Exception $e) {
        $db_error = $e->getMessage();
    }
}

// Filesystem checks
$filesystem_writable = is_writable(dirname(__FILE__));
$uploads_writable = false;
$uploads_dir = dirname(__FILE__) . '/wp-content/uploads';

if (file_exists($uploads_dir)) {
    $uploads_writable = is_writable($uploads_dir);
}

// Assemble the response
$response = [
    'status' => ($db_connected && $wp_config_exists) ? 'healthy' : 'unhealthy',
    'timestamp' => time(),
    'server' => $server_info,
    'wordpress' => [
        'loaded' => $wp_loaded,
        'config_exists' => $wp_config_exists,
        'version' => $wp_version,
    ],
    'database' => [
        'connected' => $db_connected,
        'info' => $db_info,
        'error' => $db_error
    ],
    'filesystem' => [
        'writable' => $filesystem_writable,
        'uploads_writable' => $uploads_writable
    ],
    'client_id' => getenv('CLIENT_ID') ?: 'unknown',
    'environment' => getenv('WORDPRESS_DEBUG') ? 'development' : 'production'
];

// Return the JSON response
echo json_encode($response, JSON_PRETTY_PRINT);
