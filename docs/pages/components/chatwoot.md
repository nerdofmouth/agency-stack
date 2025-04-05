---
layout: default
title: Chatwoot - Customer Service Platform - AgencyStack Documentation
---

# Chatwoot Customer Service Platform

Chatwoot is a powerful, open-source customer service platform that enables businesses to communicate with customers across multiple channels, including live chat, email, and social media.

![Chatwoot Logo](https://www.chatwoot.com/docs/assets/images/logo.svg)

## Overview

Chatwoot provides a unified inbox for all customer communications, team collaboration tools, and automation capabilities to help businesses deliver exceptional customer service.

* **Version**: v3.5.0
* **Category**: Business Applications
* **Website**: [https://www.chatwoot.com](https://www.chatwoot.com)
* **Github**: [https://github.com/chatwoot/chatwoot](https://github.com/chatwoot/chatwoot)

## Features

* **Omnichannel Support**: Manage conversations from website chat, Facebook, Twitter, WhatsApp, and email in one place
* **Team Collaboration**: Internal notes, private discussions, and assignment capabilities
* **Automation**: Auto-assign conversations, canned responses, and chatbots
* **Custom Attributes**: Track and store custom information about contacts
* **Multi-language Support**: Interface available in over 20 languages
* **API Access**: Extensive REST API for custom integrations
* **Analytics**: Track team performance and customer satisfaction
* **Mobile Apps**: Native apps for Android and iOS
* **Multi-tenant Support**: Isolate client data through AgencyStack's client-aware installation

## Installation

### Prerequisites

* Docker and Docker Compose installed
* Traefik configured as reverse proxy
* Subdomain configured in DNS (e.g., `support.example.com`)
* Mailu or other SMTP server for email notifications

### Using the Makefile

The simplest way to install Chatwoot is through the AgencyStack Makefile:

```bash
# Set your domain and install
export CHATWOOT_DOMAIN=support.example.com
make chatwoot

# For multi-tenant installations with a specific client ID
export CHATWOOT_DOMAIN=support.client1.com 
export CLIENT_ID=client1
make chatwoot

# With SSO integration
export CHATWOOT_DOMAIN=support.client1.com 
export CLIENT_ID=client1
make chatwoot INSTALL_FLAGS="--enable-sso"
```

### Manual Installation

You can also install Chatwoot manually using the installation script:

```bash
# Basic installation
sudo /opt/agency_stack/scripts/components/install_chatwoot.sh --domain support.example.com

# Advanced installation with client ID and custom SMTP settings
sudo /opt/agency_stack/scripts/components/install_chatwoot.sh \
  --domain support.client1.com \
  --client-id client1 \
  --mailu-domain mail.client1.com \
  --mailu-user support@client1.com \
  --mailu-password your_secure_password \
  --enable-sso \
  --with-deps \
  --force
```

## Configuration

### Main Configuration

The main configuration for Chatwoot is stored in the environment file at:

```
/opt/agency_stack/docker/chatwoot/.env
```

You can edit this file directly or use the Makefile command:

```bash
make chatwoot-config
```

### SMTP Configuration

By default, Chatwoot is configured to use the Mailu SMTP server in the AgencyStack environment. The default SMTP settings assume:

* SMTP Server: `mail.{domain}` (where domain is derived from your Chatwoot domain)
* SMTP Port: 587
* Username: `noreply@{domain}`
* From Email: Same as username

You can customize these settings during installation with the `--mailu-domain`, `--mailu-user`, and `--mailu-password` options, or by editing the configuration file after installation.

### SSO Integration

Chatwoot can be integrated with Keycloak for single sign-on. To enable this, use the `--enable-sso` flag during installation.

After installation, you'll need to configure the Keycloak client as described in:

```
/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/config/sso/keycloak-setup-instructions.txt
```

## Management Commands

AgencyStack provides several commands to manage your Chatwoot installation:

```bash
# Check status
make chatwoot-status

# View logs
make chatwoot-logs

# Start/stop/restart service
make chatwoot-start
make chatwoot-stop
make chatwoot-restart

# Backup data
make chatwoot-backup

# Access configuration
make chatwoot-config
```

## Security & Hardening

The AgencyStack Chatwoot installation includes several security enhancements:

* **TLS Encryption**: All traffic is encrypted via Traefik's Let's Encrypt integration
* **Security Headers**: HTTP security headers to prevent XSS, clickjacking, and other attacks
* **Database Security**: PostgreSQL and Redis use randomly generated strong passwords
* **Network Isolation**: Docker networks isolate the application components
* **Minimal Permissions**: All containers run with minimal required permissions
* **Secure Cookies**: Cookies are set with secure flags and same-site restrictions
* **Privacy Controls**: IP masking is enabled for privacy compliance

## Data Location

Chatwoot data is stored in the following locations:

* **Configuration**: `/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/config/`
* **Database**: `/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/postgres/`
* **Redis**: `/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/redis/`
* **Uploads**: `/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/storage/`

## Logs

Logs are available in the following locations:

* **Installation Logs**: `/var/log/agency_stack/components/chatwoot.log`
* **Application Logs**: Available via `make chatwoot-logs`

## Ports

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Chatwoot UI | 3000 | HTTP | Accessible via Traefik |

## Initial Setup

After installation, you'll need to set up your Chatwoot instance:

1. Access your Chatwoot installation at `https://support.yourdomain.com`
2. Log in with the super admin credentials that were generated during installation
   - These credentials are saved at `/opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/config/admin-credentials.txt`
3. Change the default password immediately
4. Configure your inbox and channels
5. Add team members as needed

## Backup and Restore

### Backup

To backup your Chatwoot data:

```bash
make chatwoot-backup
```

This creates a backup of the PostgreSQL database and uploaded files in the `/opt/agency_stack/backups/chatwoot/` directory.

### Restore

Restoring from a backup requires manual steps:

1. Stop the Chatwoot service:
   ```bash
   make chatwoot-stop
   ```

2. Restore the database:
   ```bash
   cat backup_file.sql | docker exec -i chatwoot-postgres-{CLIENT_ID} psql -U chatwoot chatwoot
   ```

3. Restore uploads:
   ```bash
   tar -xzf chatwoot_storage_backup.tar.gz -C /opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data/storage/
   ```

4. Start the service:
   ```bash
   make chatwoot-start
   ```

## Uninstallation

To completely remove Chatwoot:

1. Stop and remove the containers:
   ```bash
   make chatwoot-stop
   ```

2. Remove data directories:
   ```bash
   sudo rm -rf /opt/agency_stack/clients/{CLIENT_ID}/chatwoot_data
   sudo rm -rf /opt/agency_stack/docker/chatwoot
   ```

3. Remove from installed components:
   ```bash
   sudo sed -i '/chatwoot/d' /opt/agency_stack/installed_components.txt
   ```

4. Remove Traefik configuration:
   ```bash
   sudo rm /opt/agency_stack/traefik/config/dynamic/chatwoot-{CLIENT_ID}.toml
   ```

## Monitoring

Chatwoot exposes Prometheus metrics at the `/metrics` endpoint, which are automatically scraped by the AgencyStack monitoring system. You can view these metrics in Grafana.

Health checks are configured for all containers, and a dedicated monitoring script is installed at:

```
/opt/agency_stack/monitoring/scripts/check_chatwoot-{CLIENT_ID}.sh
```

## Troubleshooting

### SMTP Connection Issues

If you're having trouble with email sending:

1. Verify your SMTP credentials in the configuration file
2. Check if the SMTP server is accessible from the Chatwoot container
3. Check Chatwoot logs for SMTP-related errors:
   ```bash
   make chatwoot-logs | grep -i smtp
   ```

### Database Connection Issues

If Chatwoot can't connect to the database:

1. Ensure the PostgreSQL container is running:
   ```bash
   docker ps | grep postgres
   ```

2. Check PostgreSQL logs:
   ```bash
   docker logs chatwoot-postgres-{CLIENT_ID}
   ```

### Redis Connection Issues

If Chatwoot can't connect to Redis:

1. Ensure the Redis container is running:
   ```bash
   docker ps | grep redis
   ```

2. Check Redis logs:
   ```bash
   docker logs chatwoot-redis-{CLIENT_ID}
   ```

### Web Interface Not Accessible

If you can't access the Chatwoot web interface:

1. Check if Traefik is properly configured:
   ```bash
   docker logs traefik | grep chatwoot
   ```

2. Verify the DNS settings for your domain
3. Check if the Chatwoot container is running:
   ```bash
   make chatwoot-status
   ```

## Integration with Other Components

### Mailu

Chatwoot is integrated with Mailu for SMTP services. This allows you to send notifications and transactional emails using your own mail server.

### Keycloak

Integration with Keycloak provides secure single sign-on (SSO) capabilities. This is enabled with the `--enable-sso` flag during installation.

### Prometheus & Grafana

Monitoring is enabled via the Prometheus integration. Metrics are available at the `/metrics` endpoint and are automatically scraped by the Prometheus instance.

### Traefik

Chatwoot is configured to work with Traefik for routing and TLS termination. This provides secure HTTPS access to your Chatwoot instance.

## FAQ

### Can I use an external SMTP server?

Yes, you can configure any SMTP server in the configuration file. During installation, specify your SMTP server details with the `--mailu-domain`, `--mailu-user`, and `--mailu-password` options.

### How do I connect WhatsApp or other channels?

After installation, log in to your Chatwoot instance and navigate to the Inbox settings. From there, you can add various channels including WhatsApp Business API, Facebook Messenger, and more.

### How do I add team members?

As an admin, navigate to the Settings > Team section in your Chatwoot dashboard. From there, you can invite new team members by email.

### Can I run multiple Chatwoot instances?

Yes, using the multi-tenant capabilities of AgencyStack, you can run separate Chatwoot instances for different clients by specifying a different `--client-id` during installation.

### How do I upgrade Chatwoot?

To upgrade to a newer version, reinstall with the `--force` flag:

```bash
make chatwoot FORCE=true
```

Or manually:

```bash
sudo /opt/agency_stack/scripts/components/install_chatwoot.sh --domain support.yourdomain.com --force
```

## Further Resources

* [Official Chatwoot Documentation](https://www.chatwoot.com/docs/)
* [Chatwoot GitHub Repository](https://github.com/chatwoot/chatwoot)
* [Chatwoot API Documentation](https://www.chatwoot.com/developers/api)
