# Jitsi Meet

Jitsi Meet provides secure, high-quality video conferencing capabilities within the AgencyStack ecosystem. This component is fully integrated with Keycloak SSO and Traefik for secure, authenticated access.

## Features

- **Secure Video Conferencing**: Host encrypted, private video meetings
- **SSO Integration**: Seamless authentication via Keycloak
- **Multi-tenant Support**: Isolated user experiences across clients
- **TLS Support**: End-to-end encrypted communications
- **Monitoring**: Health monitoring via dashboard integration

## Installation

```bash
# Basic installation
make jitsi DOMAIN=yourdomain.com

# Installation with Keycloak SSO enabled
make jitsi DOMAIN=yourdomain.com ENABLE_KEYCLOAK=true

# Fully secured installation with SSO and HTTPS enforcement
make jitsi DOMAIN=yourdomain.com ENABLE_KEYCLOAK=true ENFORCE_HTTPS=true
```

### Advanced Installation Options

For more control, you can use the installation script directly:

```bash
scripts/components/install_jitsi.sh \
  --domain yourdomain.com \
  --jitsi-subdomain meet \
  --enable-keycloak \
  --enforce-https
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--domain` | Primary domain for your AgencyStack | localhost |
| `--client-id` | Client identifier for multi-tenant deployments | default |
| `--jitsi-subdomain` | Subdomain for Jitsi Meet | meet |
| `--use-host-network` | Whether to use host network mode | true |
| `--enable-keycloak` | Enable Keycloak SSO integration | false |
| `--enforce-https` | Force HTTPS for secure communications | true |

## Access

After installation, Jitsi Meet will be accessible at:

```
https://meet.yourdomain.com
```

## SSO Integration

When installed with `--enable-keycloak`, Jitsi Meet is configured to use Keycloak for authentication. This provides:

- Single Sign-On across AgencyStack components
- Role-based access control
- User session management
- External identity provider support

### Verification

To verify SSO integration:

1. Visit `https://meet.yourdomain.com`
2. You should be redirected to the Keycloak login page
3. After logging in, you'll be returned to Jitsi Meet
4. Component registry will show `sso_configured: true` for Jitsi

## Monitoring

Jitsi Meet includes monitoring integration with the AgencyStack dashboard. The following metrics are available:

- System health status
- Active meeting counts 
- Participant counts
- Server resource utilization

## Paths

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/{client_id}/apps/jitsi` | Installation directory |
| `/opt/agency_stack/clients/{client_id}/apps/jitsi/config` | Configuration files |
| `/opt/agency_stack/clients/{client_id}/apps/jitsi/data` | Persistent data |
| `/var/log/agency_stack/components/jitsi` | Log files |

## Troubleshooting

If Jitsi Meet is not working as expected:

1. Check the logs: `make jitsi-logs`
2. Verify Traefik routing: `make traefik-status`
3. Ensure Keycloak is accessible: `make keycloak-status`
4. Validate DNS configuration: `dig meet.yourdomain.com`

## Related Components

- [Keycloak](keycloak.md): Identity provider for SSO
- [Traefik](traefik.md): Routing and TLS provider
- [Dashboard](dashboard.md): Monitoring integration
