# Fail2ban

## Overview
Fail2ban is an intrusion prevention framework that protects AgencyStack services from brute-force attacks. It monitors log files for malicious activity and temporarily bans IP addresses that show signs of attacking the system by updating firewall rules.

## Features
- Automatic detection and prevention of brute force attacks
- Customizable ban policies and thresholds
- Jail configurations for different services
- Email notifications on banning events
- Integration with AgencyStack logs and services
- Centralized monitoring and management

## Installation

```bash
# Standard installation
make fail2ban DOMAIN=example.com ADMIN_EMAIL=admin@example.com

# Installation with custom ban settings
make fail2ban DOMAIN=example.com ADMIN_EMAIL=admin@example.com \
  BAN_TIME=7200 FIND_TIME=900 MAX_RETRY=3

# Multi-tenant installation
make fail2ban DOMAIN=example.com ADMIN_EMAIL=admin@example.com CLIENT_ID=client1
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/fail2ban` | Main installation directory |
| `/opt/agency_stack/clients/<client_id>/fail2ban` | Client-specific Fail2ban files |
| `/opt/agency_stack/clients/<client_id>/fail2ban/fail2ban-status.sh` | Status monitoring script |
| `/opt/agency_stack/clients/<client_id>/fail2ban/fail2ban-notify.sh` | Email notification script |
| `/opt/agency_stack/fail2ban/config` | Configuration backups |
| `/etc/fail2ban/jail.local` | Main Fail2ban configuration |
| `/etc/fail2ban/jail.d/` | Service-specific jail configurations |
| `/etc/fail2ban/filter.d/` | Custom filter definitions |
| `/var/log/agency_stack/components/fail2ban.log` | Component installation log |
| `/var/log/fail2ban.log` | Fail2ban operational log |

## Configuration

Fail2ban's main configuration file is `/etc/fail2ban/jail.local`, which sets global parameters:

```ini
[DEFAULT]
bantime = 3600       # Ban duration in seconds
findtime = 600       # Time window to count failures
maxretry = 5         # Max failures before banning
ignoreip = 127.0.0.1/8  # IPs to ignore
destemail = admin@example.com  # Email for notifications
```

Service-specific configurations are in `/etc/fail2ban/jail.d/`:

- **SSH**: `/etc/fail2ban/jail.d/sshd.conf`
- **Traefik**: `/etc/fail2ban/jail.d/traefik.conf` (if installed)
- **Keycloak**: `/etc/fail2ban/jail.d/keycloak.conf` (if installed)

You can modify these files to adjust protection for specific services.

## Logs

Fail2ban logs can be found in two locations:

1. Installation logs: `/var/log/agency_stack/components/fail2ban.log`
2. Operational logs: `/var/log/fail2ban.log`

To view logs:

```bash
# View Fail2ban action logs through Makefile
make fail2ban-logs

# View raw operational logs
sudo cat /var/log/fail2ban.log

# View installation logs
cat /var/log/agency_stack/components/fail2ban.log
```

## Ports

Fail2ban doesn't listen on any ports itself - it runs as a background service monitoring logs and updating firewall rules. It protects services that are listening on various ports, including:

- SSH (22/tcp)
- HTTP/HTTPS (80/tcp, 443/tcp)
- Other services as configured in jail files

## Management

The following Makefile targets are available:

```bash
# Install Fail2ban
make fail2ban

# Check Fail2ban status and view banned IPs
make fail2ban-status

# View Fail2ban logs
make fail2ban-logs

# Restart Fail2ban service
make fail2ban-restart
```

Common Fail2ban commands:

```bash
# View status of all jails
sudo fail2ban-client status

# View status of a specific jail
sudo fail2ban-client status sshd

# Manually ban an IP address
sudo fail2ban-client set sshd banip 192.168.1.1

# Manually unban an IP address
sudo fail2ban-client set sshd unbanip 192.168.1.1
```

## Jail Configuration

AgencyStack includes preconfigured jails for common services:

### SSH
```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
```

### Traefik (Web Server)
```ini
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
```

### Keycloak (Identity Server)
```ini
[keycloak]
enabled = true
port = http,https
filter = keycloak
logpath = /opt/agency_stack/clients/<client_id>/keycloak/logs/keycloak.log
maxretry = 5
```

## Security Considerations

- The default configuration may need adjustment based on legitimate traffic patterns
- Too strict settings (short findtime or low maxretry) can lead to false positives
- Too lenient settings (long findtime or high maxretry) can reduce effectiveness
- Whitelisting internal IPs is important to prevent locking out legitimate users
- Regular review of ban logs helps identify persistent threats

## Integration with Other Components

Fail2ban integrates with several other AgencyStack components:

- **Traefik**: Protects against web request brute force attacks
- **Keycloak**: Protects against authentication brute force attacks
- **Email (Mailu)**: Sends notifications when IPs are banned
- **Loki**: Can forward logs for centralized monitoring
- **Grafana**: Can visualize ban activity through dashboard integration

## Custom Filters

Fail2ban uses regex-based filters to detect malicious activity in logs. You can create custom filters in `/etc/fail2ban/filter.d/` for any application that produces logs.

Example filter for detecting failed logins:
```ini
[Definition]
failregex = ^.* Failed login attempt from <HOST>.*$
ignoreregex =
```

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| False positives | Add IP to ignoreip in jail.local or increase maxretry |
| Fail2ban not starting | Check logs with `sudo journalctl -u fail2ban` |
| IP not being banned | Verify log file path and permissions |
| No email notifications | Check sendmail configuration and test with mail command |
| Firewall conflicts | Ensure iptables or ufw isn't blocking Fail2ban actions |
| Log format changes | Update regex patterns in filter files to match new log format |
