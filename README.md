# AgencyStack

**Run your agency. Reclaim your agency.**

A comprehensive solution for deploying a complete FOSS (Free and Open Source Software) server infrastructure using Docker containers. Built by [Nerd of Mouth](https://nerdofmouth.com/stack).

## Overview

AgencyStack contains scripts and documentation for automating the deployment of a collection of free and open source applications running in Docker containers. The stack is designed to provide agencies, businesses, and independent creators with a complete suite of tools for operations, collaboration, and customer engagement.

## Philosophy

> "Tools for freedom, proof of power."

AgencyStack stands for sovereignty and freedom. It's built on the principles that:
- Technology should empower, not constrain
- Digital infrastructure should promote independence
- The tools you use should align with your values

## Features

- **One-click installation** of multiple FOSS applications
- **Docker-based** for easy deployment and maintenance
- **Secure by default** with SSL, fail2ban, and security hardening
- **Modular design** allowing selective component installation
- **Multi-tenant architecture** for serving multiple clients
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

For detailed installation instructions, see [SETUP.md](SETUP.md).

### Quick Start

1. **Clone the repository:**
```bash
git clone https://github.com/nerdofmouth/agency-stack.git
cd agency-stack
```

2. **View available commands:**
```bash
make help
```

3. **Install AgencyStack:**
```bash
make install
```

4. **Create a client:**
```bash
./scripts/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh client.yourdomain.com
```

## Documentation

- [SETUP.md](SETUP.md) - Comprehensive installation guide
- [BRANDING.md](BRANDING.md) - AgencyStack branding guidelines
- [docs/](docs/) - Detailed documentation for each component

## Architecture

AgencyStack uses a multi-tenant architecture:

1. **Core Infrastructure** - Installed once on the server
2. **Client Environments** - Each client gets their own isolated environment
3. **Shared Services** - Central dashboard for management

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

For support, contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com) or visit [nerdofmouth.com/stack](https://nerdofmouth.com/stack).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with 🧠 by [Nerd of Mouth](https://nerdofmouth.com) | Deploy Smart. Speak Nerd.
