# Security

## Overview
The Security component provides comprehensive system hardening for AgencyStack, implementing multiple layers of defense to protect against common threats. It includes firewall configuration, SSH hardening, automatic security updates, and ongoing security auditing.

## Features
- Uncomplicated Firewall (UFW) configuration with secure defaults
- SSH service hardening with secure authentication policies
- System-level security enhancements
- Automatic security updates
- Daily security audits with email reporting
- System resource limits
- Network protection settings

## Installation

```bash
# Standard installation
make security DOMAIN=example.com ADMIN_EMAIL=admin@example.com

# Installation with custom SSH port
make security DOMAIN=example.com ADMIN_EMAIL=admin@example.com SSH_PORT=2222

# Installation with additional open ports
make security DOMAIN=example.com ADMIN_EMAIL=admin@example.com ALLOW_PORTS=8080,8443,9000

# Skip specific hardening measures
make security DOMAIN=example.com ADMIN_EMAIL=admin@example.com --no-ufw --no-ssh-harden
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/security` | Main installation directory |
| `/opt/agency_stack/clients/<client_id>/security` | Client-specific security files |
| `/opt/agency_stack/clients/<client_id>/security/security-audit.sh` | Security audit script |
| `/opt/agency_stack/clients/<client_id>/security/audit` | Security audit reports |
| `/opt/agency_stack/security/config` | Configuration backups |
| `/etc/ssh/sshd_config.d/00-hardened.conf` | Hardened SSH configuration |
| `/etc/apt/apt.conf.d/50unattended-upgrades` | Automatic updates configuration |
| `/etc/sysctl.d/99-security.conf` | System security settings |
| `/etc/security/limits.d/99-security.conf` | System resource limits |
| `/etc/security/pwquality.conf` | Password policy configuration |
| `/var/log/agency_stack/components/security.log` | Component installation log |

## Configuration

The security component applies several configuration files to harden the system:

### Firewall (UFW)
The component configures UFW with these default settings:
- Default policy: deny incoming, allow outgoing
- Allow SSH (port 22 by default)
- Allow HTTP (port 80)
- Allow HTTPS (port 443)
- Any additional ports specified during installation

### SSH Hardening
SSH is hardened with secure defaults in `/etc/ssh/sshd_config.d/00-hardened.conf`:

```
Port 22                     # Customizable during installation
Protocol 2                  # SSH protocol version 2 only
PermitRootLogin prohibit-password  # Root login with key only
MaxAuthTries 4              # Limit authentication attempts
X11Forwarding no            # Disable X11 forwarding
PasswordAuthentication yes  # Can be set to "no" for key-only auth
```

### System Hardening
System-level hardening includes:

1. **Automatic Updates**: Configuration in `/etc/apt/apt.conf.d/50unattended-upgrades`
2. **System Limits**: Resource limits in `/etc/security/limits.d/99-security.conf`
3. **Network Protection**: Secure sysctl settings in `/etc/sysctl.d/99-security.conf`
4. **Password Policies**: Strong password requirements in `/etc/security/pwquality.conf`

## Logs

Security logs can be found in two locations:

1. Installation logs: `/var/log/agency_stack/components/security.log`
2. Security audit logs: `/opt/agency_stack/clients/<client_id>/security/audit/*.log`

To view logs:

```bash
# View installation logs
make security-logs

# View latest security audit report
cat /opt/agency_stack/clients/<client_id>/security/audit/latest-audit.log
```

## Ports

The Security component primarily configures the firewall to control access to ports. By default, it allows:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22   | TCP      | SSH (configurable) |
| 80   | TCP      | HTTP |
| 443  | TCP      | HTTPS |

Additional ports can be specified during installation.

## Management

The following Makefile targets are available:

```bash
# Install Security component
make security

# Check Security status
make security-status

# View Security logs
make security-logs

# Run a security audit
make security-restart
```

Common security management commands:

```bash
# Check firewall status
sudo ufw status

# Allow additional port
sudo ufw allow 8080/tcp

# Deny port
sudo ufw deny 8080/tcp

# Check SSH service
sudo systemctl status ssh

# View automatic update settings
cat /etc/apt/apt.conf.d/50unattended-upgrades
```

## Security Audit

The Security component includes a comprehensive security audit system that:

1. Checks firewall configuration
2. Verifies SSH hardening
3. Monitors for system updates
4. Lists open ports and running services
5. Checks for failed login attempts
6. Monitors sudo usage

The audit runs daily via cron and sends reports to the configured admin email. You can also run it manually:

```bash
sudo /opt/agency_stack/clients/<client_id>/security/security-audit.sh
```

## Security Considerations

- The default configuration balances security with usability
- For highest security, consider disabling password authentication in SSH
- Review firewall rules regularly to ensure only necessary ports are open
- The automatic security audit helps identify potential issues, but manual review is still recommended
- Consider installing additional security tools like CrowdSec for enhanced protection

## Integration with Other Components

The Security component integrates with several other AgencyStack components:

- **Fail2ban**: Complements security by providing intrusion prevention
- **Docker**: Secures container networking
- **Traefik**: Protects web services
- **Keycloak**: Provides identity management
- **Mailu**: Sends security audit notifications

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| UFW blocks legitimate traffic | Add required ports with `sudo ufw allow PORT/tcp` |
| SSH lockout | Access console and check `/etc/ssh/sshd_config.d/00-hardened.conf` |
| Automatic updates not running | Check `/etc/apt/apt.conf.d/50unattended-upgrades` |
| Security audit failures | Review logs in `/opt/agency_stack/clients/<client_id>/security/audit/` |
| Resource limits too restrictive | Adjust values in `/etc/security/limits.d/99-security.conf` |
| System update failures | Check `apt update` and `apt upgrade` manually for errors |
