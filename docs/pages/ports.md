---
layout: default
title: Port Assignments - AgencyStack Documentation
---

# AgencyStack Port Assignments

This document provides a comprehensive list of all port assignments used by AgencyStack components. This helps with:

1. Avoiding port conflicts when deploying new components
2. Troubleshooting network connectivity issues
3. Setting up firewall rules and security groups

## Core Infrastructure

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Traefik** | Web UI | 8080 | HTTP | Admin dashboard |
| **Traefik** | HTTP | 80 | HTTP | Redirects to HTTPS |
| **Traefik** | HTTPS | 443 | HTTPS | Primary entry point |
| **Portainer** | Web UI | 9000 | HTTP | Container management |
| **Portainer** | Agent | 9001 | HTTP | Internal communication |
| **DroneCI** | Web UI | 8000 | HTTP | CI/CD interface |
| **DroneCI** | Git Hook | 8443 | HTTPS | Repository webhook |
| **Etcd** | Client | 2379 | HTTP | API endpoint |
| **Etcd** | Peer | 2380 | HTTP | Cluster communication |

## Security & Authentication

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Keycloak** | Web UI | 8080 | HTTP | Auth server |
| **Keycloak** | Admin | 8081 | HTTP | Admin console |
| **Fail2Ban** | Service | N/A | N/A | Host-level security |
| **CrowdSec** | API | 8080 | HTTP | Security API |
| **CrowdSec** | Dashboard | 3000 | HTTP | Management UI |

## Business Applications

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **ERPNext** | Web UI | 8001 | HTTP | ERP system |
| **ERPNext** | Redis | 6379 | TCP | Cache service |
| **ERPNext** | MariaDB | 3306 | TCP | Database |
| **KillBill** | Web UI | 8002 | HTTP | Billing system |
| **KillBill** | API | 8003 | HTTP | Payment API |
| **Cal.com** | Web UI | 3000 | HTTP | Scheduling |
| **Documenso** | Web UI | 3001 | HTTP | Document signing |
| **Chatwoot** | Web UI | 3002 | HTTP | Customer service platform |

## Content Management

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **WordPress** | Web UI | 8004 | HTTP | CMS |
| **WordPress** | Database | 3306 | TCP | MariaDB |
| **WordPress** | Cache | 6379 | TCP | Redis (optional) |
| **Ghost** | Web UI | 8005 | HTTP | Publishing platform |
| **PeerTube** | Web UI | 9000 | HTTP | Video platform |
| **PeerTube** | RTMP | 1935 | RTMP | Live streaming |
| **PeerTube** | Admin | 9001 | HTTP | Admin interface |
| **Seafile** | Web UI | 8006 | HTTP | File sharing |
| **Seafile** | CCNET | 10001 | TCP | Internal service |
| **Seafile** | Seafile | 12001 | TCP | Internal service |
| **Focalboard** | Web UI | 8007 | HTTP | Project management |
| **Builder.io** | Web UI | 8008 | HTTP | Visual CMS |

## Marketing & Analytics

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Listmonk** | Web UI | 9000 | HTTP | Mailing lists |
| **Listmonk** | API | 9001 | HTTP | Integration API |
| **PostHog** | Web UI | 8010 | HTTP | Analytics platform |
| **PostHog** | API | 8011 | HTTP | Data ingestion |
| **WebPush** | Service | 8012 | HTTP | Notification service |

## AI & Machine Learning

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Ollama** | API | 11434 | HTTP | LLM service |
| **LangChain** | Service | 7860 | HTTP | AI orchestration |
| **Vector DB** | Chroma | 8000 | HTTP | Vector storage |
| **Vector DB** | Qdrant | 6333 | HTTP | Vector storage (alt) |
| **Vector DB** | Weaviate | 8080 | HTTP | Vector storage (alt) |
| **AI Dashboard** | Web UI | 3030 | HTTP | Management interface |
| **Agent Orchestrator** | API | 3031 | HTTP | Agent coordination |
| **Resource Watcher** | API | 3032 | HTTP | Resource monitoring |

## Integration & Automation

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **n8n** | Web UI | 5678 | HTTP | Workflow automation |
| **n8n** | Webhook | 5679 | HTTP | External triggers |
| **OpenIntegrationHub** | API | 3000 | HTTP | Integration platform |
| **OpenIntegrationHub** | Web UI | 3001 | HTTP | Management interface |
| **CryptoSync** | Service | 8020 | HTTP | Secure sync service |

## Communication

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **VoIP** | SIP | 5060 | UDP/TCP | SIP signaling |
| **VoIP** | RTP | 10000-20000 | UDP | Voice traffic |
| **VoIP** | Web UI | 8089 | HTTP | Admin panel |
| **Mailu** | SMTP | 25 | TCP | Mail transfer |
| **Mailu** | IMAP | 143 | TCP | Mail access |
| **Mailu** | IMAPS | 993 | TCP | Secure mail access |
| **Mailu** | POP3S | 995 | TCP | Secure mail retrieval |
| **Mailu** | SMTP | 587 | TCP | Mail submission |
| **Mailu** | Admin UI | 8085 | HTTP | Management interface |
| **Mailu** | Webmail | 8086 | HTTP | Web mail client |

## Monitoring & Observability

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Prometheus** | Web UI | 9090 | HTTP | Metrics platform |
| **Prometheus** | Alertmanager | 9093 | HTTP | Alert service |
| **Grafana** | Web UI | 3000 | HTTP | Dashboard platform |
| **Loki** | API | 3100 | HTTP | Log aggregation |
| **Netdata** | Web UI | 19999 | HTTP | Real-time monitoring |

## Port Assignment Policy

When adding new components to your AgencyStack installation, follow these guidelines:

1. **Use standard ports** where possible (e.g., 80/443 for HTTP/HTTPS)
2. **Avoid conflicts** by checking this reference before assigning new ports
3. **Group related services** in similar port ranges for better organization
4. **Consider security**: Avoid exposing administrative ports directly; use Traefik for proxy access

## Reserved Port Ranges

- **80, 443**: Reserved for Traefik HTTP/HTTPS
- **1-1024**: Privileged ports, avoid using directly
- **10000-20000**: Reserved for RTP media (VoIP)
- **3000-3999**: Common web application UI ports
- **8000-8999**: Common API and service ports
- **9000-9999**: Common monitoring and admin ports

## Changing Default Ports

To change the default port for a component, edit its configuration file in:

```
/opt/agency_stack/config/<component-name>/
```

After changing ports, restart the component with:

```
make <component>-restart
```

And update Traefik routing if necessary.
