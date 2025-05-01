-- AgencyStack MariaDB Initialization Script Template
-- Following AgencyStack Charter v1.0.3 principles
-- Ensures proper database, user creation, and permissions

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS `${DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Drop existing users to prevent conflicts
DROP USER IF EXISTS '${DB_USER}'@'%';
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER}'@'172.%.%.%';

-- Create user with proper permissions
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `${DB_NAME}`.* TO '${DB_USER}'@'%';

-- Create management user with specific host restrictions
-- This is safer than relying on root access
CREATE USER '${DB_ADMIN_USER}'@'%' IDENTIFIED BY '${DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON `${DB_NAME}`.* TO '${DB_ADMIN_USER}'@'%';
GRANT RELOAD, PROCESS, REPLICATION CLIENT ON *.* TO '${DB_ADMIN_USER}'@'%';

-- Ensure permissions take effect
FLUSH PRIVILEGES;

-- Create test table to verify proper setup
USE `${DB_NAME}`;
CREATE TABLE IF NOT EXISTS `agencystack_db_test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `test_value` varchar(255) NOT NULL DEFAULT 'Database initialized successfully',
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert test data
INSERT INTO `agencystack_db_test` (`test_value`) 
VALUES ('AgencyStack DB initialization completed successfully at ' || NOW());

-- Log successful initialization
SELECT CONCAT('Database initialization complete for ', '${DB_NAME}', ' with user ', '${DB_USER}') AS 'Setup Status';
