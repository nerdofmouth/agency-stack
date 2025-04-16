---
layout: default
title: Etebase - Encrypted CalDAV/CardDAV Server - AgencyStack Documentation
---

# Etebase

Etebase is a secure, end-to-end encrypted, self-hosted CalDAV and CardDAV server for private calendar, contact, and task synchronization.

![Etebase Logo](https://www.etebase.com/img/logo.svg)

## Overview

Etebase provides a CalDAV and CardDAV server with end-to-end encryption for your personal data synchronization needs. It allows you to securely sync your calendars, contacts, and tasks across multiple devices while maintaining privacy through strong encryption.

* **Version**: 0.7.0
* **Category**: Collaboration
* **Website**: [https://www.etebase.com](https://www.etebase.com)
* **Github**: [https://github.com/etesync/server](https://github.com/etesync/server)

## Features

* **End-to-End Encryption**: All data is encrypted before leaving your device
* **Self-Hosted**: Full control over your data
* **Standard Compliance**: Works with any CalDAV/CardDAV client
* **Multi-Tenant Support**: Separate instances for different clients with isolated storage
* **Web Interface**: Web-based admin panel for account management
* **Mobile Support**: Compatible with Android, iOS, and desktop clients
* **Offline Access**: Access your data even when offline
* **Open Source**: Transparent, auditable codebase
* **Backup/Restore**: Simple backup and restore functionality

## Architecture

Etebase in AgencyStack is deployed as a Docker container with:

* **Etebase Server**: The main application server
* **SQLite Database**: For storing encrypted data
* **Traefik Integration**: For TLS termination and routing
* **Client-Isolated Storage**: Each client gets their own isolated data storage

## Installation

### Prerequisites

* Docker and Docker Compose installed
* Domain name configured in DNS
* Traefik reverse proxy set up

### Using the Makefile

The simplest way to install Etebase is through the AgencyStack Makefile:

```bash
# Basic installation
export DOMAIN=dav.example.com
make etebase

# Multi-tenant installation with specific client ID
export DOMAIN=dav.client1.example.com
export CLIENT_ID=client1
make etebase

# Advanced installation with custom admin credentials
export DOMAIN=dav.example.com
export ADMIN_USER=adminuser
export ADMIN_EMAIL=admin@example.com
export ADMIN_PASSWORD=securepassword
make etebase
```

### Manual Installation

You can also install Etebase manually using the installation script:

```bash
sudo /opt/agency_stack/scripts/components/install_etebase.sh \
  --domain dav.example.com \
  --client-id client1 \
  --port 8732 \
  --admin-user adminuser \
  --admin-email admin@example.com \
  --with-deps
```

### Installation Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client ID for multi-tenant setup | `default` |
| `--domain` | Domain name for the Etebase server | (required) |
| `--port` | Port for the Etebase server | `8732` |
| `--admin-user` | Admin username | `admin` |
| `--admin-email` | Admin email address | `admin@domain` |
| `--admin-password` | Admin password (not recommended for production) | (randomly generated) |
| `--with-deps` | Install dependencies | `false` |
| `--force` | Force installation even if already installed | `false` |
| `--no-ssl` | Disable SSL (not recommended) | `false` |
| `--disable-monitoring` | Disable monitoring integration | `false` |

## Client Configuration

### Thunderbird

1. Install the latest version of Thunderbird
2. For Calendar:
   * Go to Calendar > New Calendar > On the Network
   * Select "CalDAV"
   * Enter the URL: `https://your-etebase-domain/dav/`
   * Enter your username and password
   * Choose a name for your calendar

3. For Contacts:
   * Go to Address Book > New > Remote Address Book
   * Enter a name for the address book
   * Enter the URL: `https://your-etebase-domain/dav/`
   * Enter your username and password

### DAVx⁵ (Android)

1. Install [DAVx⁵](https://play.google.com/store/apps/details?id=at.bitfire.davdroid) from the Google Play Store
2. Add a new account
3. Select "Login with URL and username"
4. Enter the base URL: `https://your-etebase-domain/dav/`
5. Enter your username and password
6. Select which data to sync (Calendars, Contacts, Tasks)

### iOS/macOS

1. Go to Settings > Accounts & Passwords > Add Account
2. Select "Other" at the bottom
3. Select "Add CalDAV Account" or "Add CardDAV Account"
4. Enter the server address: `https://your-etebase-domain`
5. Enter your username and password
6. Tap Next and select which data to sync

### Evolution (Linux)

1. Open Evolution
2. Go to File > New > Calendar (or Address Book)
3. Select "CalDAV" (or "CardDAV")
4. Enter the URL: `https://your-etebase-domain/dav/`
5. Enter your username and password
6. Click OK

## User Management

### Creating a New User

1. Log in to the Etebase web interface at `https://your-etebase-domain`
2. Go to the Admin panel
3. Click on "Users" in the sidebar
4. Click "Add User"
5. Fill in the required information:
   * Username
   * Email
   * Password
6. Assign appropriate permissions
7. Click "Save"

### Managing Existing Users

1. Log in to the Etebase web interface
2. Go to the Admin panel
3. Click on "Users" in the sidebar
4. Find the user you want to manage
5. Click on the user to edit their details or use the action buttons

## Multi-Tenant Usage

AgencyStack's Etebase integration fully supports multi-tenancy through client isolation:

* Each client gets a separate instance with its own:
  * Data storage
  * User database
  * Domain name
  * Encryption keys
  * Backup files

To deploy Etebase for a specific client:

```bash
export CLIENT_ID=client_name
export DOMAIN=dav.client_name.example.com
make etebase
```

The client's data will be stored in:
```
/opt/agency_stack/clients/{CLIENT_ID}/etebase/
```

## Security Considerations

Etebase provides strong security through:

1. **Data Encryption**: All calendar and contact data is encrypted
2. **TLS Encryption**: All communication is secured via HTTPS
3. **Client Isolation**: Each client's data is completely isolated
4. **Secure Credentials**: Admin credentials are stored with restricted permissions
5. **Security Headers**: HTTP security headers are configured by default
6. **Regular Backups**: Automated backup functionality

## Management Commands

AgencyStack provides several commands to manage your Etebase installation:

```bash
# Check status
make etebase-status CLIENT_ID=client1

# View logs
make etebase-logs CLIENT_ID=client1

# Start/stop/restart
make etebase-start CLIENT_ID=client1
make etebase-stop CLIENT_ID=client1
make etebase-restart CLIENT_ID=client1

# Backup data
make etebase-backup CLIENT_ID=client1

# Edit configuration
make etebase-config CLIENT_ID=client1
```

## Logs and Monitoring

Etebase logs are available in:

* Installation logs: `/var/log/agency_stack/components/etebase.log`
* Container logs: Accessible via `make etebase-logs`

The monitoring script `/opt/agency_stack/monitoring/scripts/check_etebase-{CLIENT_ID}.sh` tracks:

* Container status (running/stopped)
* Health status
* Client connections
* Last sync timestamp

This information is automatically updated in the dashboard.

## Backup and Restore

### Backup

To back up your Etebase data:

```bash
make etebase-backup CLIENT_ID=client1
```

This creates a backup in `/opt/agency_stack/backups/etebase/` containing:
* All user data
* Configuration files
* Credentials (securely stored)

### Restore

To restore from a backup:

1. Stop the Etebase service:
   ```bash
   make etebase-stop CLIENT_ID=client1
   ```

2. Run the restore script:
   ```bash
   /opt/agency_stack/clients/client1/etebase/scripts/restore.sh client1 /path/to/backup.tar.gz
   ```

3. Start the service:
   ```bash
   make etebase-start CLIENT_ID=client1
   ```

## Troubleshooting

### Connection Issues

If clients cannot connect to the server:

1. Check if the container is running:
   ```bash
   make etebase-status CLIENT_ID=client1
   ```

2. Verify the domain is properly configured in DNS
   ```bash
   nslookup your-etebase-domain
   ```

3. Check if Traefik is properly routing requests:
   ```bash
   curl -I https://your-etebase-domain
   ```

4. Check the logs for errors:
   ```bash
   make etebase-logs CLIENT_ID=client1
   ```

### Sync Problems

If calendar or contacts are not syncing:

1. Verify your client's CalDAV/CardDAV URL is correctly set to:
   ```
   https://your-etebase-domain/dav/
   ```

2. Check your username and password are correct
   
3. Try restarting the Etebase service:
   ```bash
   make etebase-restart CLIENT_ID=client1
   ```

4. Check the container logs for sync errors:
   ```bash
   make etebase-logs CLIENT_ID=client1 | grep -i sync
   ```

### Authentication Failures

If you're having trouble logging in:

1. Verify your username and password
   
2. Reset the admin password:
   ```bash
   # Edit credentials
   make etebase-config CLIENT_ID=client1
   # Restart the service
   make etebase-restart CLIENT_ID=client1
   ```

3. Check for any authentication errors in the logs:
   ```bash
   make etebase-logs CLIENT_ID=client1 | grep -i auth
   ```

## Data Location

Etebase data is stored in the following locations:

* **Config**: `/opt/agency_stack/clients/{CLIENT_ID}/etebase/config/`
* **Data**: `/opt/agency_stack/clients/{CLIENT_ID}/etebase/data/`
* **Credentials**: `/opt/agency_stack/clients/{CLIENT_ID}/etebase/config/credentials.env`
* **Backups**: `/opt/agency_stack/backups/etebase/`

## Ports

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Etebase | 8732 | HTTP | Internal port, accessed via Traefik |

## Uninstallation

To completely remove Etebase:

1. Stop and remove the containers:
   ```bash
   make etebase-stop CLIENT_ID=client1
   ```

2. Remove data directories:
   ```bash
   sudo rm -rf /opt/agency_stack/clients/client1/etebase
   sudo rm -rf /opt/agency_stack/docker/etebase
   ```

3. Remove from installed components:
   ```bash
   sudo sed -i '/etebase/d' /opt/agency_stack/installed_components.txt
   ```

4. Remove Traefik configuration:
   ```bash
   sudo rm /opt/agency_stack/traefik/config/dynamic/etebase-client1.toml
   ```

## Further Resources

* [Etebase Documentation](https://docs.etebase.com/)
* [Etebase GitHub Repository](https://github.com/etesync/server)
* [CalDAV/CardDAV Clients List](https://www.etebase.com/docs/guides/clients/)
* [DAVx⁵ Documentation](https://www.davx5.com/documentation/)
* [Thunderbird CalDAV/CardDAV Setup](https://support.mozilla.org/en-US/kb/using-multiple-calendars)
