-- AgencyStack MariaDB Initialization Script Template
-- Following AgencyStack Charter v1.0.3 principles
-- Ensures proper database, user creation, and permissions

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS `${DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use SET statements for passwords to avoid issues with special characters
SET @db_user = '${DB_USER}';
SET @db_password = '${DB_PASSWORD}';
SET @db_admin_user = '${DB_ADMIN_USER}';
SET @db_admin_password = '${DB_ADMIN_PASSWORD}';

-- Drop existing users to prevent conflicts
DROP USER IF EXISTS @db_user@'%';
DROP USER IF EXISTS @db_user@'localhost';
DROP USER IF EXISTS @db_user@'172.%.%.%';

-- Create user with proper permissions using prepared statements
SET @create_user_stmt = CONCAT('CREATE USER \'', @db_user, '\'@\'%\' IDENTIFIED BY \'', @db_password, '\'');
PREPARE stmt FROM @create_user_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @grant_stmt = CONCAT('GRANT ALL PRIVILEGES ON `${DB_NAME}`.* TO \'', @db_user, '\'@\'%\'');
PREPARE stmt FROM @grant_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Create management user with specific host restrictions
SET @create_admin_stmt = CONCAT('CREATE USER \'', @db_admin_user, '\'@\'%\' IDENTIFIED BY \'', @db_admin_password, '\'');
PREPARE stmt FROM @create_admin_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @grant_admin_stmt = CONCAT('GRANT ALL PRIVILEGES ON `${DB_NAME}`.* TO \'', @db_admin_user, '\'@\'%\'');
PREPARE stmt FROM @grant_admin_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @grant_admin_global_stmt = CONCAT('GRANT RELOAD, PROCESS, REPLICATION CLIENT ON *.* TO \'', @db_admin_user, '\'@\'%\'');
PREPARE stmt FROM @grant_admin_global_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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
VALUES (CONCAT('AgencyStack DB initialization completed successfully at ', NOW()));

-- Log successful initialization
SELECT CONCAT('Database initialization complete for ', '${DB_NAME}', ' with user ', '${DB_USER}') AS 'Setup Status';
