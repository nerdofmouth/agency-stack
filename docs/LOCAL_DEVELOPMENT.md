# AgencyStack Local Development & Remote Testing Workflow

## Development Environment Architecture

AgencyStack operates with a two-environment model:

1. **LOCAL Machine** (Development Environment)
   - Where we write, edit, and build installation scripts
   - Performs static analysis and linting
   - Generates documentation
   - Has limited ability to test actual deployment

2. **REMOTE VM** (Testing Environment)
   - Clean Ubuntu server for validation
   - Where we actually deploy the full AgencyStack installation
   - Tests the one-line installer
   - Validates all component installation scripts in real conditions
   - Confirms idempotence, logging, and error handling

## Local Development Guidelines

When developing on your LOCAL machine:

- **Repository Structure**: All code changes should be made in the local repository
- **Script Testing**: Use `shellcheck` and local linting tools before deployment
- **Documentation**: Generate and test all documentation locally
- **Validation Tools**: Run `alpha-check` and `validate_components.sh` locally to verify structure

## Remote VM Testing Guidelines

When testing on the REMOTE VM:

- **Fresh Installation**: Always start with a clean VM image for proper testing
- **One-Line Installer**: Test using `curl -L https://stack.nerdofmouth.com/install.sh | bash`
- **Idempotence Testing**: Run installation multiple times to verify idempotence
- **Permission Testing**: Test with various user accounts to verify proper permission handling
- **Network Isolation**: Test both with and without internet access to verify offline capabilities

## Local-to-Remote Workflow

1. **Local Development**:
   ```bash
   # Edit/create installation scripts
   vim scripts/components/install_<component>.sh
   
   # Run syntax validation
   shellcheck scripts/components/install_<component>.sh
   
   # Update component in registry
   scripts/utils/update_component_registry.sh --component=<component> --flag=installed --value=true
   
   # Run local validation
   make alpha-check
   ```

2. **Remote Testing**:
   ```bash
   # Method 1: Using Git
   # SSH into VM
   ssh user@vm-hostname
   
   # Clone repository
   git clone https://github.com/nerdofmouth/agency-stack.git
   cd agency-stack
   make install-<component>
   
   # Method 2: Using One-Line Installer
   # Run one-liner
   curl -L https://stack.nerdofmouth.com/install.sh | bash
   
   # Check installation result
   cd /opt/agency_stack
   make alpha-check
   ```

3. **Validation**:
   ```bash
   # Run component status check
   make <component>-status
   
   # Check component logs 
   make <component>-logs
   
   # Verify idempotence
   make <component>
   ```

## Common Pitfalls

1. **Path Differences**: Scripts that use relative paths may work locally but fail on VM
2. **Permission Issues**: Scripts run as different users locally vs. on VM
3. **Network Dependencies**: Internet availability may differ between environments
4. **System Package Differences**: VM may have different default packages installed
5. **File Ownership**: Files created during installation have different owners

## Best Practices

1. **Use Absolute Paths**: Always use absolute paths in installation scripts
2. **Check for Dependencies**: Always verify dependencies before attempting installation
3. **Proper Error Handling**: All scripts should fail loudly with descriptive error messages
4. **Idempotent Design**: Scripts should safely run multiple times
5. **Cleanup on Failure**: Scripts should clean up partial installations on failure
6. **Isolated Testing**: Test each component in isolation before testing integrations

---

**IMPORTANT**: The one-line installer must be tested on a completely fresh VM to ensure it works properly. Local testing can validate structure but cannot confirm proper installation.
