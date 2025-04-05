# AgencyStack Installation Hardening

This document outlines the hardening measures implemented in the AgencyStack installation scripts to ensure robust, secure, and consistent component deployment.

## System Validation

The `validate_system.sh` utility ensures your server meets the requirements for running AgencyStack components.

### Validation Process

Before installing any components, the system validator performs the following checks:

1. **Docker Environment**
   - Docker installation and running status
   - Docker Compose availability
   - User permissions for Docker commands
   - Critical container existence

2. **System Resources**
   - Available disk space (minimum 10GB)
   - Available memory (minimum 4GB)
   - Port availability for services

3. **Infrastructure**
   - Required directories existence and permissions
   - Docker networks configuration
   - Running containers inventory

4. **Component Registry**
   - Installed components tracking
   - Active vs. inactive components

### Running Validation

```bash
# Basic validation
make validate

# Generate a detailed report
make validate-report
```

The validation report is saved to `/tmp/agency_stack_validation_report.txt` and provides comprehensive information about the server's readiness to run AgencyStack components.

## Installation Script Enhancements

Each component installation script has been enhanced with the following features:

### Command Line Flags

| Flag | Description |
|------|-------------|
| `--help` or `-h` | Display help information and usage examples |
| `--force` | Reinstall even if the component is already installed |
| `--with-deps` | Automatically install dependencies if missing |
| `--verbose` | Show detailed output during installation |
| `--domain` | Specify the primary domain for the component |
| `--client-id` | Specify client ID for multi-tenant installations |
| `--admin-email` | Specify administrator email |

### Installation Verification

Each installation script now follows this process:

1. **Pre-Installation Checks**
   - Check if the component is already installed
   - Verify if containers are running or exist but are stopped
   - Auto-start existing containers if they're not running
   - Allow forced reinstallation with `--force` flag

2. **Dependency Resolution**
   - Check for required dependencies (Docker, Traefik, etc.)
   - Report missing dependencies with clear messages
   - Automatically install dependencies with `--with-deps` flag

3. **Environment Preparation**
   - Create required directories
   - Set up networks and volumes
   - Configure environment variables

4. **Post-Installation Verification**
   - Verify successful installation
   - Store credentials securely
   - Register component in the component registry

## Logging System

AgencyStack uses a structured logging system to track installation progress and issues:

### Log Directory Structure

```
/var/log/agency_stack/
├── components/           # Component-specific logs
│   ├── wordpress.log
│   ├── erpnext.log
│   ├── posthog.log
│   ├── voip.log
│   └── mailu.log
├── integrations/         # Integration-specific logs
│   ├── wordpress.log
│   ├── erpnext.log
│   ├── posthog.log
│   ├── voip.log
│   ├── mailu.log
│   └── integration.log   # Consolidated integration log
└── validation.log        # System validation log
```

### Log Format

Each log entry follows this format:
```
YYYY-MM-DD HH:MM:SS - [LOG_LEVEL] Message
```

Example:
```
2025-04-04 20:15:30 - INFO: Starting WordPress installation for example.com
```

### Integration Logging

When components integrate with other services (email, SSO, monitoring), they log those operations to both:
- Their component-specific integration log
- The central integration log

This dual logging ensures both component-specific traceability and a consolidated view of all integration activities.

## Makefile Integration

The installation hardening features have been integrated into the Makefile with several enhancements:

1. **Validation Target**
   ```
   make validate
   ```

2. **Component Installation Targets**
   ```
   make install-wordpress
   make install-erpnext
   make install-posthog
   make install-voip
   make install-mailu
   ```

3. **Flag Support**
   ```
   make install-wordpress FORCE=true
   make install-erpnext VERBOSE=true WITH_DEPS=true
   ```

4. **Client-Specific Installations**
   ```
   make install-wordpress DOMAIN=example.com CLIENT_ID=acme
   ```

## Template for Future Components

When adding new components to AgencyStack, follow these guidelines:

1. **Script Structure**
   - Use existing components as templates
   - Follow the same validation flow
   - Implement the same flags and options

2. **Verification Steps**
   - Check if already installed
   - Verify dependencies
   - Validate system requirements

3. **Logging**
   - Log to component-specific log files
   - Use integration logs for cross-component interactions
   - Follow consistent log formatting

4. **Makefile Integration**
   - Add a target for your component
   - Support the standard flags
   - Ensure validation runs before installation

By following these standards, all components will benefit from the same robustness, security checks, and user experience.
