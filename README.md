# FOSS Server Stack

A comprehensive solution for deploying a complete FOSS (Free and Open Source Software) server infrastructure using Docker containers.

## Overview

This repository contains scripts and documentation for automating the deployment of a collection of free and open source applications running in Docker containers. The stack is designed to provide businesses, agencies, and organizations with a complete suite of tools for operations, collaboration, and customer engagement.

## Features

- **One-click installation** of multiple FOSS applications
- **Docker-based** for easy deployment and maintenance
- **Secure by default** with SSL, fail2ban, and security hardening
- **Modular design** allowing selective component installation
- **Comprehensive documentation** for setup and maintenance

## Included Applications

| Category | Applications |
|----------|--------------|
| **Infrastructure** | Docker, Docker Compose, Traefik (SSL), Portainer |
| **Business Operations** | ERPNext, KillBill, Cal.com, Documenso |
| **Content Management** | WordPress, PeerTube, Seafile |
| **Team Collaboration** | Focalboard, TaskWarrior/Calcure |
| **Marketing & Analytics** | Listmonk, PostHog, WebPush |
| **Automation** | n8n, OpenIntegrationHub |
| **System & Security** | Netdata, Fail2ban, Security hardening |

## Getting Started

### Prerequisites

- A server running Ubuntu/Debian with root access
- Minimum 8GB RAM (16GB+ recommended)
- At least 50GB disk space
- Domain name(s) pointing to your server's IP

### Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/foss-server-stack.git
   cd foss-server-stack
   ```

2. Validate your environment:
   ```bash
   sudo bash scripts/validate_environment.sh
   ```

3. Start the installation:
   ```bash
   sudo bash scripts/install.sh
   ```

4. Follow the on-screen prompts to install desired components

### Documentation

Detailed documentation is available in the `docs/` directory:

- [Overview](docs/OVERVIEW.md) - Component descriptions and architecture
- [Installation Guide](docs/INSTALLATION.md) - Detailed installation instructions
- [Components](docs/COMPONENTS.md) - Information about each application
- [Configuration](docs/CONFIGURATION.md) - Configuration options and recommendations
- [Maintenance](docs/MAINTENANCE.md) - Ongoing maintenance procedures
- [Pre-Installation Checklist](docs/PRE_INSTALLATION_CHECKLIST.md) - Preparation steps
- [Future Plans (2025.04.03)](docs/FuturePlans.2025.04.03.md) - Future plans and updates

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
