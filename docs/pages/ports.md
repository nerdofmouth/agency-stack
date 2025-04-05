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

## Content Management

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **WordPress** | Web UI | 8010 | HTTP | CMS |
| **Ghost** | Web UI | 2368 | HTTP | Publishing platform |
| **Focalboard** | Web UI | 8011 | HTTP | Project management |
| **PeerTube** | Web UI | 9000 | HTTP | Video platform |
| **PeerTube** | Admin UI | 9001 | HTTP | Administration |
| **PeerTube** | RTMP | 1935 | RTMP | Live streaming |
| **Seafile** | Web UI | 8012 | HTTP | File sharing |
| **Builder.io** | Web UI | 8013 | HTTP | Visual CMS |

## Security & Identity

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Keycloak** | Web UI | 8080 | HTTP | SSO and IAM |
| **Vault** | Web UI | 8200 | HTTP | Secret management |
| **Crowdsec** | API | 8080 | HTTP | Security automation |
| **OWASP ZAP** | UI | 8090 | HTTP | Security scanning |

## Email & Communication

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Mailu** | SMTP | 25 | TCP | Mail transfer |
| **Mailu** | IMAP | 143 | TCP | Mail access |
| **Mailu** | IMAPS | 993 | TCP | Secure mail access |
| **Mailu** | Web UI | 8020 | HTTP | Administration |
| **Mattermost** | Web UI | 8065 | HTTP | Team chat |
| **Element** | Web UI | 8021 | HTTP | Matrix client |
| **VoIP** | SIP | 5060 | UDP/TCP | SIP signaling |
| **VoIP** | SIP TLS | 5061 | TCP | Encrypted SIP |
| **VoIP** | RTP | 16384-32768 | UDP | Voice/video media |
| **VoIP** | Web UI | 8082 | HTTP | FusionPBX UI |
| **VoIP** | Admin UI | 8445 | HTTPS | FusionPBX Admin |
| **Listmonk** | Web UI | 9000 | HTTP | Newsletter & list management |

## Monitoring & Observability

| Component | Service | Port | Protocol | Notes |
|-----------|---------|------|----------|-------|
| **Prometheus** | Web UI | 9090 | HTTP | Metrics collection |
| **Prometheus** | Alertmanager | 9093 | HTTP | Alert handling |
| **Prometheus** | Node Exporter | 9100 | HTTP | System metrics |
| **Prometheus** | Pushgateway | 9091 | HTTP | Batch job metrics |
| **Grafana** | Web UI | 3000 | HTTP | Visualization |
| **Loki** | API | 3100 | HTTP | Log aggregation |
| **Node Exporter** | Metrics | 9100 | HTTP | System metrics |
| **cAdvisor** | Metrics | 8082 | HTTP | Container metrics |

## Port Assignment Guidelines

When adding new components to AgencyStack, please follow these guidelines:

1. **Check for conflicts**: Always verify that your chosen ports don't conflict with existing components
2. **Use logical groupings**: Try to keep related services in similar port ranges
3. **Document everything**: Always update this document when adding new port assignments
4. **Consider security**: Avoid exposing administrative ports directly; use Traefik for proxy access

## Reserved Port Ranges

- **80, 443**: Reserved for Traefik HTTP/HTTPS
- **1-1024**: System reserved ports, avoid unless specifically required (e.g., mail ports)
- **2000-3000**: Reserved for development and testing
- **8000-8999**: General web services
- **9000-9999**: Administrative interfaces and metrics endpoints
