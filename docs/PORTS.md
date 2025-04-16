# 📡 Ports Reference

This document provides a comprehensive list of ports used by the FOSS server stack components.

## 🌐 Required Ports

The following ports need to be accessible from the internet for proper operation of the stack:

| Port | Protocol | Service | Usage | Required |
|------|----------|---------|-------|----------|
| 22 | TCP | SSH | Server access | Yes |
| 80 | TCP | HTTP | Web traffic (redirects to HTTPS) | Yes |
| 443 | TCP | HTTPS | Secure web traffic | Yes |
| 9443 | TCP | HTTPS | Portainer Container UI | Yes |
| 41641 | UDP | WireGuard/Tailscale | Mesh VPN | Optional (if exit node) |

## 🧩 Service Port Reference

This table outlines all service ports in the FOSS server stack. All web-exposed ports are proxied via Traefik unless otherwise noted.

| Service | Port(s) | Notes |
|---------|---------|-------|
| **Traefik** | 80, 443 | HTTP/S reverse proxy, handles TLS termination |
| **Portainer** | 9443 | Docker UI — Secure web access |
| **ERPNext** | 8000 (internal), 8080 (proxied) | ERP/CRM system with web interface |
| **Kill Bill** | 8081 (proxied) | Subscription billing API & admin |
| **Cal.com** | 3000 (proxied) | Scheduling UI |
| **Seafile** | 8000, 8082 (proxied) | Web UI + file transfer backend |
| **Listmonk** | 9000 (proxied) | Email marketing dashboard |
| **PostHog** | 8001 (proxied) | Product analytics suite |
| **Documenso** | 5000 (proxied) | Document e-signature UI |
| **PeerTube** | 9001 (proxied), 8444 (internal) | Video publishing platform |
| **FocalBoard** | 8005 (proxied) | Project mgmt, kanban-style UI |
| **n8n** | 5678 (proxied) | Workflow automation visual editor |
| **Vaultwarden** | 8222 (proxied) | Self-hosted Bitwarden backend |
| **Netdata** | 19999 | System monitoring (internal or reverse proxy) |
| **Uptime Kuma** | 3001 (proxied) | Service uptime monitoring UI |
| **Grafana** | 3002 (proxied) | Dashboards & metrics |
| **Prometheus** | 9090 | Metrics collector (internal only) |
| **Loki** | 3100 | Log aggregation (internal only) |
| **Sentry** | 9002 (proxied) | App monitoring / error tracking |
| **Keycloak** | 8085 (proxied) | Identity and access management |
| **OpenIntegrationHub** | 8003 (proxied) | Integration layer for apps and data |
| **Mailu Webmail** | 8025 (proxied) | Roundcube or webmail interface |
| **SMTP/IMAP** | 25, 587 / 143, 993 | Standard email delivery + retrieval |
| **FusionPBX** | 8004 (proxied) | VOIP/telephony admin interface |
| **FreeSWITCH** | 5060-5061/UDP | SIP/VOIP signaling — internal only |
| **Builder.io** | (cloud-hosted) | API only — no exposed port |
| **Launchpad Dashboard** | 1337 (proxied) | Central services portal |
| **Hedgedoc** | 3010 (proxied) | Markdown editor |
| **Gitea** | 3020 (proxied) | Git server |
| **Restic REST server** | 8200 (internal) | Backup API |

## 💾 Database & Cache Ports

| Service | Port | Notes |
|---------|------|-------|
| **MySQL/MariaDB** | 3306 | Database for ERPNext and other services |
| **PostgreSQL** | 5432 | Database for multiple services |
| **Redis** | 6379 | Caching & message broker |

## 🔒 Port Configuration Notes

- **Internal only**: These ports don't need to be exposed to the public internet as they are accessed through Traefik.
- **Yes** in the Required column means the port must be accessible from the public internet.
- Traefik routes traffic to the appropriate internal services based on hostnames.
- For production environments, consider restricting access to administrative interfaces (Portainer, Traefik dashboard, etc.).
- Ports can be changed in the respective docker-compose files if there are conflicts.
- All proxied services are routed via Traefik and use HTTPS.
- Access control is handled through Keycloak, Tailscale, or internal firewalls.

## 🔥 Firewall Configuration

For **Ubuntu/Debian** with UFW:

```bash
# Allow SSH
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Portainer
ufw allow 9443/tcp

# Optional: Allow Tailscale
ufw allow 41641/udp

# Enable the firewall
ufw enable
```

For **CentOS/RHEL** with firewalld:

```bash
# Allow SSH
firewall-cmd --permanent --add-port=22/tcp

# Allow HTTP/HTTPS
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp

# Allow Portainer
firewall-cmd --permanent --add-port=9443/tcp

# Optional: Allow Tailscale
firewall-cmd --permanent --add-port=41641/udp

# Reload firewall
firewall-cmd --reload
```

