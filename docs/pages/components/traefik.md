# Traefik Dashboard

## Overview
Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy.
This installation provides a dashboard for monitoring and configuring Traefik.

## Installation

```bash
# Basic installation
bash scripts/components/install_traefik.sh

# With Keycloak authentication
bash scripts/components/install_traefik.sh --enable-keycloak --domain keycloak.example.com --admin-email admin@example.com
```

## Access

The dashboard is available at:
```
http://localhost:8081/dashboard/
```

## Authentication

The dashboard is secured with Keycloak authentication:
- Keycloak Domain: keycloak.example.com
- Keycloak Realm: default
- Client ID: traefik-dashboard
- Callback URL: http://localhost:8081/oauth-callback

## Configuration

Configuration files are located at:
```
/opt/agency_stack/clients/default/traefik/config
```

## Logs

Logs are available in:
```
/var/log/agency_stack/components/traefik
```

## Testing

### Basic verification
```bash
/opt/agency_stack/clients/default/traefik/scripts/verify.sh
```

### TDD tests
```bash
/opt/agency_stack/clients/default/traefik/scripts/test.sh
```

### Integration tests
```bash
/opt/agency_stack/clients/default/traefik/scripts/integration_test.sh
```

## Restart

To restart Traefik:
```bash
cd /opt/agency_stack/clients/default/traefik && docker-compose restart
```
