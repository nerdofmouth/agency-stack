-- AgencyStack Deployment Lessons Database Schema
-- Following AgencyStack Charter v1.0.3 principles
-- Repository as Source of Truth, Auditability & Documentation

-- Drop tables if they exist
DROP TABLE IF EXISTS lessons;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS charter_principles;
DROP TABLE IF EXISTS lesson_principles;
DROP TABLE IF EXISTS projects;

-- Create categories table
CREATE TABLE categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- Create projects table
CREATE TABLE projects (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT
);

-- Create charter principles table
CREATE TABLE charter_principles (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT
);

-- Create lessons table
CREATE TABLE lessons (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  category_id INTEGER NOT NULL,
  lesson TEXT NOT NULL,
  solution TEXT NOT NULL,
  project_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(id),
  FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Create junction table for lessons and principles
CREATE TABLE lesson_principles (
  lesson_id INTEGER NOT NULL,
  principle_id INTEGER NOT NULL,
  PRIMARY KEY (lesson_id, principle_id),
  FOREIGN KEY (lesson_id) REFERENCES lessons(id),
  FOREIGN KEY (principle_id) REFERENCES charter_principles(id)
);

-- Insert categories
INSERT INTO categories (name) VALUES 
  ('Deployment'),
  ('Architecture'),
  ('Configuration'),
  ('Quality'),
  ('Monitoring');

-- Insert projects
INSERT INTO projects (name, description) VALUES 
  ('peacefestivalusa', 'Peace Festival USA client WordPress deployment');

-- Insert charter principles
INSERT INTO charter_principles (name, description) VALUES
  ('Repository as Source of Truth', 'All installation behavior must be defined in the repository'),
  ('Idempotency & Automation', 'All scripts must be rerunnable without harmful side effects'),
  ('Auditability & Documentation', 'Every component must be documented in human-readable markdown'),
  ('Strict Containerization', 'Never install any component directly on the host system'),
  ('Multi-Tenancy & Security', 'Default to tenant isolation and strong authentication'),
  ('Proper Change Workflow', 'All changes must be made in local repo, tested, committed, and deployed via scripts'),
  ('Component Consistency', 'Every component must have tracked install script, Makefile targets, docs, registry entry, and logs'),
  ('TDD Protocol', 'All components must follow the Test-Driven Development protocol');

-- Insert lessons
INSERT INTO lessons (title, category_id, lesson, solution, project_id, date) VALUES
  ('Database Connection Testing is Critical', 
   1, 
   'Always include database connection testing in the deployment process. The WordPress database connection error we encountered could have been detected earlier with properly integrated tests.',
   'Integrate database connectivity checks in the deployment workflow. Add a health check endpoint (agencystack-health.php) that verifies database connections and returns diagnostics in JSON format.',
   1,
   '2025-05-14'),
   
  ('Path Resolution in Docker-in-Docker Environments',
   2,
   'Makefile targets referenced scripts with incorrect paths (/scripts/components/... instead of relative paths), causing failures in Docker-in-Docker environments.',
   'Always use relative paths in Makefiles, referencing variables like $(SCRIPTS_DIR) instead of hardcoded absolute paths. Follow AgencyStack Charter directory structure conventions.',
   1,
   '2025-05-14'),
   
  ('Environment Variable Consistency',
   3,
   'Inconsistent environment variables between WordPress and MariaDB containers led to database connection failures. WordPress expected ''wordpress'' as password but MariaDB was configured with ''change_this_password''.',
   'Create a unified environment configuration file (.env) with consistent variable values. Generate secure passwords dynamically and share them across services.',
   1,
   '2025-05-14'),
   
  ('Unified Testing Framework',
   4,
   'Multiple test scripts existed but weren''t properly integrated into the deployment process. Tests in utils/ and components/ directories with overlapping functionality.',
   'Consolidate testing scripts and integrate them directly into the deployment process. Follow the TDD Protocol defined in AgencyStack Charter.',
   1,
   '2025-05-14'),
   
  ('Health Check Integration',
   5,
   'Missing health check endpoints made it difficult to diagnose issues in deployed services.',
   'Add standardized health check endpoints to all services. Deploy agencystack-health.php with WordPress installations to provide JSON-based diagnostics.',
   1,
   '2025-05-14');

-- Insert lesson principles relationships
-- Lesson 1: Database Connection Testing
INSERT INTO lesson_principles (lesson_id, principle_id) VALUES 
  (1, 4), -- Strict Containerization
  (1, 8), -- TDD Protocol
  (1, 3); -- Auditability & Documentation

-- Lesson 2: Path Resolution
INSERT INTO lesson_principles (lesson_id, principle_id) VALUES 
  (2, 1), -- Repository as Source of Truth
  (2, 6); -- Proper Change Workflow

-- Lesson 3: Environment Variable Consistency
INSERT INTO lesson_principles (lesson_id, principle_id) VALUES 
  (3, 2), -- Idempotency & Automation
  (3, 5); -- Multi-Tenancy & Security

-- Lesson 4: Unified Testing Framework
INSERT INTO lesson_principles (lesson_id, principle_id) VALUES 
  (4, 8), -- TDD Protocol
  (4, 7); -- Component Consistency

-- Lesson 5: Health Check Integration
INSERT INTO lesson_principles (lesson_id, principle_id) VALUES 
  (5, 3), -- Auditability & Documentation
  (5, 6); -- Proper Change Workflow
