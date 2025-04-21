---
layout: default
title: System Prerequisites - AgencyStack Documentation
---

## Migration Notice (2025-04-20)

> **Note:** As of April 2025, all prerequisite checks and fix logic have been consolidated into the unified `preflight_check_agencystack` function in `scripts/utils/common.sh`. Deprecated scripts such as `install_prerequisites.sh` and all `fix_*.sh` scripts have been removed or replaced with no-ops. All installation scripts now invoke this unified check, ensuring idempotence and full environment validation.

# System Prerequisites

The System Prerequisites component installs and configures the essential base packages, system configurations, and security settings required by all other AgencyStack components.

## Overview

This is the foundational component that prepares the server environment, ensuring all necessary dependencies are in place before installing any other components. It follows a strict idempotent approach, allowing safe re-runs without duplicating work.

**Key Features:**
- Essential system package installation
- Directory structure creation and permissions
- Firewall configuration (UFW)
- Log rotation setup
- Core security hardening

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | 1.0.0 |
| **Component Type** | Core Infrastructure |
| **Data Directory** | /opt/agency_stack |
| **Log Directory** | /var/log/agency_stack |
| **Marker File** | /opt/agency_stack/.prerequisites_ok |
| **Log Files** | /var/log/agency_stack/prerequisites-*.log |

## Installation

### Prerequisites

- Debian or Ubuntu Linux system
- Root access (sudo)
- Internet connection (for package installation)
- **DNS Configuration**: Domain(s) properly configured to point to the server IP
  - Required for Traefik, Dashboard, and other web components
  - For local testing, entries can be added to `/etc/hosts`

### Installation Commands

**Basic Installation:**
```bash
make prerequisites
```

**Installation with Specific Client:**
```bash
make prerequisites CLIENT_ID=your_client_id
```

**Check Installation Status:**
```bash
make prerequisites-status
```

**View Logs:**
```bash
make prerequisites-logs
```

**Force Reinstallation:**
```bash
make prerequisites-restart
```

## Configuration Details

The prerequisites component performs the following tasks:

1. **Directory Structure Setup**:
   - Creates standard paths at `/opt/agency_stack`
   - Sets up log directories at `/var/log/agency_stack`
   - Establishes client-specific subdirectories

2. **System Package Installation**:
   - Essential utilities: curl, wget, git, make, jq, bc
   - Security tools: openssl, gnupg, ca-certificates
   - Runtime dependencies: python3, pip, apt-transport-https

3. **Log Rotation Configuration**:
   - Sets up logrotate configuration for `/var/log/agency_stack/*.log`
   - Configures daily rotation with 14-day retention
   - Ensures compressed archives for space efficiency

4. **Firewall Setup**:
   - Installs and configures UFW (Uncomplicated Firewall)
   - Default deny incoming, allow outgoing policy
   - Permits SSH, HTTP, and HTTPS services

## Security Considerations

- All operations are performed with strict error checking
- Installation is idempotent and can be safely re-run
- Follows the principle of least privilege
- Creates minimal required system changes
- Uses absolute paths to prevent directory traversal issues

## Troubleshooting

**Installation Fails with Package Errors**:
- Check internet connectivity
- Verify apt sources are correctly configured
- Run `apt update` manually to identify specific issues

**Firewall Configuration Issues**:
- Check if UFW is installed: `ufw status`
- Ensure ports 22, 80, and 443 are allowed
- Review logs at `/var/log/ufw.log`

**Directory Permission Problems**:
- Verify ownership of `/opt/agency_stack` directories
- Ensure the script is run with sudo/root permissions

## Integration with Other Components

The Prerequisites component is foundational and required by all other AgencyStack components. The `.prerequisites_ok` marker file indicates successful installation, which is checked by other components before they attempt installation.

## Advanced Usage

**Forcing Reinstallation:**
```bash
sudo rm -f /opt/agency_stack/.prerequisites_ok
make prerequisites
```

**Using with Advanced Options:**
```bash
make prerequisites VERBOSE=true FORCE=true
```
