# Ports Reference

This document provides a comprehensive list of ports used by the FOSS server stack components.

## Required Ports

The following ports need to be accessible for proper operation of the stack:

| Port | Protocol | Service | Component | Usage | Required |
|------|----------|---------|-----------|-------|----------|
| 22 | TCP | SSH | System | Server access | Yes |
| 80 | TCP | HTTP | Traefik | Web traffic (redirects to HTTPS) | Yes |
| 443 | TCP | HTTPS | Traefik | Secure web traffic | Yes |
| 9443 | TCP | HTTPS | Portainer | Container management UI | Yes |

## Component-Specific Ports

These ports are used by specific components in the stack:

| Port | Protocol | Service | Component | Usage | Required |
|------|----------|---------|-----------|-------|----------|
| 3000 | TCP | HTTP | Focalboard | Project management | Internal only |
| 3001 | TCP | HTTP | n8n | Workflow automation | Internal only |
| 3306 | TCP | MySQL | ERPNext | Database | Internal only |
| 5432 | TCP | PostgreSQL | Multiple | Database for multiple services | Internal only |
| 6379 | TCP | Redis | Multiple | Caching & message broker | Internal only |
| 8000 | TCP | HTTP | ERPNext | Web interface | Internal only |
| 8080 | TCP | HTTP | Keycloak | Identity management | Internal only |
| 8090 | TCP | HTTP | ListMonk | Email campaign manager | Internal only |
| 8123 | TCP | HTTP | PostHog | Analytics dashboard | Internal only |
| 8444 | TCP | HTTPS | PeerTube | Video streaming | Internal only |
| 8800 | TCP | HTTP | OpenIntegrationHub | Integration platform | Internal only |
| 9000 | TCP | HTTP | Traefik | Dashboard | Internal only |
| 9100 | TCP | HTTP | Netdata | System monitoring | Internal only |
| 19999 | TCP | HTTP | Netdata | Web dashboard | Internal only |

## Newly Added Component Ports

Ports used by the recently added components:

| Port | Protocol | Service | Component | Usage | Required |
|------|----------|---------|-----------|-------|----------|
| 3000 | TCP | HTTP | Launchpad Dashboard | Central services portal | Internal only |
| 3001 | TCP | HTTP | Status Monitor | Uptime monitoring | Internal only |
| 3000 | TCP | HTTP | Hedgedoc | Markdown editor | Internal only |
| 3000 | TCP | HTTP | Gitea | Git server | Internal only |
| 41641 | UDP | WireGuard | Tailscale | Mesh VPN | External (if acting as exit node) |
| 8200 | TCP | HTTP | Restic REST server | Backup API | Internal only |

## Port Configuration Notes

- **Internal only**: These ports don't need to be exposed to the public internet as they are accessed through Traefik.
- **Yes** in the Required column means the port must be accessible from the public internet.
- Traefik routes traffic to the appropriate internal services based on hostnames.
- For production environments, consider restricting access to administrative interfaces (Portainer, Traefik dashboard, etc.).
- Ports can be changed in the respective docker-compose files if there are conflicts.

## Firewall Configuration

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