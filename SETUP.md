# AgencyStack Setup Guide

This document provides step-by-step instructions for setting up AgencyStack on a new virtual machine with nothing pre-installed.

## Table of Contents
- [System Requirements](#system-requirements)
- [Prerequisites](#prerequisites)
- [Installation Process](#installation-process)
- [Post-Installation Configuration](#post-installation-configuration)
- [Client Setup](#client-setup)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## System Requirements

AgencyStack is designed to run on Linux-based systems and has been tested on:
- Ubuntu 20.04 LTS or newer
- Debian 10 or newer
- CentOS 8 or newer

Minimum hardware requirements:
- CPU: 2 cores (4+ recommended)
- RAM: 4GB (8GB+ recommended)
- Storage: 40GB (100GB+ recommended)
- Network: Reliable internet connection

## Prerequisites

### 1. Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Basic Dependencies

```bash
sudo apt install -y git make curl wget jq
```

### 3. Clone the Repository

```bash
git clone https://github.com/nerdofmouth/agency-stack.git
cd agency-stack
```

Alternatively, download a release archive and extract it:

```bash
wget https://nerdofmouth.com/downloads/agency-stack-latest.tar.gz
tar -xzf agency-stack-latest.tar.gz
cd agency-stack
```

## Installation Process

### 1. Review the Installation Options

```bash
make help
```

This will display all available make targets with their descriptions.

### 2. Test Your Environment

Before installation, verify that your system meets all requirements:

```bash
make test-env
```

Address any issues reported by the test before proceeding.

### 3. Full Installation

For a complete installation with all components:

```bash
make install
```

This will:
1. Check and install dependencies
2. Install Docker and Docker Compose
3. Set up the core infrastructure (Traefik, Portainer)
4. Install all service components
5. Configure port management

The interactive installation will prompt you for:
- Primary domain
- Email for SSL certificates
- Basic configuration options

### 4. Core Installation

If you only want the core components without optional services:

```bash
sudo ./scripts/install.sh
```

When prompted, select option 40 for core components only.

## Post-Installation Configuration

### 1. Verify Installation

Check that all services are running:

```bash
make stack-info
```

This will show:
- Installed components
- Running containers
- Port allocations

### 2. Access the Dashboard

After installation, access the dashboard at:

```
https://dashboard.yourdomain.com
```

Default credentials:
- Username: admin
- Password: (Generated during installation, found in `/opt/agency_stack/secrets/dashboard_password.txt`)

### 3. Update DNS Records

Ensure your domain's DNS records point to your server's IP address:

```
yourdomain.com            A      [Your-Server-IP]
*.yourdomain.com          A      [Your-Server-IP]
dashboard.yourdomain.com  A      [Your-Server-IP]
```

## Client Setup

AgencyStack uses a multi-tenant architecture where each client gets their own isolated environment.

### 1. Create a New Client

```bash
cd agency-stack
./scripts/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh client.yourdomain.com
```

This creates:
- Client-specific docker-compose.yml
- Environment configuration
- Required directories

### 2. Start Client Services

```bash
cd clients/client.yourdomain.com
docker-compose up -d
```

### 3. Access Client Services

After setup, client services are available at:
- ERPNext: https://client.yourdomain.com
- PeerTube: https://media.client.yourdomain.com

## Troubleshooting

### View Logs

System logs are stored in:
```bash
/var/log/agency_stack/
```

Component-specific logs can be viewed with:
```bash
docker logs [container-name]
```

### Common Issues

1. **Port Conflicts**

If you encounter port conflicts during installation:
```bash
make ports
```
This shows all allocated ports. Modify conflicting ports in the component's configuration.

2. **Certificate Issues**

If SSL certificates aren't being issued:
```bash
docker logs traefik
```
Ensure your DNS is properly configured and ports 80/443 are accessible.

3. **Performance Issues**

If you experience performance problems:
```bash
make rootofmouth
```
This displays system resource usage to help identify bottlenecks.

## Maintenance

### Updates

Keep your AgencyStack up to date:

```bash
make update
```

### Backups

Create a backup of all data:

```bash
make backup
```

Backups are stored in `/opt/agency_stack/backups/`.

### Monitoring

Monitor system health:

```bash
make stack-info
```

## Additional Resources

- Documentation: https://nerdofmouth.com/stack/docs
- Support: support@nerdofmouth.com
- GitHub: https://github.com/nerdofmouth/agency-stack

---

Created by [Nerd of Mouth](https://nerdofmouth.com) | Deploy Smart. Speak Nerd.
