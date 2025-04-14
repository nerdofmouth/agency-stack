# Component Port Reference for AgencyStack

This document provides a comprehensive reference for ports used by AgencyStack components, which is essential for firewall configuration, network planning, and security hardening.

## Core Infrastructure Components

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| Traefik | 80, 443 | 80, 443 | TCP | Reverse proxy for all services |
| Docker | 2375/2376 | N/A | TCP | Docker API (internal only) |
| Keycloak | 8080 | 443 (via Traefik) | TCP | Identity and access management |
| Postgres | 5432 | N/A | TCP | Database for multiple services |
| Redis | 6379 | N/A | TCP | Caching and message broker |

## TLS and SSO Components

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| Dashboard | 3000 | 443 (via Traefik) | TCP | Agency Stack management dashboard |
| Keycloak Admin | 8080 | 443 (via Traefik) | TCP | Keycloak admin console |
| Let's Encrypt | N/A | 80, 443 | TCP | Certificate validation (HTTP-01 challenge) |

## Business and Productivity Tools

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| WordPress | 80 | 443 (via Traefik) | TCP | CMS platform |
| ERPNext | 8000 | 443 (via Traefik) | TCP | ERP system |
| KillBill | 8080 | 443 (via Traefik) | TCP | Billing system |
| Mailu | 25, 110, 143, 465, 587, 993, 995 | 25, 465, 587, 993 | TCP | Email server |
| Chatwoot | 3000 | 443 (via Traefik) | TCP | Customer communication |
| Cal.com | 3000 | 443 (via Traefik) | TCP | Scheduling system |

## Media and Communication

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| PeerTube | 9000, 1935 | 443 (via Traefik) | TCP | Video hosting platform |
| Jitsi | 8000, 8443, 10000 | 443, 10000 | TCP/UDP | Video conferencing |
| Mailu Webmail | 8000 | 443 (via Traefik) | TCP | Webmail interface |

## Development and DevOps

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| Gitea | 3000 | 443 (via Traefik) | TCP | Git repository |
| DroneCI | 8000 | 443 (via Traefik) | TCP | CI/CD platform |
| Portainer | 9000 | 443 (via Traefik) | TCP | Docker management |

## AI and Integration

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| PGVector | 5432 | N/A | TCP | Vector database for AI |
| n8n | 5678 | 443 (via Traefik) | TCP | Workflow automation |
| OpenIntegrationHub | 3000 | 443 (via Traefik) | TCP | Integration framework |

## Monitoring and Security

| Component | Internal Port | External Port | Protocol | Description |
|-----------|--------------|--------------|----------|-------------|
| Prometheus | 9090 | N/A | TCP | Metrics collection |
| Grafana | 3000 | 443 (via Traefik) | TCP | Metrics visualization |
| Fail2ban | N/A | N/A | N/A | Intrusion prevention |
| CrowdSec | 8080 | N/A | TCP | Collaborative security |
| Netdata | 19999 | 443 (via Traefik) | TCP | Real-time monitoring |

## Port Conflict Management

AgencyStack handles potential port conflicts through:

1. **Docker Networking**: Components are isolated in their own networks
2. **Traefik Routing**: Components with the same internal port are accessible via unique subdomains
3. **Port Remapping**: When necessary, ports are remapped to avoid conflicts

## Firewall Configuration

For standard AgencyStack installations, the following ports should be opened on your firewall:

### Essential Ports
- **80/TCP**: HTTP (redirects to HTTPS)
- **443/TCP**: HTTPS (for all web services)

### Email Ports (if using Mailu)
- **25/TCP**: SMTP (incoming mail)
- **465/TCP**: SMTPS (secure mail submission)
- **587/TCP**: Submission (mail client submission)
- **993/TCP**: IMAPS (secure mail retrieval)

### Video Conferencing (if using Jitsi)
- **10000/UDP**: WebRTC media traffic

## Validation Commands

```bash
# Check TLS configuration on ports
make tls-verify DOMAIN=yourdomain.com

# Verify all component ports are properly configured
make port-check

# Check status of SSO components
make sso-status DOMAIN=yourdomain.com
```
