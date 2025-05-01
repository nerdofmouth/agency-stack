# AgencyStack Utility Scripts - AI Agent Guidelines

## Directory Purpose

This directory contains all shared utility functions and helper scripts that are used by multiple components across the AgencyStack platform. Following the AgencyStack Charter v1.0.3 principles, these utilities ensure consistency, reliability, and code reuse.

## AI Agent Interaction Guidelines

### 🚫 Critical Restrictions

- **NEVER duplicate functionality already available in utility scripts**
- **NEVER create utilities that encourage host-level installations**
- **NEVER bypass containerization principles in utility functions**

### ✅ Required Practices

1. **Function Documentation:** All utility functions must include clear documentation headers.
2. **Error Handling:** Implement proper error handling and validation in all utilities.
3. **Idempotency:** Utilities must be designed to be rerunnable without harmful side effects.
4. **Testing:** Create companion test scripts for all utility functions following the TDD protocol.
5. **Consistent Naming:** Follow established naming conventions for better discoverability.

### 📁 Key Utility Files

```
/scripts/utils/
├── common.sh             # Core utility functions used by all components
├── docker_utils.sh       # Docker-specific helper functions
├── network_utils.sh      # Networking utilities and diagnostics
├── tls_utils.sh          # TLS certificate generation and management
├── agent_lint.sh         # Charter compliance verification for scripts
└── test_common.sh        # Common testing utilities and functions
```

## Using Utility Scripts

When creating new component scripts, always:
1. Source common utilities: `source "$(dirname "$0")/../utils/common.sh"`
2. Use standard logging: `log_info`, `log_warning`, `log_error`, `log_success`
3. Call environment validation: `exit_with_warning_if_host "component_name"`
4. Leverage shared functions: `ensure_directory_exists`, `check_prerequisites`, etc.

## Key References

- [AgencyStack Charter v1.0.3](/docs/charter/v1.0.3.md)
- [Test-Driven Development Protocol](/docs/charter/tdd_protocol.md)
- [Common Utilities Documentation](/docs/pages/components/common_utilities.md)

For all utility scripts, maintain strict containerization principles and never create utilities that encourage direct host system modifications.
