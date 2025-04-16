# Mailu

## Overview

Mailu is a fully-featured, Docker-based mail server solution that provides a comprehensive email platform for AgencyStack. It includes SMTP for sending and receiving mail, IMAP for mail access, a webmail interface, and admin capabilities.

### Key Features

- **Complete Email Solution**: SMTP, IMAP, and webmail in one cohesive system
- **Anti-Spam & Anti-Virus**: Built-in spam filtering with RSpamd and ClamAV integration
- **Modern Webmail Interface**: Multiple webmail options (Roundcube and Rainloop)
- **Admin Interface**: Easy management of domains, users, and email settings
- **Multi-Tenant Support**: Isolated mail services per client in AgencyStack
- **TLS Encryption**: Secure mail transfer through Traefik integration
- **DKIM/SPF/DMARC**: Email authentication to improve deliverability
- **Container-Based**: Runs as a set of Docker containers for easy management

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik (for TLS termination and routing)
- A valid domain name with proper DNS records (A, MX, TXT for SPF, DKIM, and DMARC)
- Open network ports (25, 465, 587, 993, 995, 80, 443)

### Installation Process

The installation is handled by the `install_mailu.sh` script, which can be executed using:

```bash
make mailu DOMAIN=mail.example.com EMAIL_DOMAIN=example.com ADMIN_EMAIL=admin@example.com
```

Optional parameters:
- `CLIENT_ID=tenant1` - For multi-tenant setups
- `ADMIN_PASSWORD=secure_password` - Set a specific admin password
- `FORCE=true` - Force reinstallation
- `WITH_DEPS=true` - Automatically install dependencies

### DNS Configuration

For proper email functionality, you must configure these DNS records:

```
# MX record (priority 10)
example.com. IN MX 10 mail.example.com.

# SPF record
example.com. IN TXT "v=spf1 mx -all"

# DKIM record (generated during installation)
dkim._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=..."

# DMARC record
_dmarc.example.com. IN TXT "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
```

The installation script will generate all necessary DKIM keys and provide instructions for DNS configuration.

## Configuration

### Directory Structure

```
/opt/agency_stack/mailu/[DOMAIN]/
├── .env                 # Environment variables
├── docker-compose.yml   # Docker Compose configuration
├── data/                # Persistent data
│   ├── mail/            # Mail storage
│   ├── redis/           # Redis data
│   ├── filter/          # Filtering rules
│   ├── dkim/            # DKIM keys
│   └── certs/           # TLS certificates
└── mailu.env            # Mailu-specific configuration
```

For multi-tenant setups, the path becomes:
```
/opt/agency_stack/mailu/clients/[CLIENT_ID]/[DOMAIN]/
```

### Default Configuration

Mailu is configured with the following defaults:

- HTTPS enabled through Traefik
- Admin interface protected by authentication
- Spam filtering enabled with conservative settings
- DKIM signing for all outbound mail
- 25GB default quota per mailbox

### Customization

To customize Mailu beyond the default settings, modify the `mailu.env` file in the installation directory. The main settings include:

- `DOMAIN`: The primary domain for the mail server
- `HOSTNAMES`: Additional domains served by this mail server
- `POSTMASTER`: Email address for the postmaster
- `SECRET_KEY`: Used for encryption (auto-generated)
- `SUBNET`: Network subnet for the containers
- `MESSAGE_SIZE_LIMIT`: Maximum email size in bytes
- `AUTH_RATELIMIT`: Rate limiting for authentication attempts

