# Fail2Ban

## Overview

Fail2Ban is an intrusion prevention system that protects AgencyStack servers from brute-force and denial-of-service attacks. It monitors logs and temporarily bans IPs that show malicious behavior by updating firewall rules.

## Installation

```bash
# Standard installation
make fail2ban

# With custom options
make fail2ban CLIENT_ID=myagency DOMAIN=example.com
```

## Configuration

The Fail2Ban component stores its configuration in:
- `/opt/agency_stack/clients/${CLIENT_ID}/fail2ban/`

Key files:
- `jail.local`: Main configuration file with ban settings
- `filter.d/`: Directory containing custom filter rules
- `action.d/`: Directory containing custom ban actions

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client identifier | `default` |
| `--domain` | Domain for rule configuration | `localhost` |
| `--force` | Force reinstallation | `false` |
| `--ban-time` | Ban duration in seconds | `3600` (1 hour) |
| `--find-time` | Time window for counting retries | `600` (10 minutes) |
| `--max-retry` | Number of failures before ban | `5` |
| `--custom-jails` | Path to custom jail config | `""` |

## Services Protected

By default, Fail2Ban provides protection for:

- SSH (port 22)
- Web services (HTTP/HTTPS)
- Mail services (if installed)
- Database services (if exposed)

## Restart and Maintenance

```bash
# Check status
make fail2ban-status

# View logs
make fail2ban-logs

# Restart the service
make fail2ban-restart
```

## Security

The Fail2Ban component enhances security by:

- Detecting brute force login attempts
- Blocking IPs with suspicious behavior
- Protecting services from DoS attacks
- Maintaining ban logs for security analysis
- Supporting client-specific ban rules in multi-tenant setups

## Troubleshooting

Common issues:

1. **Self-lockout**
   - Add your IP to the `ignoreip` directive in jail.local
   - Reset bans: `fail2ban-client unban all`

2. **Service Not Protected**
   - Check if the appropriate jail is enabled
   - Verify log file paths in jail configuration
   - Test regex filter patterns

3. **Excessive CPU Usage**
   - Increase findtime and bantime for persistent attackers
   - Use more efficient regex patterns
   - Consider using ipset for large ban lists
