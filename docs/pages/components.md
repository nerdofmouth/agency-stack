---
layout: default
title: Components Overview - AgencyStack Documentation
---

# Components Overview

AgencyStack consists of a carefully curated selection of open-source applications that work together to provide a complete agency infrastructure solution. This page provides an overview of all available components, organized by category.

## Core Infrastructure

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Traefik** | Edge router and reverse proxy, handles SSL certificates | N/A | ✅ Ready |
| **Portainer** | Container management UI | https://portainer.yourdomain.com | ✅ Ready |
| **Docker** | Container runtime | N/A | ✅ Ready |
| **DroneCI** | Continuous Integration/Deployment server | https://drone.yourdomain.com | ✅ Ready |
| **Etcd** | Distributed key-value store | N/A | ✅ Ready |

## Security & Authentication

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Keycloak** | Identity and access management | https://auth.yourdomain.com | ✅ Ready |
| **Fail2Ban** | Intrusion prevention system | N/A | ✅ Ready |
| **CrowdSec** | Collaborative security | N/A | ✅ Ready |
| **Traefik SSL** | SSL/TLS certificate management for Traefik | N/A | ✅ Ready |
| **Multi-Tenancy** | Client isolation and multi-tenant infrastructure | N/A | ✅ Ready |
| **Signing Timestamps** | Secure document timestamping | N/A | 🔄 In Progress |

## Monitoring & Observability

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Prometheus** | Metrics collection and alerting | https://prometheus.yourdomain.com | ✅ Ready |
| **Grafana** | Metrics visualization and dashboards | https://grafana.yourdomain.com | ✅ Ready |
| **Loki** | Log aggregation system | N/A | ✅ Ready |
| **Netdata** | Real-time performance monitoring | https://netdata.yourdomain.com | 🔄 In Progress |

## Business Applications

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **ERPNext** | Enterprise Resource Planning system | https://erp.yourdomain.com | ✅ Ready |
| **KillBill** | Open-source subscription billing | https://billing.yourdomain.com | ✅ Ready |
| **Cal.com** | Scheduling and appointment application | https://cal.yourdomain.com | ✅ Ready |
| **Documenso** | Document signing platform | https://sign.yourdomain.com | ✅ Ready |

## Content Management

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **WordPress** | Content management system | https://blog.yourdomain.com | ✅ Ready |
| **Ghost** | Modern publishing platform | https://news.yourdomain.com | ✅ Ready |
| **Focalboard** | Project management board | https://board.yourdomain.com | ✅ Ready |
| **PeerTube** | Self-hosted video streaming platform | https://video.yourdomain.com | ✅ Ready |
| **Seafile** | File sync and share solution | https://files.yourdomain.com | ✅ Ready |
| **Builder.io** | Visual content management | https://builder.yourdomain.com | ✅ Ready |

## Team Collaboration

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Focalboard** | Project management tool | https://board.yourdomain.com | ✅ Ready |
| **TaskWarrior & Calcurse** | Task and calendar management | http://taskwarrior.yourdomain.com | ✅ Ready |
| **Chatwoot** | Customer messaging platform | https://chat.yourdomain.com | ✅ Ready |
| **CryptoSync** | Secure file synchronization | N/A | ✅ Ready |

## Marketing and Analytics

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Listmonk** | Newsletter and mailing list manager | https://mail.yourdomain.com | ✅ Ready |
| **PostHog** | Product analytics platform | https://analytics.yourdomain.com | 🔄 In Progress |
| **WebPush** | Web push notification service | N/A | 🔄 In Progress |

## AI & Machine Learning

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Ollama** | Local LLM server | N/A | ✅ Ready |
| **LangChain** | AI framework and orchestration | N/A | ✅ Ready |
| **Vector DB** | Vector database for embeddings | N/A | ✅ Ready |
| **AI Dashboard** | AI management interface | https://ai.yourdomain.com | ✅ Ready |
| **Agent Orchestrator** | AI agent management | N/A | ✅ Ready |
| **Resource Watcher** | Resource monitoring for AI | N/A | ✅ Ready |

## Integration & Automation

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **n8n** | Workflow automation platform | https://n8n.yourdomain.com | ✅ Ready |
| **OpenIntegrationHub** | Data integration platform | https://integration.yourdomain.com | 🔄 In Progress |

## Communication

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **VoIP System** | Complete Voice over IP telephony service | https://voip.yourdomain.com | ✅ Ready |
| **Mailu** | Complete email server with webmail, SMTP, and IMAP | https://mail.yourdomain.com | ✅ Ready |

## Utility & Infrastructure

| Component | Description | Default URL | Alpha Status |
|-----------|-------------|-------------|-------------|
| **Multi-Tenancy** | Client isolation and management | N/A | ✅ Ready |
| **Backup Strategy** | System backup and recovery | N/A | 🔄 In Progress |
| **Launchpad Dashboard** | System dashboard and launcher | https://dashboard.yourdomain.com | ✅ Ready |
| **Tailscale** | Secure network connectivity | N/A | 🔄 In Progress |

## Component Documentation

Each component has its own dedicated documentation page that includes:

- Installation instructions
- Configuration options
- Security considerations
- Monitoring and logging
- Troubleshooting tips

Use the links in the tables above to access the detailed documentation for each component.

## Installation Commands

Most components can be installed using a simple make command:

```bash
# Install a component
make <component>

# Check component status
make <component>-status

# View component logs
make <component>-logs

# Restart a component
make <component>-restart
```

Replace `<component>` with the component name (e.g., `peertube`, `prometheus`, `wordpress`).

## Component Integration

AgencyStack components are designed to work together seamlessly. Common integrations include:

1. **Single Sign-On**: Most components integrate with Keycloak for unified authentication
2. **Monitoring**: All components expose metrics for Prometheus and logs for Loki
3. **Reverse Proxy**: All web-based components are accessible through Traefik
4. **Multi-tenancy**: Components support client isolation where applicable
