---
layout: default
title: Mailu - AgencyStack Documentation
---

# Mailu

## Overview

Mailu is a complete, sovereign email server solution for AgencyStack, providing a full suite of email services including SMTP, IMAP, webmail, anti-spam, and admin tools. It enables complete control over email communication without reliance on external providers.

## Features

- **Complete Email Server**: SMTP, IMAP, and POP3 services
- **Webmail Interface**: Access emails through a web browser
- **Admin Interface**: User-friendly domain and account management
- **Anti-spam & Anti-virus**: Built-in filtering with Rspamd and ClamAV
- **DKIM, SPF, and DMARC**: Email authentication standards
- **Automatic TLS**: Secure communication with Let's Encrypt
- **Sieve Filtering**: Server-side email filtering and rules
- **Catch-all Addresses**: Receive mail for any address in your domains
- **Relay Options**: Smart host configuration for outbound mail

## Prerequisites

- Docker and Docker Compose
- DNS control for your domain
- Public IP address with ports 25, 465, 587, 993 available
- Traefik for routing and TLS termination

## Installation

Install Mailu using the Makefile:

```bash
make mailu
```

Options:

- `--domain=<domain>`: Primary mail domain
- `--postmaster=<email>`: Postmaster email address
- `--admin-email=<email>`: Admin user email
- `--admin-password=<password>`: Initial admin password
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies
- `--force`: Override existing installation

## Configuration

Mailu configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/mailu/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MAIL_DOMAIN` | Primary mail domain | From `--domain` |
| `POSTMASTER` | Postmaster email address | From `--postmaster` |
| `SECRET_KEY` | Secret key for sessions | Auto-generated |
| `TLS_FLAVOR` | TLS configuration (letsencrypt, cert, notls) | `letsencrypt` |
| `AUTH_RATELIMIT` | Authentication rate limit | `10/minute` |
| `DISABLE_STATISTICS` | Disable anonymous statistics | `True` |
| `SUBNET` | Docker subnet for Mailu | `10.10.10.0/24` |
| `WEBMAIL` | Webmail client (roundcube, rainloop, none) | `roundcube` |
| `WEBMAIL_THEME` | Webmail theme | `agency` |

## Required DNS Records

After installation, configure these DNS records:

```
# MX record
@ IN MX 10 mail.yourdomain.com.

# SPF record
@ IN TXT "v=spf1 mx ~all"

# DKIM record (generated during installation)
dkim._domainkey IN TXT "v=DKIM1; k=rsa; p=..."

# DMARC record
_dmarc IN TXT "v=DMARC1; p=reject; rua=mailto:postmaster@yourdomain.com"

# A/AAAA records
mail IN A 203.0.113.1
```

## Usage

### Management Commands

```bash
# Check status
make mailu-status

# View logs
make mailu-logs

# Restart service
make mailu-restart
```

### Web Interfaces

- **Admin Panel**: `https://mail.yourdomain.com/admin`
- **Webmail**: `https://mail.yourdomain.com/webmail`

### Email Client Configuration

For external email clients, use these settings:

#### IMAP Settings
- Server: `mail.yourdomain.com`
- Port: `993`
- Security: SSL/TLS
- Authentication: Normal password
- Username: Full email address

#### SMTP Settings
- Server: `mail.yourdomain.com`
- Port: `587`
- Security: STARTTLS
- Authentication: Normal password
- Username: Full email address

## Security

Mailu is configured with the following security measures:

- TLS encryption for all mail protocols
- Strong anti-spam filtering with Rspamd
- ClamAV virus scanning for attachments
- Authentication rate limiting
- IP-based access control options
- DKIM/SPF/DMARC email authentication

## Monitoring

All Mailu operations are logged to:

```
/var/log/agency_stack/components/mailu.log
```

Individual service logs are also available:

```
/var/log/agency_stack/components/mailu_smtp.log
/var/log/agency_stack/components/mailu_imap.log
/var/log/agency_stack/components/mailu_antispam.log
```

## Troubleshooting

### Common Issues

1. **Email delivery failures**:
   - Check DNS records (MX, SPF, DKIM, DMARC)
   - Verify outbound ports are not blocked
   - Check Rspamd scoring and potential spam classification

2. **Authentication failures**:
   - Verify user credentials in the admin panel
   - Check for account restrictions or lockouts
   - Verify TLS certificate validity

3. **High CPU or memory usage**:
   - Check ClamAV and Rspamd resource settings
   - Consider enabling message size limits
   - Monitor for spam or relay attacks

### Logs

For detailed logs:

```bash
# Main logs
tail -f /var/log/agency_stack/components/mailu.log

# SMTP server logs (useful for delivery issues)
tail -f /var/log/agency_stack/components/mailu_smtp.log
```

## Integration with Other Components

Mailu integrates with:

1. **Keycloak**: Optional SSO integration
2. **Traefik**: For routing and TLS termination
3. **Prometheus/Grafana**: For monitoring
4. **Fail2Ban**: For additional intrusion protection

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/mailu/config/mailu.env
```

Custom webmail themes can be added to:

```
/opt/agency_stack/clients/${CLIENT_ID}/mailu/webmail/themes/
```

## Backup and Restore

Mail data is stored in Docker volumes. To back up:

```bash
# Backup mail data
make mailu-backup

# Restore from backup
make mailu-restore --backup-file=<path-to-backup>
```

## Multi-domain Configuration

Add additional domains through the admin interface:

1. Log in to the admin panel
2. Navigate to Domains > Add domain
3. Configure DNS records for the new domain
4. Create users or aliases for the new domain
