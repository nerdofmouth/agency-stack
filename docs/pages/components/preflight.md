# Pre-Flight Installation Verification

This component verifies that your system meets all requirements specified in the pre-installation checklist before proceeding with AgencyStack installation.

## Purpose

The pre-flight verification performs comprehensive checks of your server environment to ensure it meets all necessary requirements for a successful AgencyStack installation. It helps identify potential issues before beginning the installation process.

## Usage

### Run the verification

```bash
make preflight-check DOMAIN=your-domain.com
```

### Options

The preflight check accepts several options:

- `DOMAIN`: Your domain name (required)
- `INTERACTIVE=false`: Run in non-interactive mode
- `SKIP_PORTS=true`: Skip port availability checks
- `SKIP_DNS=true`: Skip DNS verification
- `SKIP_SYSTEM=true`: Skip system requirements checks
- `SKIP_NETWORK=true`: Skip network checks
- `SKIP_SSH=true`: Skip SSH configuration checks

## Paths

- **Installation Script**: `/scripts/components/preflight_check.sh`
- **Log File**: `/var/log/agency_stack/components/preflight.log`
- **Report File**: `/opt/agency_stack/repo/pre_installation_report.md`

## Checklist Items

The pre-flight verification checks the following items:

### System Requirements
- OS type and version
- RAM (minimum 8GB, 16GB+ recommended)
- Disk space (minimum 50GB, 100GB+ recommended)
- Root/sudo access

### Network Requirements
- Public static IP
- Domain name configuration
- Required ports (80, 443, 22, 9443)
- Firewall/ISP port blocking

### SSH Configuration
- Key-based authentication
- Password authentication status

### Preparation Tasks
- System updates
- Hostname configuration
- Timezone configuration

## Interpreting the Report

The verification report categorizes issues into two types:

- **Critical Issues**: Must be resolved before installation
- **Warnings**: Should be addressed for optimal operation but won't prevent installation

## Resolving Common Issues

### Insufficient RAM
- Upgrade your server's RAM
- Or use a more powerful VPS/dedicated server

### Insufficient Disk Space
- Upgrade your server's disk
- Clean up unnecessary files

### Domain Configuration
- Verify DNS settings with your domain registrar
- Ensure A records point to your server's public IP
- Allow time for DNS propagation (up to 48 hours)

### Port Availability
- Check for services using required ports: `sudo lsof -i :<port>`
- Configure your firewall: `sudo ufw allow <port>/tcp`
- Contact your ISP if ports are blocked at the network level

## Security Considerations

The pre-flight verification helps identify security concerns:
- Password-based SSH authentication (should be disabled)
- Missing SSH key configuration
- System update status

## Related Components

- **prerequisites**: Installs required system packages
- **validate_system**: Performs system validation during installation
