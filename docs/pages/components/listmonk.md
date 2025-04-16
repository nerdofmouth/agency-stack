---
layout: default
title: Listmonk - Newsletter & Mailing List Manager - AgencyStack Documentation
---

# Listmonk Email Newsletter Component

Listmonk is a self-hosted, modern, and feature-rich newsletter and mailing list manager. This component is part of the AgencyStack Email & Communication suite.

![Listmonk Logo](https://listmonk.app/static/images/logo.svg)

## Overview

Listmonk provides a complete solution for creating, managing, and sending newsletters and transactional emails. It features a clean, modern interface and powerful capabilities for subscriber management, campaign creation, and performance analytics.

* **Version**: v2.5.1
* **Category**: Email & Communication
* **Website**: [https://listmonk.app](https://listmonk.app)
* **Github**: [https://github.com/knadh/listmonk](https://github.com/knadh/listmonk)

## Features

* **Subscriber Management**: Import, organize, and segment subscribers
* **Campaign Creation**: Rich text editor for crafting beautiful newsletters
* **Subscriber Lists**: Organize subscribers into multiple lists and segments
* **Email Templates**: Create and save reusable email templates
* **Analytics**: Track open rates, click rates, and other campaign metrics
* **Bounce Handling**: Automatically manage bounced emails
* **Multi-tenancy Support**: Isolate client data through AgencyStack's client-aware installation
* **Keycloak SSO Integration**: Single sign-on support through AgencyStack identity provider

## Installation

### Prerequisites

* Docker and Docker Compose installed
* Traefik configured as reverse proxy
* Subdomain configured in DNS (e.g., `lists.example.com`)
* Mailu or other SMTP server for email sending

### Using the Makefile

The simplest way to install Listmonk is through the AgencyStack Makefile:

```bash
# Interactive installation with prompts
make listmonk

# Set your domain and install directly
make listmonk DOMAIN=lists.example.com

# For multi-tenant installations with a specific client ID
make listmonk DOMAIN=lists.client1.com CLIENT_ID=client1

# With Mailu integration
make listmonk DOMAIN=lists.example.com MAILU_DOMAIN=mail.example.com MAILU_USER=listmonk@example.com MAILU_PASSWORD=your_password
```

### Manual Installation

You can also install Listmonk manually using the installation script:

```bash
# Basic installation
sudo /opt/agency_stack/scripts/components/install_listmonk.sh --domain lists.example.com

# Advanced installation with client ID and custom SMTP settings
sudo /opt/agency_stack/scripts/components/install_listmonk.sh \
  --domain lists.client1.com \
  --client-id client1 \
  --mailu-domain mail.client1.com \
  --mailu-user newsletters@client1.com \
  --mailu-password your_secure_password \
  --with-deps \
  --force
```

## Directory Structure

Listmonk follows the standardized AgencyStack directory structure:

```
/opt/agency_stack/clients/[CLIENT_ID]/
├── listmonk_data/
│   ├── config/           # Configuration files
│   │   └── config.toml   # Main configuration
│   ├── uploads/          # Media uploads
│   ├── postgresql/       # Database files
│   └── docker-compose.yml
└── .env                  # Environment variables

/var/log/agency_stack/components/
└── listmonk.log          # Installation and operation logs
```

For the default installation (non-client-specific), the path is `/opt/agency_stack/clients/default/`.

## Configuration

### Main Configuration

The main configuration file is located at:

```
/opt/agency_stack/clients/[CLIENT_ID]/listmonk_data/config/config.toml
```

Key configuration sections include:

```toml
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "listmonk"  # Changed during setup

[privacy]
individual_tracking = true
unsubscribe_tracker = true

[smtp]
enabled = true
host = "mail.example.com"
port = 587
auth_protocol = "login"
username = "listmonk@example.com"
password = "your_password"
email_headers = { "X-AgencyStack" = "Listmonk" }
```

### SMTP Configuration with Mailu

Listmonk integrates seamlessly with the AgencyStack Mailu email server:

```bash
make listmonk-mailu DOMAIN=lists.example.com MAILU_DOMAIN=mail.example.com MAILU_USER=listmonk@example.com MAILU_PASSWORD=your_password
```

This configures Listmonk to use Mailu as its SMTP relay for sending all newsletters and transactional emails.

## Standardized Makefile Targets

AgencyStack provides standardized Makefile targets for managing Listmonk:

| Target | Description | Example |
|--------|-------------|---------|
| `make listmonk` | Install Listmonk | `make listmonk DOMAIN=lists.example.com` |
| `make listmonk-status` | Check Listmonk status | `make listmonk-status DOMAIN=lists.example.com` |
| `make listmonk-logs` | View Listmonk logs | `make listmonk-logs DOMAIN=lists.example.com` |
| `make listmonk-restart` | Restart Listmonk | `make listmonk-restart DOMAIN=lists.example.com` |
| `make listmonk-mailu` | Integrate with Mailu | `make listmonk-mailu DOMAIN=lists.example.com MAILU_DOMAIN=mail.example.com` |

All targets support the following common parameters:
- `DOMAIN`: The domain name for Listmonk (required)
- `CLIENT_ID`: For multi-tenant setups (optional)

## Security & Hardening

The AgencyStack Listmonk installation includes several security enhancements:

* **TLS Encryption**: All traffic is encrypted via Traefik's Let's Encrypt integration
* **Security Headers**: HTTP security headers to prevent XSS, clickjacking, and other attacks
* **Database Security**: PostgreSQL uses randomly generated strong passwords
* **Network Isolation**: Docker networks isolate the application components
* **Minimal Permissions**: All containers run with minimal required permissions
* **Rate Limiting**: API rate limiting to prevent abuse
* **CSRF Protection**: Protection against Cross-Site Request Forgery attacks
* **Secure Password Storage**: All passwords are securely hashed
* **Resource Constraints**: Container resource limits to prevent DoS

### Security Best Practices

1. **Change Default Admin Password**: Always change the default admin password immediately after installation
2. **Use Strong SMTP Credentials**: Use unique, strong passwords for the SMTP relay
3. **Enable Keycloak SSO**: Use the AgencyStack SSO integration for centralized authentication
4. **Regular Backups**: Schedule regular backups of your subscriber data
5. **Review Access Logs**: Periodically review access logs for suspicious activity

## Logs & Monitoring

### Log Locations

* **Installation Logs**: `/var/log/agency_stack/components/listmonk.log`
* **Application Logs**: Available via `make listmonk-logs`
* **Database Logs**: `/opt/agency_stack/clients/[CLIENT_ID]/listmonk_data/postgresql/logs/`

### Prometheus Metrics

Listmonk exposes metrics at `/metrics` for integration with Prometheus monitoring. Key metrics include:

* `listmonk_campaigns_total`: Total number of campaigns
* `listmonk_subscribers_total`: Total number of subscribers
* `listmonk_message_sends_total`: Total messages sent
* `listmonk_message_opens_total`: Total message opens
* `listmonk_message_clicks_total`: Total message clicks
* `listmonk_message_bounces_total`: Total message bounces

## Integration with Other Components

### Mailu Email Server

Listmonk integrates with Mailu for SMTP relay services:

```bash
make listmonk-mailu DOMAIN=lists.example.com MAILU_DOMAIN=mail.example.com
```

### Keycloak SSO

For centralized authentication, Listmonk can be integrated with Keycloak:

```bash
# In development - coming soon
```

### ERPNext

Listmonk can be integrated with ERPNext to synchronize contacts:

```bash
# In development - coming soon
```

### WordPress & Ghost

For integrating Listmonk with WordPress or Ghost:

```bash
# Example for WordPress subscribers/users integration
# In development - coming soon
```

## Ports & Networking

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Listmonk Web UI | 9000 | HTTP | Accessible via Traefik |
| PostgreSQL | 5432 | TCP | Internal only, not exposed |

All service URLs are routed through Traefik which provides TLS termination and handles all external traffic on ports 80/443.

## Backup and Restore

### Backup

To backup your Listmonk data:

```bash
make listmonk-backup DOMAIN=lists.example.com [CLIENT_ID=client1]
```

This creates a complete backup including:
- PostgreSQL database dump
- Configuration files
- Media uploads
- Environment variables

Backups are stored in `/opt/agency_stack/backups/listmonk/[TIMESTAMP]/`.

### Restore

To restore from a backup:

```bash
make listmonk-restore DOMAIN=lists.example.com BACKUP=/path/to/backup.tar.gz [CLIENT_ID=client1]
```

## Troubleshooting

### Common Issues

1. **SMTP Connection Errors**
   - Verify SMTP credentials are correct
   - Check firewall rules for outgoing SMTP traffic
   - Confirm Mailu is running properly

2. **Database Connection Issues**
   - Check database logs in `/opt/agency_stack/clients/[CLIENT_ID]/listmonk_data/postgresql/logs/`
   - Verify database service is running with `docker ps | grep listmonk_db`
   - Check disk space availability

3. **Performance Issues**
   - Monitor resource usage with `docker stats`
   - Consider increasing container resource limits
   - Optimize large subscriber lists with proper segmentation

4. **Template Rendering Problems**
   - Check for syntax errors in your email templates
   - Preview emails before sending to catch formatting issues
   - Test with multiple email clients for compatibility

### Diagnostic Commands

```bash
# Check container health
docker ps --filter "name=listmonk_"

# View application logs
make listmonk-logs DOMAIN=lists.example.com

# Check database status
docker exec -it listmonk_db psql -U listmonk -c "\l"

# Test SMTP connection
docker exec -it listmonk_app telnet [SMTP_SERVER] [SMTP_PORT]
```

## Upgrading

To upgrade Listmonk to the latest version:

```bash
make listmonk-upgrade DOMAIN=lists.example.com [CLIENT_ID=client1]
```

Always backup your data before upgrading:

```bash
make listmonk-backup DOMAIN=lists.example.com [CLIENT_ID=client1]
```

## Reference Documentation

- [Listmonk Official Documentation](https://listmonk.app/docs)
- [Listmonk GitHub Repository](https://github.com/knadh/listmonk)
- [AgencyStack Email & Communication Suite](/pages/communication.html)
- [Mailu Integration](/pages/components/mailu.html)