For advanced customization, see the [official Mailu documentation](https://mailu.io/2.0/configuration.html).

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| SMTP | 25 | TCP | Mail reception |
| Submission | 587 | TCP | Mail sending (authenticated) |
| SMTPS | 465 | TCP | Mail sending over SSL |
| IMAP | 143 | TCP | Mail access |
| IMAPS | 993 | TCP | Secure mail access |
| Web Admin | 80/443 | HTTP/S | Admin and webmail interfaces |

All these services are routed through Traefik, which handles TLS termination and routing based on hostnames.

### Endpoints

- Admin Interface: `https://mail.example.com/admin/`
- Webmail: `https://mail.example.com/webmail/`
- SMTP Server: `mail.example.com:25` (reception)
- Submission: `mail.example.com:587` (sending, requires authentication)
- IMAP Server: `mail.example.com:993` (SSL)

## Logs & Monitoring

### Log Files

- Installation logs: `/var/log/agency_stack/components/install_mailu-[timestamp].log`
- Component logs: `/var/log/agency_stack/components/mailu.log`
- Container logs accessible via `docker logs mailu_[container]`

To view logs using make:
```bash
make mailu-logs DOMAIN=mail.example.com [CONTAINER=admin|smtp|imap|webmail]
```

### Monitoring

Mailu exports basic metrics that can be integrated with Prometheus and Grafana for monitoring:

- SMTP/IMAP connection counts
- Queue sizes
- Authentication success/failure rates
- Message delivery statistics

## Security Considerations

### Network Security

- All traffic is routed through Traefik with TLS encryption
- Authentication rate limiting is enabled by default
- DKIM/SPF/DMARC are enabled for enhanced security
- Passwords are stored securely in `/opt/agency_stack/secrets/mailu/`

### Email Security

- SPF, DKIM, and DMARC help prevent email spoofing
- ClamAV provides antivirus scanning for mail
- RSpamd provides anti-spam filtering

### Hardening Recommendations

- Keep the system updated regularly
- Monitor authentication logs for suspicious activity
- Configure strict SPF and DMARC policies
- Enable additional security headers through Traefik
- Use 2FA for administrative access when possible

## Integration with Other Components

### Listmonk

Mailu integrates with Listmonk for newsletter and email campaign management:
```bash
make mailu-listmonk DOMAIN=mail.example.com
```

### Chatwoot

For customer support email integration with Chatwoot:
```bash
# Implemented in upcoming release
```

### WordPress & Ghost

To configure WordPress and Ghost to use Mailu for sending emails:
```bash
make wordpress-mailu-integration DOMAIN=blog.example.com MAIL_DOMAIN=mail.example.com
```

### ERPNext

ERPNext can use Mailu as its SMTP provider for outgoing notifications and emails.

## Troubleshooting

### Common Issues

1. **Email delivery issues**
   - Check that DNS records (MX, SPF, DKIM, DMARC) are properly configured
   - Verify that port 25 is open (many cloud providers block it by default)
   - Check your server's IP reputation on blacklists

2. **Authentication failures**
   - Verify credentials in the mail client
   - Ensure SSL/TLS settings are correct
   - Check for rate-limiting or IP blocking

3. **Webmail access issues**
   - Verify that Traefik routes are correctly set up
   - Check for SSL certificate issues
   - Confirm that webmail containers are running

### Diagnostics

To diagnose mail delivery issues:
```bash
make mailu-diagnose DOMAIN=mail.example.com
```

To check mail server connectivity:
```bash
telnet mail.example.com 25
```

To test SMTP authentication:
```bash
swaks --auth --server mail.example.com:587 --to test@example.com --from admin@example.com
```

## Backup & Recovery

### Backup Procedure

Mail data can be backed up using:
```bash
make mailu-backup DOMAIN=mail.example.com
```

This creates a compressed archive of:
- Mail data
- User accounts
- Configuration files

### Recovery Procedure

To restore from backup:
```bash
make mailu-restore DOMAIN=mail.example.com BACKUP_FILE=/path/to/backup.tar.gz
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make mailu` | Install Mailu email server |
| `make mailu-status` | Check status of Mailu |
| `make mailu-logs` | View Mailu logs |
| `make mailu-restart` | Restart Mailu services |
| `make mailu-backup` | Backup Mailu data |
| `make mailu-restore` | Restore Mailu from backup |
| `make mailu-listmonk` | Integrate with Listmonk |
| `make mailu-test-email` | Send a test email |
| `make mailu-diagnose` | Run diagnostics tests |
| `make mailu-update` | Update Mailu to newer version |

## Conclusion

Mailu provides AgencyStack with a robust, self-hosted email solution that integrates well with the rest of the stack. It offers a good balance of features, security, and ease of management while maintaining sovereignty over your email communications.

For more advanced email features or larger deployments, consider exploring additional anti-spam solutions or dedicated email security gateways.
