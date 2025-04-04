---
layout: default
title: Installation Guide - AgencyStack Documentation
---

# Installation Guide

AgencyStack provides multiple installation methods to fit your needs and technical comfort level.

## Quick Installation (Recommended)

The simplest way to install AgencyStack is with our one-line installer:

```bash
curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

This automated installer will:
- Install all required dependencies
- Configure the system appropriately
- Set up the core infrastructure components
- Prepare your system for client deployments

## Manual Installation

For more control over the installation process, you can perform a manual installation:

### Prerequisites

- Ubuntu 20.04 LTS or newer (recommended)
- Debian-based Linux distribution
- Root access to the server
- Git, Make, Curl, Wget, JQ (will be installed if missing)

### Steps

1. **Clone the repository:**

```bash
git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency-stack
cd /opt/agency-stack
```

2. **Make scripts executable:**

```bash
chmod +x scripts/*.sh
chmod +x scripts/agency_stack_bootstrap_bundle_v10/*.sh
```

3. **Run the installation:**

```bash
make install
```

4. **Verify the installation:**

```bash
make test-env
```

## Component Selection

During installation, you'll be prompted to select which components to install. Choose from:

1. **Core Infrastructure Only**: Traefik, Portainer, basic monitoring (minimum requirement)
2. **Business Suite**: Core + ERPNext, KillBill, Cal.com, Documenso
3. **Content Suite**: Core + WordPress, PeerTube, Seafile, Builder.io 
4. **Team Suite**: Core + Focalboard, TaskWarrior/Calcure
5. **Marketing Suite**: Core + Listmonk, PostHog, WebPush
6. **Full Stack**: All of the above components
7. **Custom**: Select individual components

## Post-Installation

After installation completes:

1. Access the Portainer dashboard at `https://portainer.yourdomain.com`
2. Set up your first client with:

```bash
make client
```

3. Consider setting up the [self-healing infrastructure](self-healing.html) for production deployments

## Troubleshooting

If you encounter issues during installation:

1. Check the logs in `/var/log/agency_stack/`
2. Run the environment test: `make test-env`
3. Ensure all ports are available: 80, 443, 8080, 9000

For additional help, see our [troubleshooting guide](troubleshooting.html) or contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
