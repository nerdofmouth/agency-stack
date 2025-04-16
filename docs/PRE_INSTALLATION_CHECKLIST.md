# Pre-Installation Checklist

Use this checklist to ensure your environment is ready before deploying the FOSS server stack.

> **New!** You can now automatically verify your system against this checklist using:
> ```bash
> make preflight-check DOMAIN=your-domain.com
> ```
> The verification will produce a detailed report in `pre_installation_report.md` and will identify any potential issues before installation.
> 
> **Parameters:**
> - `DOMAIN=your-domain.com` - Specify your domain for DNS checks
> - `SKIP_PORTS=1` - Skip port accessibility checks
> - `SKIP_DNS=1` - Skip DNS configuration checks
> - `SKIP_SYSTEM=1` - Skip system requirements checks
> - `SKIP_NETWORK=1` - Skip network configuration checks
> - `SKIP_SSH=1` - Skip SSH security configuration checks
>
> **Example with multiple parameters:**
> ```bash
> make preflight-check DOMAIN=example.com SKIP_PORTS=1 SKIP_SSH=1
> ```

## Server Requirements

- [ ] Server with Linux OS (Ubuntu/Debian recommended)
- [ ] Minimum 8GB RAM (16GB+ recommended for full stack)
- [ ] At least 50GB free disk space (100GB+ recommended)
- [ ] Public static IP address
- [ ] Root or sudo access to the server

## Network Requirements

- [ ] Domain name configured with DNS records pointing to your server IP
- [ ] Open ports:
  - [ ] 80/443 (HTTP/HTTPS)
  - [ ] 22 (SSH)
  - [ ] 9443 (Portainer)
  - [ ] Any additional ports needed by specific services (e.g., 8080 for Portainer) 
<!-- START:ports-table -->
| Port | Protocol | Service | Component | Usage | Required |
|------|----------|---------|-----------|-------|----------|
| 22 | TCP | SSH | System | Server access | Yes |
| 80 | TCP | HTTP | Traefik | Web traffic (redirects to HTTPS) | Yes |
| 443 | TCP | HTTPS | Traefik | Secure web traffic | Yes |
| 9443 | TCP | HTTPS | Portainer | Container management UI | Yes |
| 3000 | TCP | HTTP | Focalboard/Dashboard/Hedgedoc/Gitea | Various web UIs | Internal only |
| 3001 | TCP | HTTP | n8n/Status Monitor | Workflow & monitoring | Internal only |
| 8080 | TCP | HTTP | Keycloak | Identity management | Internal only |
| 41641 | UDP | WireGuard | Tailscale | Mesh VPN | External (if exit node) |
<!-- END:ports-table -->
- [ ] Firewall allows necessary traffic
- [ ] ISP allows hosting services (not blocking ports 80/443)

## Preparation Tasks

- [ ] Perform full system update:
  ```
  apt update && apt upgrade -y
  ```
- [ ] Set system hostname:
  ```
  hostnamectl set-hostname your-server-name
  ```
- [ ] Configure timezone:
  ```
  timedatectl set-timezone your/timezone
  ```
- [ ] Create non-root user with sudo privileges (if not already done)
- [ ] Configure SSH key-based authentication
- [ ] Disable password-based SSH authentication (recommended)
- [ ] Record your server's IP address and domain information

## Service Planning

- [ ] List which components you need to install
- [ ] Prepare domain/subdomain names for each service
- [ ] Plan backup strategy
- [ ] Consider monitoring needs
- [ ] Determine resource allocation for critical services

## Data Preparation

- [ ] Prepare any data that needs to be imported
- [ ] Gather credentials for third-party services (SMTP, payment gateways, etc.)
- [ ] Create backups of any existing data if migrating

## Post-Installation Planning

- [ ] Schedule maintenance windows
- [ ] Plan user onboarding process
- [ ] Prepare documentation for end users
- [ ] Define backup verification procedures
- [ ] Outline security audit process
