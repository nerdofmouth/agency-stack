# Traefik-Keycloak Integration

This component provides a secure integration between Traefik and Keycloak for dashboard authentication.

## Overview

The Traefik-Keycloak integration provides:
- A Traefik reverse proxy for service routing and load balancing
- Keycloak as the identity provider for SSO following the AgencyStack SSO protocol
- Authentication middleware to protect the Traefik dashboard

## Installation

```bash
# Install with default settings
make traefik-keycloak

# Custom installation
make traefik-keycloak CLIENT_ID=myagency DOMAIN=example.com TRAEFIK_PORT=8090 KEYCLOAK_PORT=8091
```

## Configuration

The component is configured through the following files:
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/config/traefik/traefik.yml`: Main Traefik configuration
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/config/traefik/dynamic/basicauth.yml`: Authentication configuration

## Authentication Details

The Traefik dashboard is secured with HTTP Basic Authentication:
- Username: `admin`
- Password: `password`

Keycloak is available for more advanced SSO integration:
- Admin console: http://localhost:8091/auth/admin/
- Default credentials: `admin` / `admin`

## Testing

The component includes comprehensive tests following the AgencyStack TDD Protocol:

```bash
# Run tests
/root/_repos/agency-stack/scripts/components/test_traefik_keycloak.sh

# Run tests with debug output
/root/_repos/agency-stack/scripts/components/test_traefik_keycloak.sh --debug
```

## Ports

| Service | Default Port | Purpose |
|---------|--------------|---------|
| Traefik Dashboard | 8090 | Web UI for Traefik management |
| Traefik HTTP | 80 | HTTP traffic routing |
| Keycloak | 8091 | Identity provider admin interface |

## Logs

Logs can be viewed using:

```bash
# View Traefik logs
docker logs traefik_default

# View Keycloak logs
docker logs keycloak_default
```

## Restart and Stop

```bash
# Restart services
docker restart traefik_default keycloak_default

# Stop services
docker stop traefik_default keycloak_default
```

## Troubleshooting

### Cannot access Traefik dashboard

1. Verify Traefik is running:
   ```bash
   docker ps | grep traefik_default
   ```

2. Check port conflicts:
   ```bash
   netstat -tuln | grep 8090
   ```

3. Test authentication:
   ```bash
   curl -u admin:password http://localhost:8090/dashboard/
   ```

### Keycloak not working

1. Verify Keycloak is running:
   ```bash
   docker ps | grep keycloak_default
   ```

2. Check logs for errors:
   ```bash
   docker logs keycloak_default
   ```

3. Test direct connection:
   ```bash
   curl -I http://localhost:8091/auth/
   ```

## Security Considerations

- The basic auth credentials should be changed in production environments
- For production deployments, enable TLS encryption
- Keycloak should be properly secured with strong admin credentials
- Regular security audits should be conducted

## Related Components

- **Docker**: Container platform used to run Traefik and Keycloak
- **Portainer**: Optional UI for managing Docker containers
- **Nginx**: Can be used as an alternative reverse proxy
