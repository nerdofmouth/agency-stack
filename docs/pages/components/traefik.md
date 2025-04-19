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
make traefik DOMAIN=yourdomain.com ADMIN_EMAIL=admin@example.com
```

This will:
1. Check if ports 80 and 443 are available (with conflict detection)
2. Create required directories and Docker network
3. Generate configuration files for proper FQDN access
4. Set up Let's Encrypt integration
5. Start Traefik as a Docker container
6. Verify port accessibility and connectivity

### Port Configuration
The installation now automatically:
- Verifies ports 80 and 443 are available before installation
- Properly configures port bindings in docker-compose.yml
- Tests port accessibility after installation
- Provides clear diagnostics for any port-related issues

You can bypass port availability checks with:
```bash
make traefik DOMAIN=yourdomain.com ADMIN_EMAIL=admin@example.com SKIP_PORT_CHECK=true
```

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
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/` | Dynamic configuration directory |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/` | Let's Encrypt certificates |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/data/logs/` | Traefik internal logs |
| `/var/log/agency_stack/components/traefik.log` | Installation and operation logs |

## Ports & Endpoints

| Port | Protocol | Description |
|------|----------|-------------|
| 80   | HTTP     | Standard HTTP port, with automatic redirection to HTTPS |
| 443  | HTTPS    | Standard HTTPS port for secure communication |

## Troubleshooting

### Common Issues

#### Port Conflicts
If installation fails due to port conflicts:
```
[ERROR] Port 80 is not available. Use --force to continue anyway or --skip-port-check to bypass this check.
```

**Solution**: Either:
1. Stop the service using that port
2. Use the --force flag: `make traefik FORCE=true`
3. Skip the port check: `make traefik SKIP_PORT_CHECK=true`

#### DNS Resolution Issues
If your domain doesn't resolve to your server IP:

**Solution**: Ensure proper DNS configuration or temporarily add an entry to your hosts file:
```bash
echo "YOUR_SERVER_IP yourdomain.com" | sudo tee -a /etc/hosts
```

#### Certificate Issues
Let's Encrypt may fail to issue certificates if:
- Your domain doesn't resolve correctly
- Ports 80/443 aren't accessible from the internet

**Solution**: Verify DNS configuration and port accessibility before installation.

## Maintenance

### Restarting Traefik
```bash
make traefik-restart
```

### Viewing Logs
```bash
make traefik-logs
```

### Checking Status
```bash
make traefik-status
```

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/traefik.log` - Installation and operation logs
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik/data/logs/traefik.log` - Traefik internal logs
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
For comprehensive information about SSL certificate management, please see the dedicated [SSL Certificates documentation](./ssl-certificates.md).

### Hardening
- No access logs containing sensitive information
- Docker socket mounted read-only
- Non-root user in container

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make traefik` | Install traefik |
| `make traefik-status` | Check status of traefik |
| `make traefik-logs` | View traefik logs |
| `make traefik-restart` | Restart traefik |
| `make traefik-dns-check` | Verify DNS configuration |
