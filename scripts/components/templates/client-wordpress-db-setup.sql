-- AgencyStack Client WordPress Database Setup Script
-- Following repository integrity policy and containerization principles

-- Create WordPress database if not exists
CREATE DATABASE IF NOT EXISTS `DBNAME` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Drop existing users to prevent conflicts
DROP USER IF EXISTS 'DBUSER'@'%';
DROP USER IF EXISTS 'DBUSER'@'localhost';
DROP USER IF EXISTS 'DBUSER'@'172.%.%.%';

-- Create WordPress user with full permissions (accessible from any host)
CREATE USER 'DBUSER'@'%' IDENTIFIED BY 'DBPASS';
GRANT ALL PRIVILEGES ON `DBNAME`.* TO 'DBUSER'@'%';

-- Ensure privileges are applied
FLUSH PRIVILEGES;

-- Create a simple test table to verify permissions
USE `DBNAME`;
CREATE TABLE IF NOT EXISTS `agencystack_test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `test_value` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert test data
INSERT INTO `agencystack_test` (`test_value`) VALUES ('Database initialization successful');

-- Log successful initialization
SELECT CONCAT('WordPress database initialization complete for ', 'DBNAME') AS 'Success';
