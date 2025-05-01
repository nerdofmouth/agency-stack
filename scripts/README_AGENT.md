# AgencyStack Scripts - AI Agent Guidelines

## Directory Purpose

This directory contains all installation, configuration, and utility scripts for the AgencyStack platform. Following the AgencyStack Charter v1.0.3 principles, all operational logic must be defined here and tracked in the repository.

## AI Agent Interaction Guidelines

### 🚫 Critical Restrictions

- **NEVER write scripts that install directly on host systems**
- **ALL scripts must validate their execution environment**
- **ALL scripts must use utility functions from `/scripts/utils/common.sh`**
- **Installation scripts must exit early if running on host systems**

### ✅ Required Practices

1. **Environment Validation:** All component scripts must call `exit_with_warning_if_host()` early to prevent host contamination.
2. **Common Utilities:** Always source common utilities with `source "$(dirname "$0")/../utils/common.sh"` at the beginning of scripts.
3. **Idempotency:** Scripts must be designed to be rerunnable without harmful side effects.
4. **Logging:** Use standard logging functions (`log_info`, `log_warning`, `log_error`, `log_success`) from common.sh.
5. **Error Handling:** Implement proper error trapping and handling with `trap_agencystack_errors`.

### 📁 Directory Structure

```
/scripts/
├── components/     # Component-specific installation scripts
│   └── templates/  # Templates used by installation scripts
├── utils/          # Shared utility functions and helpers
└── archive/        # Archived/deprecated scripts (reference only)
```

## Script Development Workflow

1. Use existing scripts as templates for consistency
2. Include standard headers and environment validation
3. Follow Charter guidelines for containerization
4. Implement proper error handling
5. Test in container/VM environments, never directly on host
6. Ensure scripts follow TDD protocol with proper test coverage

## Key References

- [AgencyStack Charter v1.0.3](/docs/charter/v1.0.3.md)
- [Test-Driven Development Protocol](/docs/charter/tdd_protocol.md)
- [Common Utilities Documentation](/docs/pages/components/common_utilities.md)

For all scripts, assume strict containerization and never perform actions that would modify the host system directly. All installations must happen inside containers or VMs, and all behavior must be repository-tracked.
