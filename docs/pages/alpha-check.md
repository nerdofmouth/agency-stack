---
layout: default
title: Alpha Check - AgencyStack Documentation
---

# Alpha-Check: Deployment Validation Tool

The `alpha-check` tool provides comprehensive validation of your AgencyStack installation to ensure it meets all DevOps standards before deployment. This is a critical step in the Alpha Test + Deploy phase, helping you identify and resolve issues before going live.

## Overview

The validation process performs multiple checks across all components:

- Verifies all components against AgencyStack DevOps standards
- Inspects installed components status
- Confirms required directory structures exist
- Validates installation logs and marker files
- Checks for port conflicts between services

## Usage

```bash
make alpha-check
```

If the validation passes, you'll see:

```
 Alpha validation complete - system ready for deployment!
```

If any checks fail, you'll receive specific error messages indicating what needs to be fixed.

## Fixing Common Issues

The system includes an automated fix utility that can resolve common problems:

```bash
make alpha-fix
```

This will attempt to:
- Add missing Makefile targets
- Create template documentation for missing component docs
- Fix registry entries with missing flags
- Generate template scripts for missing components

After running `alpha-fix`, you should run `alpha-check` again to verify the fixes.

## Manual Troubleshooting

If automatic fixes don't resolve all issues, refer to these common troubleshooting steps:

### Missing Components

If components are missing or incomplete:

```bash
make <component>             # Install or reinstall a component
make <component>-status      # Check component status
make <component>-logs        # View component logs
```

### Port Conflicts

If port conflicts are detected:

```bash
make detect-ports            # Get detailed port conflict information
make remap-ports             # Automatically resolve port conflicts
```

### Directory Structure Issues

If directory structure validation fails:

```bash
make prep-dirs               # Create required directories
```

### Validation Report

For detailed information about component validation results:

```bash
cat component_validation_report.md
```

## Integration with CI/CD

The `alpha-check` tool is designed to be integrated into CI/CD pipelines, enabling automated validation during deployment:

```bash
# Example CI/CD script
git clone https://github.com/nerdofmouth/agency-stack.git
cd agency-stack
make alpha-check || exit 1
# Continue with deployment if validation passes
```

## Component Registry Tracking

The alpha-check process verifies all components against the component registry, ensuring each component:

- Has a proper entry in the registry with all required flags
- Includes standardized Makefile targets (install, status, logs, restart)
- Has comprehensive documentation
- Follows script implementation standards including idempotence

## Local Development vs. Remote VM Testing

The AgencyStack validation process follows a dual-environment workflow:

### Local Development Environment
- **Purpose**: Script development, structure validation, documentation
- **Command**: `make alpha-check`
- **Validates**: All components comply with structure standards, naming conventions, and documentation

### Remote VM Testing Environment 
- **Purpose**: Actual installation validation, performance testing, security testing
- **Setup**: Requires setting `REMOTE_VM_SSH` environment variable
- **Command**: `make vm-alpha-check`
- **Validates**: Components install correctly, services start, ports bind correctly

### Workflow

1. **Develop Locally**:
   ```bash
   # Edit installation scripts
   vim scripts/components/install_<component>.sh
   
   # Run local validation
   make alpha-check
   ```

2. **Test on Remote VM**:
   ```bash
   # Set remote VM connection
   export REMOTE_VM_SSH=user@vm-hostname
   
   # Deploy current codebase to VM
   make deploy-to-vm
   
   # Run alpha-check on VM
   make vm-alpha-check
   
   # Alternatively, test the one-line installer
   make vm-test-installer
   ```

3. **Component-Specific Remote Testing**:
   ```bash
   # Test a specific component on remote VM
   make <component>-test-remote
   ```

### Important Notes

- The full installation must be validated on a **clean VM** to ensure idempotence
- Local validation focuses on **structure** while remote validation tests **functionality**
- Any permissions issues seen locally may not accurately reflect VM deployment
- Documentation in `docs/LOCAL_DEVELOPMENT.md` contains the complete workflow reference

## Next Steps

After successfully passing `alpha-check`:

1. Deploy to production using `make deploy`
2. Setup monitoring with `make monitoring-setup`
3. Enable automated backups with `make setup-backup`
4. Setup log rotation with `make setup-log-rotation`
