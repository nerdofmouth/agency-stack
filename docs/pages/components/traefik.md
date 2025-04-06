---
layout: default
title: Traefik - AgencyStack Documentation
---

# Traefik

## Overview

Traefik serves as the edge router and reverse proxy for AgencyStack, handling all incoming HTTP/HTTPS traffic, automatic SSL certificate management, and intelligent routing to services. It provides the entry point to your sovereign infrastructure with zero trust security principles built in.

## Features

- **Automatic HTTPS**: SSL/TLS termination with Let's Encrypt integration
- **Dynamic Configuration**: Auto-discover and route to Docker containers
- **Circuit Breaking**: Protect services from cascading failures
- **Rate Limiting**: Prevent abuse and DDoS attacks
- **Metrics Exposure**: Prometheus metrics for monitoring
- **Access Logs**: Detailed logging for security auditing
- **Middleware Support**: Headers manipulation, authentication, compression
- **API & Dashboard**: Web UI for configuration and monitoring
- **Multi-tenant Routing**: Client-specific routing rules

## Prerequisites

- Docker and Docker Compose
- DNS control for your domains
- Open ports 80 and 443 on your firewall

## Installation

Install Traefik using the Makefile:

```bash
make traefik
```

Options:

- `--domain=<domain>`: Primary domain for installation
- `--admin-email=<email>`: Email for Let's Encrypt registration
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-ssl`: Enable automatic SSL/TLS with Let's Encrypt
- `--force`: Override existing installation

## Configuration

Traefik configuration is stored in:

```
/opt/agency_stack/traefik/config/
```

Main configuration files:

- `traefik.yml`: Static configuration
- `dynamic.yml`: Dynamic configuration
- `acme.json`: Let's Encrypt certificates (secured)

Client-specific routes are stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/traefik/rules/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TRAEFIK_DASHBOARD_USERS` | Dashboard auth credentials | Auto-generated |
| `TRAEFIK_LOG_LEVEL` | Log level (DEBUG, INFO, WARNING, ERROR) | `INFO` |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt | From `--admin-email` |
| `TRAEFIK_ENTRYPOINTS_WEB_PORT` | HTTP port | `80` |
| `TRAEFIK_ENTRYPOINTS_WEBSECURE_PORT` | HTTPS port | `443` |
| `TRAEFIK_API_DASHBOARD` | Enable dashboard | `true` |
| `TRAEFIK_PROVIDERS_DOCKER` | Enable Docker provider | `true` |
| `TRAEFIK_PROVIDERS_FILE_DIRECTORY` | Dynamic config directory | `/etc/traefik/dynamic` |

## Usage

### Management Commands

```bash
# Check status
make traefik-status

# View logs
make traefik-logs

# Restart service
make traefik-restart

# Apply SSL configuration
make traefik-ssl
```

### Dashboard Access

The Traefik dashboard is accessible at:

```
https://traefik.yourdomain.com/dashboard/
```

Authentication credentials are in:

```
/opt/agency_stack/traefik/config/users.txt
```

### Adding a New Route

Routes are automatically created for components installed via the Makefile. For manual configuration:

1. Create a YAML file in `/opt/agency_stack/clients/${CLIENT_ID}/traefik/rules/`
2. Define the router, middleware, and service
3. Restart Traefik or wait for auto-reload

Example route configuration:

```yaml
http:
  routers:
    my-service:
      rule: "Host(`service.yourdomain.com`)"
      service: "my-service"
      entryPoints:
        - "websecure"
      tls:
        certResolver: "default"
      middlewares:
        - "secure-headers"
  
  services:
    my-service:
      loadBalancer:
        servers:
          - url: "http://my-service:8080/"
```

## Security

Traefik is configured with the following security measures:

- TLS 1.2+ with modern cipher suites
- HTTP-to-HTTPS redirection
- Strict Transport Security (HSTS)
- Security headers (XSS Protection, Frame Options, etc.)
- Access control for the dashboard and API
- Rate limiting for exposed endpoints

## Monitoring

All Traefik operations are logged to:

```
/var/log/agency_stack/components/traefik.log
```

Access logs are stored in:

```
/var/log/agency_stack/components/traefik_access.log
```

Metrics are exposed on `/metrics` for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Certificate generation failures**:
   - Verify domain DNS is properly configured
   - Check that ports 80/443 are accessible from the internet
   - Verify Let's Encrypt registration email is valid

2. **Routing issues**:
   - Check container labels for traefik configuration
   - Verify service is running and accessible
   - Check rule syntax in configuration files

3. **Dashboard access problems**:
   - Verify credentials in users.txt
   - Check dashboard endpoint is enabled
   - Ensure the dashboard host is defined in DNS

### Logs

For detailed logs:

```bash
# Main logs
tail -f /var/log/agency_stack/components/traefik.log

# Access logs (useful for debugging routing)
tail -f /var/log/agency_stack/components/traefik_access.log
```

## Integration with Other Components

Traefik is the gateway for all AgencyStack components:

1. **Web Applications**: WordPress, Ghost, PeerTube, etc.
2. **Business Tools**: ERPNext, KillBill, etc.
3. **Infrastructure**: Portainer, Grafana
4. **Security**: Keycloak for authentication

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/traefik/config/traefik.yml
```

Custom middleware can be defined in:

```
/opt/agency_stack/traefik/config/dynamic/middlewares.yml
```

## TLS Configuration

By default, AgencyStack configures Traefik with:

- Let's Encrypt for automatic certificate management
- Modern TLS configuration (TLS 1.2+)
- Secure cipher suites
- HTTP-to-HTTPS redirection
- HSTS preloading support

To modify TLS settings, edit:

```
/opt/agency_stack/traefik/config/dynamic/tls.yml
```

## Multi-tenancy Support

In multi-tenant environments, each client gets:

1. **Dedicated Host Rules**: Client-specific domain routing
2. **Isolated Configurations**: Separate rule files
3. **Custom Middlewares**: Client-specific security policies
4. **Access Controls**: Limited visibility to client-specific endpoints
