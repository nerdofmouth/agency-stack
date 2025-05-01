-- AgencyStack WordPress Database Initialization Script
-- This ensures proper user permissions and database setup
-- To be mounted in MariaDB container at /docker-entrypoint-initdb.d/

-- Create WordPress database if it doesn't exist
CREATE DATABASE IF NOT EXISTS `${WP_DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Drop existing user with same name to prevent conflicts
DROP USER IF EXISTS '${WP_DB_USER}'@'%';
DROP USER IF EXISTS '${WP_DB_USER}'@'localhost';
DROP USER IF EXISTS '${WP_DB_USER}'@'172.%.%.%';

-- Create WordPress user with access from any host
CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `${WP_DB_NAME}`.* TO '${WP_DB_USER}'@'%';

-- Ensure privileges are set
FLUSH PRIVILEGES;

-- Log successful setup
SELECT CONCAT('WordPress database setup completed for ', '${WP_DB_NAME}', ' with user ', '${WP_DB_USER}') AS 'Setup Complete';
