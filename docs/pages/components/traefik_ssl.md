# Traefik SSL

## Overview

Traefik SSL is a component that configures SSL/TLS for Traefik, providing secure HTTPS connections for all AgencyStack services. It supports both Let's Encrypt for automatic certificate management and self-signed certificates for development environments.

## Installation

```bash
# Standard installation
make traefik_ssl

# With custom options
make traefik_ssl CLIENT_ID=myagency DOMAIN=example.com EMAIL=admin@example.com
```

## Configuration

The Traefik SSL component stores its configuration in:
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik/ssl/`

Key files:
- `acme.json`: Let's Encrypt certificate storage
- `certs/`: Directory containing SSL certificates
  - `server.key`: Private key
  - `server.crt`: Certificate
  - `server.csr`: Certificate Signing Request (if applicable)

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client identifier | `default` |
| `--domain` | Domain name for certificates | `localhost` |
| `--email` | Email for Let's Encrypt | `admin@example.com` |
| `--force` | Force reinstallation | `false` |
| `--self-signed` | Use self-signed certificates | `false` |
| `--cert-file` | Custom certificate file path | `""` |
| `--key-file` | Custom key file path | `""` |

## Restart and Maintenance

```bash
# Check status
make traefik_ssl-status

# View logs
make traefik_ssl-logs

# Restart the service
make traefik_ssl-restart
```

## Security

The Traefik SSL component:

- Manages TLS certificate renewals automatically
- Generates strong 2048-bit RSA keys
- Enables secure TLS 1.2+ protocols
- Disables weak cipher suites
- Implements HTTP to HTTPS redirects
- Stores ACME credentials securely 
- Isolates certificates per client in multi-tenant setups

## Troubleshooting

Common issues:

1. **Certificate Renewal Failures**
   - Check DNS configuration
   - Verify port 80/443 are accessible
   - Review Let's Encrypt rate limits

2. **Certificate Not Trusted**
   - For self-signed: Add exception or import CA
   - For Let's Encrypt: Verify correct domain configuration

3. **Configuration Errors**
   - Check Traefik configuration files
   - Validate proper ACME challenge setup
