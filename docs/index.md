---
layout: default
title: AgencyStack Documentation
---

<div style="text-align: center; margin-bottom: 30px;">
  <img src="/images/AgencyStackLogo.png" alt="AgencyStack Logo" style="max-width: 400px; width: 100%;">
</div>

# Digital Sovereignty for Modern Agencies

> "Run your agency. Reclaim your agency."

AgencyStack is more than just a collection of open-source software—it's a declaration of independence for digital agencies, creative professionals, and businesses who want to own their technology stack, control their data, and operate with true digital sovereignty.

## Our Vision

In a world where agencies and businesses increasingly rely on closed SaaS platforms that limit control, extract ongoing fees, and hold your data hostage, AgencyStack offers a different path. We believe that:

- **Digital sovereignty** is fundamental to business resilience and independence
- **Open source tools** can and should be as powerful and polished as proprietary alternatives
- **Agencies deserve freedom** from vendor lock-in, unpredictable pricing, and unnecessary complexity
- **Technology should serve your mission**, not complicate it or compromise it

AgencyStack empowers you to deploy a complete, integrated stack of best-in-class open source tools with a single command. Take back control, eliminate monthly SaaS fees, and build client solutions on a foundation you actually own.

<div style="text-align: center; margin: 30px 0;">
  <a href="#quick-installation" style="display: inline-block; background-color: #4CAF50; color: white; padding: 15px 25px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 18px;">⚡ Get Started</a>
  <a href="https://github.com/nerdofmouth/agency-stack" style="display: inline-block; background-color: #333; color: white; padding: 15px 25px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 18px; margin-left: 15px;">
    <img src="images/github-mark-white.svg" style="height: 20px; vertical-align: middle; margin-right: 10px;">GitHub
  </a>
</div>

## Quick Installation {#quick-installation}

Install AgencyStack on your server with our one-line installer:

```bash
curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

Or, to install all core components from a dev container:

```bash
make install-all
```

## Installation Targets

- `make install-all`: Installs all major components (WordPress, ERPNext, PostHog, VoIP, Mailu, Listmonk, KillBill)
- Individual targets: `make install-wordpress`, `make install-erpnext`, etc.

## What's Included

AgencyStack provides a complete server solution including:

- **Core Infrastructure**: Docker, Docker Compose, Traefik (reverse proxy), Portainer
- **Business Applications**: ERPNext, KillBill, Cal.com, Documenso
- **Content Management**: WordPress, PeerTube, Seafile, Builder.io
- **Team Collaboration**: Focalboard, TaskWarrior/Calcure
- **Marketing and Analytics**: Listmonk, PostHog, WebPush
- **Integration**: n8n, OpenIntegrationHub
- **System Monitoring**: Netdata, Fail2ban, DroneCI

## Documentation Sections

- [Detailed Installation Guide](pages/installation.html)
- [Components Overview](pages/components.html)
- [Client Setup](pages/client-setup.html)
- [Maintenance and Backup](pages/maintenance.html)
- [Self-Healing Setup](pages/self-healing.html)
- [Public Demo Environment](pages/demo-setup.html)
- [DroneCI Integration](pages/droneci-guide.html)
- [Troubleshooting Guide](pages/troubleshooting.html)

## Requirements

- Ubuntu 20.04 LTS or newer
- At least 4GB RAM (8GB+ recommended)
- 20GB+ free disk space
- Root access

## Support and Community

- [GitHub Issues](https://github.com/nerdofmouth/agency-stack/issues)
- [Email Support](mailto:support@nerdofmouth.com)

<div style="text-align: center; margin: 50px 0 20px 0; padding: 20px; background-color: #f8f9fa; border-radius: 5px;">
  <p>Built by <a href="https://nerdofmouth.com">
    <img src="/images/NerdOfMouthLogo.png" alt="Nerd of Mouth" style="height: 30px; vertical-align: middle;">
  </a> | Deploy Smart. Speak Nerd.</p>
</div>
## Component List (Auto-Generated from Registry)

| Name | Category | Version | Status | Docs |
|------|----------|---------|--------|------|
| Ollama | AI | 0.1.27 | Installed |  |
| Cal.com | Business Applications | 2.9.4 | Installed |  |
| Chatwoot | Business Applications | v3.5.0 | Installed |  |
| Documenso | Business Applications | 1.4.2 | Installed |  |
| ERPNext | Business Applications | 14.0.0 | Installed |  |
| KillBill | Business Applications | 0.24.0 | Installed |  |
| Etebase | Collaboration | v0.7.0 | Installed |  |
| Builder.io | Content Management | 2.0.0 | Installed |  |
| Focalboard | Content Management | 7.8.0 | Installed |  |
| Ghost | Content Management | 5.59.0 | Installed |  |
| PeerTube | Content Management | 7.0.0 | Installed |  |
| Seafile | Content Management | 10.0.1 | Installed |  |
| WordPress | Content Management | 6.4.2 | Installed |  |
| Docker | Core Infrastructure | latest | Installed |  |
| Docker Compose | Core Infrastructure | latest | Installed |  |
| DroneCI | Core Infrastructure | 2.25.0 | Installed |  |
| Portainer | Core Infrastructure | 2.17.1 | Installed |  |
| Pre-Flight Check | Core Infrastructure | 1.0.0 | Installed |  |
| System Prerequisites | Core Infrastructure | 1.0.0 | Installed |  |
| Traefik | Core Infrastructure | 2.9.8 | Installed |  |
| pgvector | Database | 0.5.1 | Not Installed |  |
| Drone CI | DevOps | 2.16.0 | Installed |  |
| Gitea | DevOps | 1.20.0 | Installed |  |
| Listmonk | Email & Communication | 4.1.0 | Installed |  |
| Mailu | Email & Communication | 1.9 | Installed |  |
| Mattermost | Email & Communication | 7.10.0 | Installed |  |
| VoIP | Email & Communication | 1.0.0 | Installed |  |
| Grafana | Monitoring & Observability | 10.1.0 | Installed |  |
| Loki | Monitoring & Observability | 2.9.0 | Installed |  |
| Prometheus | Monitoring & Observability | 2.44.0 | Installed |  |
| CrowdSec | Security & Identity | 1.5.0 | Installed |  |
| Fail2ban | Security & Identity | latest | Installed |  |
| Keycloak | Security & Identity | 22.0.1 | Installed |  |
| Security Hardening | Security & Identity | 1.0.0 | Installed |  |
| Signing & Timestamps | Security & Identity | 1.0.0 | Installed |  |
| Vault | Security & Identity | 1.14.0 | Installed |  |
| Backup Strategy | Security & Storage | 1.0.0 | Installed |  |
| Cryptosync | Security & Storage | v1.0.0 | Installed |  |
