---
layout: default
title: Client Setup - AgencyStack Documentation
---

# Client Setup Guide

AgencyStack is designed with a multi-client architecture, allowing you to create isolated environments for each of your clients while maintaining a single server infrastructure.

## Understanding Client Architecture

In AgencyStack, each client gets:
- A dedicated subdomain structure (e.g., client1.yourdomain.com)
- Isolated container instances
- Separate data volumes and backups
- Independent configuration

This architecture ensures client data remains separate while you manage everything from a central location.

## Creating a New Client

### Using the Makefile (Recommended)

The simplest way to create a new client is using the `make client` command:

```bash
cd /opt/agency_stack
make client
```

You'll be prompted to provide:
- Client domain name (e.g., client1.yourdomain.com)
- Components to enable for this client
- Additional configuration options

### Manual Client Creation

For more control, you can directly use the bootstrap script:

```bash
cd /opt/agency_stack
./scripts/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh client1.yourdomain.com
```

## Client Configuration

Each client's configuration is stored in:

```
/opt/agency_stack/clients/<client-domain>/
```

This directory contains:
- `docker-compose.yml` - Client services configuration
- `.env` - Environment variables
- Various data directories for persistent storage

### Customizing Client Components

You can customize which components are available to each client by editing their `docker-compose.yml` file. By default, the bootstrap process will include all the components you selected during the initial installation.

## Accessing Client Services

Once a client is set up, services are available at:

- WordPress: `https://cms.client1.yourdomain.com`
- ERPNext: `https://erp.client1.yourdomain.com`
- And so on for each component...

## Managing Clients

### Starting Client Services

```bash
cd /opt/agency_stack/clients/<client-domain>
docker-compose up -d
```

### Stopping Client Services

```bash
cd /opt/agency_stack/clients/<client-domain>
docker-compose down
```

### Removing a Client

```bash
cd /opt/agency_stack
./scripts/remove_client.sh <client-domain>
```

⚠️ **Warning:** This will delete all client data. Make sure to back up anything important first.

## Backing Up Client Data

```bash
cd /opt/agency_stack
./scripts/backup_client.sh <client-domain>
```

Backups are stored in `/opt/agency_stack/backups/<client-domain>/`.

## Setting Up Client Authentication

AgencyStack supports various authentication methods for client access:

### Basic Authentication

1. Generate password file:
```bash
cd /opt/agency_stack/clients/<client-domain>
htpasswd -c .htpasswd username
```

2. Update the client's Traefik configuration to use this file for basic auth.

### OAuth/SSO Integration

For advanced authentication, you can integrate with OAuth providers:

1. Obtain credentials from your OAuth provider
2. Configure the client's Traefik configuration with the appropriate middleware
3. Update the client's environment variables with the OAuth details

See the [Authentication Guide](authentication.html) for detailed instructions.
