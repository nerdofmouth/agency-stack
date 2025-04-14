# AgencyStack Beta Phase Documentation

## Overview

This document outlines the Beta phase for AgencyStack deployment, which follows the successful completion of the Alpha milestone. The Beta phase introduces comprehensive validation, remote VM deployment testing, and preparation for production-grade stability.

## Beta Phase Requirements

For a component or system to be considered Beta-ready, it must meet all Alpha requirements plus the following:

- Validated deployment across multiple VM environments
- Comprehensive monitoring with alert configuration
- Complete documentation for installation and troubleshooting
- All components properly integrated with SSO, TLS, and monitoring
- Successfully passing `beta-check` validation
- Performance tuning for production workloads

## Beta Deployment Process

### 1. Local Preparation

Before deploying to a VM environment:

```bash
# Verify local repository
make beta-check-local

# Create a release tag (optional)
git tag -a beta-v1.0.0 -m "Beta release 1.0.0"
git push origin beta-v1.0.0
```

### 2. Remote VM Validation

Verify that the target VM meets all requirements:

```bash
export REMOTE_VM_SSH=user@vm-hostname
make beta-check-remote
```

### 3. Deployment

Deploy to the target VM with proper validation:

```bash
make beta-deployment REMOTE_VM_SSH=user@vm-hostname DOMAIN=agency.example.com
```

### 4. Status Verification

Monitor the deployment status:

```bash
make beta-status REMOTE_VM_SSH=user@vm-hostname DOMAIN=agency.example.com
```

### 5. Issue Resolution

If issues are detected, run the automated fix procedure:

```bash
make beta-fix REMOTE_VM_SSH=user@vm-hostname
```

## Validation Checks

The `beta-check` command runs the following validations:

1. **TLS/SSO Validation**
   - Verifies proper HTTPS termination
   - Checks certificate validity and expiration
   - Validates SSO integration with Keycloak
   - Confirms registry entries for TLS/SSO components

2. **AI Suite Validation**
   - Verifies all AI components are operational
   - Checks Prometheus metrics integration
   - Tests mock mode functionality
   - Validates model loading and inference

3. **Billing Integration**
   - Confirms KillBill API availability
   - Checks KAUI interface accessibility
   - Validates metrics collection
   - Verifies SSO integration

4. **Inter-Component Connectivity**
   - Tests connectivity between all critical services
   - Validates proper port configurations
   - Confirms network isolation where required

5. **System Resources**
   - Checks CPU, memory, and disk utilization
   - Validates system capacity for production workloads
   - Monitors resource usage during operation

## Known Limitations

1. Beta deployments should have at least 4GB RAM and 2 CPU cores
2. Initial database setup may take up to 30 minutes
3. AI components require additional resources when running real models
4. Mock mode should be used for testing when hardware is limited

## Security Considerations

All Beta deployments must follow these security practices:

1. Use properly secured SSH keys for deployment
2. Keep the repository on a secure local machine
3. Use strong passwords for all services
4. Configure firewall rules to restrict access
5. Enable Fail2Ban or similar intrusion prevention
6. Regularly update all components

## Repository Integrity

Following AgencyStack's strict repository integrity policy:

1. All changes must be made to the local repository first
2. Changes must be committed before deployment
3. Remote VMs must get code exclusively through the deployment process
4. Manual edits on remote VMs are strictly prohibited
5. Monitoring must be enabled to detect unauthorized changes

## Documentation Standards

All Beta components must have:

1. Detailed installation instructions
2. Common troubleshooting scenarios
3. API documentation where applicable
4. Security best practices
5. Performance tuning recommendations

## Next Steps

After successful Beta deployment:

1. Begin user acceptance testing
2. Monitor system stability for at least 7 days
3. Review all logs for errors and warnings
4. Prepare production migration plan
5. Document any remaining issues in the issue tracker
