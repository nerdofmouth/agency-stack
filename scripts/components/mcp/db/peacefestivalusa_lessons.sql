-- PeaceFestivalUSA Integration Lessons Schema
-- Following AgencyStack Charter v1.0.3 Principles

CREATE TABLE IF NOT EXISTS deployment_lessons (
  id INTEGER PRIMARY KEY,
  component TEXT NOT NULL,
  issue_context TEXT NOT NULL,
  lesson TEXT NOT NULL,
  solution TEXT NOT NULL,
  added_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- WSL/Windows Integration Lessons
INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES 
('traefik', 'wsl_windows_access', 
 'Traefik running in WSL is not accessible from Windows host browser by default',
 'Configure Traefik to bind to all interfaces (0.0.0.0) and ensure port 80/443 are exposed to the host');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('networking', 'wsl_windows_hostnames',
 'Hostname resolution does not work across WSL/Windows boundary without configuration',
 'Add entries to both WSL /etc/hosts AND Windows hosts file for local domain names');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('docker', 'volume_mounts',
 'Docker volume mounts behave differently in WSL2 versus Windows Docker Desktop',
 'Use correct path translation with wslpath -w for Windows Docker mounts; prefer named volumes');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('installation', 'repository_integrity',
 'Installation scripts must follow Repository Integrity Policy with proper organization',
 'Create modular, reusable installation components in /scripts/components/{component}/install/');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('testing', 'cross_environment',
 'Services must be tested from both WSL and Windows host perspectives',
 'Implement test suite that verifies access via localhost, WSL IP, and Windows host browser');

-- WordPress Integration Lessons
INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('wordpress', 'traefik_integration',
 'WordPress container must be properly labeled for Traefik discovery',
 'Use traefik.enable=true and proper Host rules in container labels');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('database', 'connectivity',
 'Database connectivity issues may occur due to network isolation',
 'Ensure database and application containers share a common network');

-- Script Organization Lessons
INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('scripts', 'consolidation',
 'Multiple overlapping scripts lead to maintenance challenges and divergent implementations',
 'Consolidate into modular, reusable components with clear responsibilities');

INSERT INTO deployment_lessons (component, issue_context, lesson, solution) VALUES
('deployment', 'idempotency',
 'Scripts must be rerunnable without harmful side effects',
 'Add proper checks before operations and handle existing resources gracefully');
