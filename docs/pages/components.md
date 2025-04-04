---
layout: default
title: Components Overview - AgencyStack Documentation
---

# Components Overview

AgencyStack consists of a carefully curated selection of open-source applications that work together to provide a complete agency infrastructure solution.

## Core Infrastructure

| Component | Description | Default URL |
|-----------|-------------|-------------|
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
| **WordPress** | Content management system | https://cms.yourdomain.com |
| **PeerTube** | Video hosting platform | https://video.yourdomain.com |
| **Seafile** | File sync and share solution | https://files.yourdomain.com |
| **Builder.io** | Visual content management | https://builder.yourdomain.com |

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

## Integration

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **n8n** | Workflow automation tool | https://n8n.yourdomain.com |
| **OpenIntegrationHub** | Integration framework | https://integration.yourdomain.com |

## System Monitoring

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Netdata** | Real-time performance monitoring | https://monitor.yourdomain.com |
| **Fail2ban** | Intrusion prevention framework | N/A |
| **Buddy System** | Self-healing infrastructure service | N/A |

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
