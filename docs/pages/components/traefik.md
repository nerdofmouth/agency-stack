# Traefik

## Overview
Edge router and reverse proxy for AgencyStack. Traefik handles all incoming HTTP/HTTPS traffic, routing requests to the appropriate backend services based on domain names and path prefixes.

## Installation

### Prerequisites
- Docker and Docker Compose
- Network connectivity on ports 80 and 443
- **DNS Configuration**: Domain names properly configured to point to the server IP
  - Default: `<hostname>.<domain>` and `*.<hostname>.<domain>`
  - For multi-tenant setups: `<client_id>.<hostname>.<domain>`

### Installation Process
The installation is handled by the `install_traefik.sh` script, which can be executed using:

```bash
make traefik
```

For client-specific installations:
```bash
make traefik CLIENT_ID=your_client_id
```

## Configuration

### Default Configuration
- Automatic HTTP to HTTPS redirection
- Let's Encrypt SSL certificate provisioning
- Docker provider enabled (auto-discovery of containers)
- Dashboard access protected with basic authentication
- Standard network: `agency_stack` (used by all components)

### Customization
- Custom domain: `make traefik DOMAIN=your-domain.com`
- Admin email: `make traefik ADMIN_EMAIL=admin@example.com`
- Custom authentication: Modify `/opt/agency_stack/clients/<client_id>/traefik/config/dynamic/dashboard.yml`

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| HTTP    | 80   | HTTP     | Redirects to HTTPS |
| HTTPS   | 443  | HTTPS    | Secure web traffic |
| Dashboard | 443 | HTTPS   | Traefik dashboard at `traefik.<domain>` |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/traefik.log` - Installation log
- `/opt/agency_stack/clients/<client_id>/traefik/config/logs/traefik.log` - Runtime logs

### Monitoring
- Dashboard: Access via `https://traefik.<domain>/dashboard/`
- Health check: `https://<domain>/ping`

## Troubleshooting

### Common Issues

#### DNS Resolution Problems
- **Symptom**: "This site can't be reached" or "DNS address could not be found"
- **Resolution**:
  1. Verify DNS settings: `nslookup <hostname>.<domain>`
  2. For testing, add an entry to your local hosts file:
     ```
     <server_ip> <hostname>.<domain>
     ```
  3. Check connection: `curl -v https://<hostname>.<domain>/ping`

#### Network Configuration Issues
- **Symptom**: Dashboard shows 504 Gateway Timeout errors
- **Resolution**:
  1. Verify containers are on the same network: `docker network inspect agency_stack`
  2. Check traefik is using the correct network:
     ```bash
     grep -r "network:" /opt/agency_stack/clients/<client_id>/traefik/
     ```
  3. Restart traefik: `make traefik-restart`

#### Certificate Issues
- **Symptom**: SSL certificate warnings
- **Resolution**:
  1. Check ACME status: `cat /opt/agency_stack/clients/<client_id>/traefik/config/acme/acme.json`
  2. Verify domain resolution: `host <hostname>.<domain>`
  3. Check Let's Encrypt rate limits: [https://letsencrypt.org/docs/rate-limits/](https://letsencrypt.org/docs/rate-limits/)

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make traefik` | Install traefik |
| `make traefik-status` | Check status of traefik |
| `make traefik-logs` | View traefik logs |
| `make traefik-restart` | Restart traefik services |
| `make traefik-dns-check` | Verify DNS resolution for configured domains |

## Direct Access for Troubleshooting

When troubleshooting, specific components can be accessed directly via their exposed ports:
- Dashboard: `http://<server_ip>:3001`
- Other components: See `docker ps` for port mappings

This direct access method bypasses Traefik and can help isolate network/routing issues from component functionality.
