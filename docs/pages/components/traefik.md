# Traefik

## Overview
Traefik is a modern HTTP reverse proxy and load balancer for microservices. It integrates with existing infrastructure components and configures itself automatically and dynamically. Within AgencyStack, Traefik serves as the central entry point for all web traffic, providing TLS termination, automatic SSL certificate management, and routing of requests to the appropriate services.

## Installation

### Prerequisites
- Docker and Docker Compose must be installed
- Port 80 and 443 must be available and not blocked by firewalls
- Domain name must be properly configured with DNS pointing to the server

### Installation Process
The installation is handled by the `install_traefik.sh` script, which can be executed using:

```bash
make traefik
```

This will:
1. Create required directories and network
2. Generate configuration files
3. Set up Let's Encrypt integration
4. Start Traefik as a Docker container

## Configuration

### Default Configuration
Traefik is configured with the following defaults:
- Automatic HTTP to HTTPS redirection
- Let's Encrypt certificate generation
- Docker provider for automatic service discovery
- Dashboard protected with basic authentication (username: admin, default password)
- Network isolation using the agency_stack Docker network

### Customization
Configuration can be customized by editing:
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/traefik.yml` - Main configuration
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/` - Dynamic configuration files

## Paths & Directories

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/` | Main installation directory |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/` | Configuration files |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/acme/` | Let's Encrypt certificates |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/logs/` | Traefik internal logs |
| `/var/log/agency_stack/components/traefik.log` | Installation and operation logs |

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| HTTP    | 80   | HTTP     | Automatically redirects to HTTPS |
| HTTPS   | 443  | HTTPS    | Main entry point for secure web traffic |
| Dashboard | 8080 | HTTPS  | Admin dashboard (accessible only via traefik.${DOMAIN}) |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/traefik.log` - Installation and operation logs
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/logs/traefik.log` - Traefik internal logs
- System logs can be viewed with: `journalctl -u traefik` or `docker logs traefik_${CLIENT_ID}`

### Monitoring
- Access the dashboard at `https://traefik.${DOMAIN}` for real-time metrics
- Health check endpoint: `https://traefik.${DOMAIN}/ping`
- Prometheus metrics available at `https://traefik.${DOMAIN}/metrics`

## Security

### Authentication
- Dashboard is protected with basic authentication
- Default credentials: username `admin`, password configured during installation

### TLS/SSL
- Automatic certificate management via Let's Encrypt
- Modern TLS protocols and ciphers configured
- HSTS enabled for improved security

### Hardening
- No access logs containing sensitive information
- Docker socket mounted read-only
- Non-root user in container

## Troubleshooting

### Common Issues
- **Certificate generation fails**: Ensure ports 80/443 are accessible from the internet for Let's Encrypt verification
- **Services not appearing**: Check if services have the correct Traefik labels
- **Dashboard inaccessible**: Verify DNS configuration for traefik.${DOMAIN}

### Recovery
If Traefik fails, you can restart it with:
```bash
make traefik-restart
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make traefik` | Install traefik |
| `make traefik-status` | Check status of traefik |
| `make traefik-logs` | View traefik logs |
| `make traefik-restart` | Restart traefik |
| `make traefik-dns-check` | Verify DNS configuration |
