# AgencyStack Test-Driven Development Protocol

## 1. Introduction

This document establishes formal Test-Driven Development (TDD) protocols for all AgencyStack components. These protocols are to be considered mandatory for all new components and modifications to existing components.

## 2. Core TDD Principles

### 2.1 Test-First Development
- Tests MUST be written before implementation code
- No component functionality shall be considered complete without corresponding tests
- Tests should verify both expected functionality and failure cases

### 2.2 Multi-Level Testing Strategy

All components must implement the following testing levels:

1. **Unit Tests**: Test individual functions and classes in isolation
   - Should test single responsibility units
   - Should mock dependencies
   - Should cover both success and failure paths

2. **Integration Tests**: Test interactions between components
   - Should verify correct communication between components
   - Should validate data flow across boundaries
   - Should test real dependencies where feasible

3. **System Tests**: End-to-end verification
   - Should test complete workflows
   - Should use the actual runtime environment
   - Should verify from user/API perspective

### 2.3 Automated Verification

- Tests MUST be automatically executed during installation
- Tests MUST have clear pass/fail criteria
- Failed tests should provide clear error messages
- Failed tests should abort installation in production environments

## 3. Implementation Requirements

### 3.1 Test Script Architecture

Each component must include three standard test scripts:

1. `verify.sh`: Basic health check (fast, essential verification)
2. `test.sh`: Comprehensive unit tests
3. `integration_test.sh`: Cross-component testing

### 3.2 Test Documentation

Each component must document:
- Testing strategy overview
- Test commands and expected outcomes
- Required test dependencies
- How to interpret test failures

### 3.3 Test Coverage Standards

Components shall achieve minimum coverage levels:
- Critical paths: 100% coverage
- Core functionality: 90% coverage 
- Edge cases: 80% coverage

## 4. Testing Infrastructure

### 4.1 Common Testing Utilities

The repository shall provide common test utilities:
- `/scripts/utils/test_common.sh`: Common test functions
- `/scripts/utils/mock_services.sh`: Mock service creation
- `/scripts/utils/test_assertions.sh`: Standard assertions

### 4.2 Continuous Integration

- CI pipelines must run all tests on each commit
- Tests must pass on at least two reference environments
- Test results should be auditable and persistent

## 5. TDD Workflow

1. Write tests that define expected behavior
2. Verify tests fail (as implementation is missing)
3. Implement minimum code to pass tests
4. Refactor and improve implementation while keeping tests passing
5. Review and document test coverage

## 6. Compatibility with Repository Integrity Policy

The TDD Protocol works in concert with the Repository Integrity Policy:
- All test files must be defined within the repository
- Test scripts must follow standard directory conventions
- Tests must validate idempotent behavior
- Tests must verify proper multi-tenancy

## 7. Component Completion Criteria

No component installation shall be considered complete until:
1. All unit tests pass
2. All integration tests pass
3. System verification confirms functionality
4. Test coverage meets minimum standards
5. All tests are executable via standard commands

## 8. Reporting and Metrics

Testing shall generate:
- Pass/fail summary for each test level
- Coverage metrics by component
- Execution time for performance benchmarking

## 9. Authentication Integration Testing Requirements

Based on lessons learned during Traefik-Keycloak SSO integration, the following specific requirements must be implemented for all authentication-related components:

1. **Authentication Flow Verification**
   - Tests must verify the entire authentication flow, not just endpoint availability
   - OAuth2/OIDC redirects must be tested to ensure they use proper externally-accessible URLs
   - Authentication callbacks must be verified with proper status codes

2. **Container Network Validation**
   - Tests must validate all components can communicate properly both via internal networks and external ports
   - Hostname resolution tests must ensure internal container names are not exposed to external clients
   - URL verification must confirm all OAuth-related URLs are properly reachable from both internal and external contexts

3. **Multi-Tier Authentication Testing**
   - Network level: Verify proper HTTP status codes and headers
   - Application level: Validate authentication middleware and access control
   - User experience level: Verify login processes complete successfully with proper redirection

4. **Cross-Component Integration Verification**
   - Tests must verify integration between all components (e.g., Traefik, Keycloak, OAuth2 Proxy)
   - Explicit checks for URL consistency between client configuration and service configuration
   - Verification of proper realm and client configuration in identity providers

These requirements extend the existing TDD protocol for any component with `sso: true` in its component registry entry.

## 10. Repository Integrity Verification Tests

Every component must include mandatory repository integrity verification tests:

1. **Installation Source Verification**
   - Tests must verify scripts are running from the repository path
   - All file paths used for installation must originate from the repository
   - No runtime-generated files may be used that weren't defined in the repository

2. **VM/Container Modification Detection**
   - Tests must validate that files in VMs/containers match repository definitions
   - Any detected direct modification to VM/container must cause test failure
   - Container configurations must match repository-defined configurations

3. **Deployment Path Validation**
   - All file operations must be traced to their repository source
   - Test must verify proper deployment channels were used:
     - Git pulls from authorized repositories
     - Official installation scripts run from repo context
     - Makefile targets executed from repo context

4. **Configuration Source Verification**
   - All runtime configurations must be traceable to repository definitions
   - No ad-hoc or manual configuration permitted
   - Tests must verify configurations originate from repository files

These tests are **mandatory** and must be implemented in *every* component. Failure to include repository integrity tests will automatically prevent component registry flag updates.

---

This protocol is effective as of April 25, 2025 and applies to all subsequent development.
