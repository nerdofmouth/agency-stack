---
layout: default
title: Components Overview - AgencyStack Documentation
---

# Components Overview

AgencyStack consists of a carefully curated selection of open-source applications that work together to provide a complete agency infrastructure solution.

## Core Infrastructure

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **System Prerequisites** | Core system packages and configurations | N/A |
| **Traefik** | Edge router and reverse proxy, handles SSL certificates | N/A |
| **Portainer** | Container management UI | https://portainer.yourdomain.com |
| **Docker** | Container runtime | N/A |
| **DroneCI** | Continuous Integration/Deployment server | https://drone.yourdomain.com |

## Business Applications

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **ERPNext** | Enterprise Resource Planning system | https://erp.yourdomain.com |
| **KillBill** | Open-source subscription billing | https://billing.yourdomain.com |
| **Cal.com** | Scheduling and appointment application | https://cal.yourdomain.com |
| **Documenso** | Document signing platform | https://sign.yourdomain.com |

## Content Management

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **WordPress** | Content management system | https://blog.yourdomain.com |
| **Ghost** | Modern publishing platform | https://news.yourdomain.com |
| **Focalboard** | Project management board | https://board.yourdomain.com |
| **PeerTube** | Self-hosted video streaming platform | https://peertube.yourdomain.com |
| **Seafile** | File sync and share solution | https://files.yourdomain.com |
| **Builder.io** | Visual content management | https://builder.yourdomain.com |

For detailed Builder.io integration instructions, see our [Builder.io Integration Guide](/pages/builderio-integration.html).

## Team Collaboration

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Focalboard** | Project management tool | https://board.yourdomain.com |
| **TaskWarrior/Calcure** | Task and calendar management | https://tasks.yourdomain.com |

## Marketing and Analytics

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Listmonk** | Self-hosted newsletter and mailing list manager | https://mail.yourdomain.com |
| **PostHog** | Open-source product analytics | https://analytics.yourdomain.com |
| **WebPush** | Web push notification service | https://push.yourdomain.com |

## AI Tools

- [Bolt DIY](./components/bolt_diy.md) - DIY AI workflow automation platform
- [Archon](./components/archon.md) - AI agent orchestration platform

## Integration

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **n8n** | Workflow automation tool | https://n8n.yourdomain.com |
| **OpenIntegrationHub** | Integration framework | https://integration.yourdomain.com |

## System Monitoring

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Netdata** | Real-time performance monitoring | https://monitor.yourdomain.com |
| **Grafana** | Metrics visualization and monitoring platform | https://grafana.yourdomain.com |
| **Fail2ban** | Intrusion prevention framework | N/A |
| **Buddy System** | Self-healing infrastructure service | N/A |

## Security & Identity Management

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Keycloak** | Open-source identity and access management | https://auth.yourdomain.com |

### Keycloak Identity Provider

AgencyStack includes Keycloak, a comprehensive identity and access management solution:

**Features:**
- Single Sign-On (SSO) for all applications
- Identity Brokering and Social Login
- User Federation (LDAP, Active Directory)
- Two-Factor Authentication
- Fine-grained authorization
- Standard protocols support (OpenID Connect, SAML, OAuth 2.0)
- User self-service

**Default URLs:**
- Admin Console: https://auth.yourdomain.com/auth/admin
- Account Console: https://auth.yourdomain.com/auth/realms/agency/account

For detailed integration instructions with other AgencyStack components, see our [Identity Integration Guide](/pages/identity-integration.html).

### Grafana Dashboard

AgencyStack includes Grafana for advanced monitoring and visualization:

**Features:**
- Customizable dashboards
- Multiple data source integration
- Alerting and notification engine
- User-friendly query builder
- Role-based access control
- API for automation and integration

**Default URLs:**
- Dashboard: https://grafana.yourdomain.com

For detailed Grafana setup and integration information, see our [Monitoring Guide](/pages/monitoring.html).

## Security & Storage

| Component | Description | Status |
|-----------|-------------|--------|
| **[Vaultwarden](components/vaultwarden.md)** | Self-hosted password manager | ✅ |
| **[Cryptosync](components/cryptosync.md)** | Encrypted local vaults + remote cloud sync | ✅ |

## Communication

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **VoIP System** | Complete Voice over IP telephony service | https://voip.yourdomain.com |
| **Mailu** | Complete email server with webmail, SMTP, and IMAP | https://mail.yourdomain.com |

### Mailu Email Server

AgencyStack includes Mailu, a complete, Docker-based mail server solution:

**Features:**
- SMTP server for sending and receiving emails
- IMAP server for accessing emails
- Webmail interface (Roundcube) for browser-based email access
- Admin panel for managing domains, users, and aliases
- Anti-spam filtering (with RSpamd)
- Automatic DKIM, SPF, and DMARC setup
- TLS encryption with Let's Encrypt integration

**Default URLs:**
- Admin panel: https://mailu.yourdomain.com/admin
- Webmail: https://webmail.yourdomain.com
- SMTP: smtp.yourdomain.com (port 587)
- IMAP: imap.yourdomain.com (port 993)

For detailed email client setup instructions, see our [Email Client Setup Guide](/pages/email-client-setup.html).

### VoIP Details

The AgencyStack VoIP component provides a comprehensive communication solution:

**Server Components:**
- **FreePBX/Asterisk**: Open-source PBX system for call routing and management
- **WebRTC Gateway**: For browser-based calling without plugins
- **SIP Trunking**: Connect to external phone networks
- **Voicemail to Email**: Automatic email delivery of voice messages

**Client Applications:**
- **Desktop**: Supports softphones like Zoiper, MicroSIP, and Bria (Windows, macOS, Linux)
- **Mobile**: 
  - **Android**: Zoiper, Linphone, Grandstream Wave (available on Google Play)
  - **iOS**: Zoiper, Linphone, Acrobits Softphone (available on App Store)
- **Web Interface**: Browser-based calling interface with no installation required
- **Hardware Support**: Compatible with standard SIP desk phones from Yealink, Polycom, etc.

For detailed client setup instructions, see our [VOIP Client Setup Guide](/pages/voip-client-setup.html) that you can share with end-users.

**Features:**
- Call recording and monitoring
- IVR (Interactive Voice Response) menus
- Conference rooms
- Call queues and ring groups
- Detailed call reporting

All client applications are FOSS (Free and Open Source Software) or have FOSS alternatives available.

## Component Selection

During installation, you can choose which component groups to install based on your needs. The Core Infrastructure is always installed as it provides the foundation for all other components.

For production environments, we recommend starting with the Core Infrastructure and gradually adding component groups as needed.

## Component Configuration

Each component includes sensible defaults, but can be customized by editing the configuration files in:

```
/opt/agency_stack/config/<component-name>/
```

For client-specific configurations, these are located in:

```
/opt/agency_stack/clients/<client-domain>/config/
```

## Resource Requirements

| Component Group | Minimum RAM | Recommended RAM | Disk Space |
|-----------------|-------------|----------------|------------|
| Core Infrastructure | 2 GB | 4 GB | 10 GB |
| Business Suite | 4 GB | 8 GB | 20 GB |
| Content Suite | 4 GB | 8 GB | 20 GB+ |
| Team Suite | 2 GB | 4 GB | 10 GB |
| Marketing Suite | 2 GB | 4 GB | 10 GB |
| Full Stack | 8 GB | 16 GB+ | 60 GB+ |

For detailed information about each component, including setup and configuration instructions, visit their respective documentation pages.
