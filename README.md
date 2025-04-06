# AgencyStack

<div align="center">
  <img src="images/AgencyStack-logo.png" alt="AgencyStack Logo" width="400">
  <p><strong>Digital Sovereignty for Modern Agencies</strong></p>
  <p><em>Run your agency. Reclaim your agency.</em></p>
</div>

A declaration of independence for digital agencies, creative professionals, and businesses who want to own their technology stack, control their data, and operate with true digital sovereignty. Built by [Nerd of Mouth](https://stack.nerdofmouth.com).

## One-Line Installation

For fresh installations, use our one-line installer:

```bash
curl -fsSL https://raw.githubusercontent.com/nerdofmouth/agency-stack/main/scripts/install.sh | sudo bash
```

This installer automatically handles first-run dependencies, creates required directories, and prepares your system for AgencyStack component installation. For detailed installation instructions, see [One-Line Installation Guide](docs/pages/one_line_install.md).

## Vision

In a world where agencies and businesses increasingly rely on closed SaaS platforms that limit control, extract ongoing fees, and hold your data hostage, AgencyStack offers a different path. We believe that:

- **Digital sovereignty** is fundamental to business resilience and independence
- **Open source tools** can and should be as powerful and polished as proprietary alternatives
- **Agencies deserve freedom** from vendor lock-in, unpredictable pricing, and unnecessary complexity
- **Technology should serve your mission**, not complicate it or compromise it

## Features

AgencyStack provides:
- **One-click installation** of multiple FOSS applications
- **Docker-based** for easy deployment and maintenance
- **Secure by default** with SSL, fail2ban, and security hardening
- **Multi-client architecture** for agency/client isolation
- **Self-healing infrastructure** with buddy system monitoring
- **DroneCI integration** for automated testing and deployment
- **Comprehensive documentation** for setup and maintenance
- **Beautiful branding** with custom taglines and ASCII art
- **One-line installation** for quick deployment

### Core Components
- **Traefik**: Reverse proxy with automatic HTTPS
- **Docker**: Container orchestration
- **Portainer**: Container management UI
- **MinIO**: S3-compatible object storage
- **Netmaker**: VPN and network management
- **Mailu**: Complete mail server solution
- **Databases**: MySQL, PostgreSQL, MongoDB
- **Keycloak**: Identity and access management
- **WordPress**: Content management system
- **ERPNext**: Business management platform (ERP/CRM)

### Operations Features
- **Monitoring**: Grafana and Loki for logs + metrics
- **Auto-alerting**: Email, Telegram, and webhook notifications
- **Backup Tools**: Automated Restic verification
- **Configuration Management**: Git-based version control
- **Operations Dashboard**: System audit and health monitoring
- **Single Sign-On**: Keycloak integration across components

## Components

AgencyStack includes:

### Core Infrastructure
- **Traefik**: Edge router and reverse proxy
- **Portainer**: Container management UI
- **Docker & Docker Compose**: Container runtime
- **DroneCI**: Continuous Integration server

### Business Applications
- **ERPNext**: Enterprise Resource Planning
- **KillBill**: Subscription billing
- **Cal.com**: Scheduling and appointments
- **Documenso**: Document signing

### Content Management
- **WordPress**: Content management system
- **PeerTube**: Video hosting platform
- **Seafile**: File sync and share solution
- **Builder.io**: Visual content management

### Team Collaboration
- **Focalboard**: Project management
- **TaskWarrior/Calcure**: Task and calendar management

### Marketing and Analytics
- **Listmonk**: Newsletter and mailing list manager
- **PostHog**: Product analytics
- **WebPush**: Web push notifications

### Integration
- **n8n**: Workflow automation
- **OpenIntegrationHub**: Integration framework

### System Monitoring
- **Netdata**: Performance monitoring
- **Fail2ban**: Intrusion prevention
- **Buddy System**: Self-healing infrastructure

## Getting Started

Visit our documentation at [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com) for comprehensive installation guides and configuration options.

### Quick Start

```bash
# One-line installer (recommended)
curl -fsSL https://raw.githubusercontent.com/nerdofmouth/agency-stack/main/scripts/install.sh | sudo bash

# OR clone and install manually
git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency-stack
cd /opt/agency-stack
make install
```

## Documentation

- [Installation Guide](https://stack.nerdofmouth.com/pages/installation.html)
- [Components Overview](https://stack.nerdofmouth.com/pages/components.html)
- [Client Setup](https://stack.nerdofmouth.com/pages/client-setup.html)
- [Maintenance and Backup](https://stack.nerdofmouth.com/pages/maintenance.html)
- [Self-Healing Setup](https://stack.nerdofmouth.com/pages/self-healing.html)
- [Public Demo Environment](https://stack.nerdofmouth.com/pages/demo-setup.html)
- [Troubleshooting](https://stack.nerdofmouth.com/pages/troubleshooting.html)

## Support

For support, contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com) or visit [stack.nerdofmouth.com](https://stack.nerdofmouth.com).

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

<div align="center">
  <img src="docs/images/NerdofMouth-logo.png" alt="Nerd of Mouth" height="30">
  <p><strong>Built by Nerd of Mouth</strong> | Deploy Smart. Speak Nerd.</p>
</div>
