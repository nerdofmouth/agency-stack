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

## Installation

### Prerequisites

* Docker and Docker Compose installed
* Traefik configured as reverse proxy
* Subdomain configured in DNS (e.g., `lists.example.com`)
* Mailu or other SMTP server for email sending

### Using the Makefile

The simplest way to install Listmonk is through the AgencyStack Makefile:

```bash
# Set your domain and install
export LISTMONK_DOMAIN=lists.example.com
make listmonk

# For multi-tenant installations with a specific client ID
export LISTMONK_DOMAIN=lists.client1.com 
export CLIENT_ID=client1
make listmonk
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

## Configuration

### Main Configuration

The main configuration file is located at:

```
/opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/config/config.toml
```

You can edit this file directly or use the Makefile command:

```bash
make listmonk-config
```

### SMTP Configuration

By default, Listmonk is configured to use the Mailu SMTP server in the AgencyStack environment. The default SMTP settings assume:

* SMTP Server: `mail.{domain}` (where domain is derived from your Listmonk domain)
* SMTP Port: 587
* Username: `listmonk@{domain}`
* From Email: Same as username

You can customize these settings during installation with the `--mailu-domain`, `--mailu-user`, and `--mailu-password` options, or by editing the configuration file after installation.

## Management Commands

AgencyStack provides several commands to manage your Listmonk installation:

```bash
# Check status
make listmonk-status

# View logs
make listmonk-logs

# Start/stop/restart service
make listmonk-start
make listmonk-stop
make listmonk-restart

# Backup data
make listmonk-backup

# Access configuration
make listmonk-config
```

## Security & Hardening

The AgencyStack Listmonk installation includes several security enhancements:

* **TLS Encryption**: All traffic is encrypted via Traefik's Let's Encrypt integration
* **Security Headers**: HTTP security headers to prevent XSS, clickjacking, and other attacks
* **Database Security**: PostgreSQL uses randomly generated strong passwords
* **Network Isolation**: Docker networks isolate the application components
* **Minimal Permissions**: All containers run with minimal required permissions

## Data Location

Listmonk data is stored in the following locations:

* **Configuration**: `/opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/config/`
* **Uploads**: `/opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/uploads/`
* **Database**: `/opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/postgresql/`

## Logs

Logs are available in the following locations:

* **Installation Logs**: `/var/log/agency_stack/components/listmonk.log`
* **Application Logs**: Available via `make listmonk-logs`

## Ports

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Listmonk Web UI | 9000 | HTTP | Accessible via Traefik |

## Backup and Restore

### Backup

To backup your Listmonk data:

```bash
make listmonk-backup
```

This creates a backup of the PostgreSQL database and uploaded files in the `/opt/agency_stack/backups/listmonk/` directory.

### Restore

Restoring from a backup requires manual steps:

1. Stop the Listmonk service:
   ```bash
   make listmonk-stop
   ```

2. Restore the database:
   ```bash
   cat backup_file.sql | docker exec -i listmonk-postgres-{CLIENT_ID} psql -U listmonk listmonk
   ```

3. Restore uploads:
   ```bash
   tar -xzf listmonk_uploads_backup.tar.gz -C /opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/uploads/
   ```

4. Start the service:
   ```bash
   make listmonk-start
   ```

## Uninstallation

To completely remove Listmonk:

1. Stop and remove the containers:
   ```bash
   make listmonk-stop
   ```

2. Remove data directories:
   ```bash
   sudo rm -rf /opt/agency_stack/clients/{CLIENT_ID}/listmonk_data
   ```

3. Remove from installed components:
   ```bash
   sudo sed -i '/listmonk/d' /opt/agency_stack/installed_components.txt
   ```

## Troubleshooting

### SMTP Connection Issues

If you're having trouble with email sending:

1. Verify your SMTP credentials in the configuration file
2. Check if the SMTP server is accessible from the Listmonk container
3. Check Listmonk logs for SMTP-related errors:
   ```bash
   make listmonk-logs | grep -i smtp
   ```

### Database Connection Issues

If Listmonk can't connect to the database:

1. Ensure the PostgreSQL container is running:
   ```bash
   docker ps | grep postgres
   ```

2. Check PostgreSQL logs:
   ```bash
   docker logs listmonk-postgres-{CLIENT_ID}
   ```

### Web Interface Not Accessible

If you can't access the Listmonk web interface:

1. Check if Traefik is properly configured:
   ```bash
   docker logs traefik | grep listmonk
   ```

2. Verify the DNS settings for your domain
3. Check if the Listmonk container is running:
   ```bash
   make listmonk-status
   ```

## Integration with Other Components

### Mailu

Listmonk is integrated with Mailu for SMTP services. This allows you to send newsletters and transactional emails using your own mail server.

### Keycloak

While Listmonk doesn't natively support SSO, instructions for setting up a Keycloak proxy for authentication are provided in the following file:

```
/opt/agency_stack/clients/{CLIENT_ID}/listmonk_data/config/keycloak-sso-note.txt
```

### Prometheus

Monitoring is enabled via the Prometheus integration. Metrics are available at the `/metrics` endpoint and are automatically scraped by the Prometheus instance.

## FAQ

### Can I use an external SMTP server?

Yes, you can configure any SMTP server in the configuration file. During installation, specify your SMTP server details with the `--mailu-domain`, `--mailu-user`, and `--mailu-password` options.

### How do I change the admin password?

You can change the admin password by editing the configuration file:

```bash
make listmonk-config
```

Then modify the `app.admin_password` setting and restart the service:

```bash
make listmonk-restart
```

### Can I run multiple Listmonk instances?

Yes, using the multi-tenant capabilities of AgencyStack, you can run separate Listmonk instances for different clients by specifying a different `--client-id` during installation.

### How do I upgrade Listmonk?

To upgrade to a newer version, reinstall with the `--force` flag:

```bash
make listmonk FORCE=true
```

## Further Resources

* [Official Listmonk Documentation](https://listmonk.app/docs/)
* [Listmonk GitHub Repository](https://github.com/knadh/listmonk)
* [Listmonk API Documentation](https://listmonk.app/docs/apis/)
