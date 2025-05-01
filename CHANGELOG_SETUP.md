# AgencyStack Setup Changelog

This changelog tracks AI-generated configuration fixes, script refactors, and known edge-case notes to facilitate ongoing improvement and AI-human handoff in the AgencyStack platform.

## Format Guidelines

Each entry should follow this format:
```markdown
### YYYY-MM-DD Component Name

<!-- @agent:category -->
**Change Type**: [Feature|Fix|Refactor|Security]
**Author**: [AI|Human|Collaborative]
**Files Changed**: `/path/to/file1.sh`, `/path/to/file2.sh`

Description of the change, including motivation and context.

**Edge Cases**: Any known limitations or edge cases
**Testing Done**: Description of testing performed
```

## Current Changes

### 2025-04-30 Environment Enforcement System

<!-- @agent:critical-fix -->
**Change Type**: Security/Feature
**Author**: AI
**Files Changed**: 
- `/scripts/utils/common.sh`
- `/scripts/utils/environment_audit.sh`
- `/scripts/utils/agent_lint.sh`
- `/Makefile`
- `/README_AGENT.md`
- Various component README files

Implemented comprehensive environment enforcement system to prevent host contamination and ensure compliance with AgencyStack Charter v1.0.3 principles. Added `exit_with_warning_if_host()` function to common utilities to enforce strict containerization, created linting tools to verify proper script structure, and improved documentation for AI interaction.

**Edge Cases**: 
- VM detection might give false positives in certain container environments
- Legacy scripts may need updates to comply with new enforcement
- Some third-party tools may need special handling

**Testing Done**:
- Verified host detection logic in container environments
- Tested script linting against sample component scripts
- Validated documentation across key directories

### 2025-04-30 Database Connectivity Fix

<!-- @agent:critical-fix -->
**Change Type**: Fix
**Author**: AI
**Files Changed**:
- `/scripts/components/install_peacefestivalusa_wordpress.sh`
- `/scripts/utils/mysql-diagnostics/Dockerfile`
- `/scripts/utils/mysql-diagnostics/build-and-test.sh`

Fixed persistent "Access denied for user 'root'@'localhost'" error when connecting to MariaDB from inside the WordPress container. Created a diagnostic container to troubleshoot database connectivity issues, and updated the installation script to properly handle both local and remote database connections.

**Edge Cases**:
- Special characters in passwords may cause issues with certain MySQL client versions
- Multiple nested containers may have different networking behavior

**Testing Done**:
- Verified connection from WordPress container to MariaDB
- Tested with various password configurations
- Validated database initialization scripts

<!-- @human:manual-confirmation-required -->
**Note**: This implementation should be reviewed for security implications and confirmed working across all client deployments.
