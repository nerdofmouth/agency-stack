# AgencyStack One-Line Installation

This guide provides a convenient way to install AgencyStack using our integrated one-line installer. This is ideal for first-time installations on fresh systems.

## Prerequisites

- A Debian or Ubuntu-based system
- Root privileges (sudo access)
- Internet connectivity

## Quick Installation

Copy and paste the following command into your terminal:

```bash
curl -fsSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

## What the Installer Does

The one-line installer performs the following operations:

1. **Automatic Mode Detection**:
   - Automatically detects when run via curl pipe
   - Enables first-run environment preparation

2. **Initial Setup**:
   - Checks system compatibility
   - Creates a log file in `/var/log/agency_stack/`
   - Ensures you're running with appropriate permissions

3. **Dependency Installation**:
   - Installs essential utilities (`curl`, `git`, `wget`, `make`, `jq`, `bc`)
   - Prepares the system for component installation

4. **Directory Structure Setup**:
   - Creates all required directories according to AgencyStack DevOps rules
   - Sets up client and component directories

5. **Existing Installation Handling**:
   - Automatically detects if AgencyStack is already installed
   - In non-interactive mode (one-line installation), creates a backup of the existing installation
   - Backup is stored at `/opt/agency_stack_backup_<timestamp>/`
   - Proceeds with a fresh installation while preserving your data

6. **Repository Setup**:
   - Clones the AgencyStack repository (if not already present)
   - Prepares the environment for component installation

7. **Makefile Integration**:
   - Runs `make prep-dirs` to set up component directories
   - Runs `make env-check` to validate the environment

8. **Seamless Transition**:
   - Proceeds to the regular installation flow after preparation
   - Presents the component selection menu

## Manual Installation Steps

After running the one-line installer, the script will guide you through component selection and installation. You can also run individual installation commands:

1. Install Docker infrastructure:
   ```bash
   sudo make docker
   sudo make docker_compose
   ```

2. Install Traefik and SSL:
   ```bash
   sudo make traefik-ssl
   ```

3. Add security components:
   ```bash
   sudo make fail2ban
   sudo make crowdsec
   ```

4. Check installation status:
   ```bash
   sudo make alpha-check
   ```

## Logging

All installation logs are stored in `/var/log/agency_stack/install-*.log`

For component-specific logs, check `/var/log/agency_stack/components/`.

## Troubleshooting

If you encounter issues during installation:

1. Check the installation logs
2. Ensure all dependencies are properly installed
3. Verify your system meets the minimum requirements
4. Run `make env-check` to identify configuration issues

For additional help, visit the [AgencyStack Troubleshooting Guide](troubleshooting.md).
