# SSL Certificates with Let's Encrypt

## Overview
AgencyStack uses Let's Encrypt to provide free, automated SSL/TLS certificates for all components. This ensures secure connections to all services without the need for self-signed certificates or manual certificate management. The integration is primarily handled through Traefik, which automates the certificate issuance, renewal, and deployment process.

## Features
- **Automatic Certificate Issuance**: Certificates are automatically requested for configured domains
- **Automatic Renewal**: Certificates are renewed before expiration with no downtime
- **Multiple Domains Support**: Each component can have its own subdomain with a valid certificate
- **Zero-Downtime Updates**: Certificate renewals happen without service interruption
- **Robust Error Handling**: Failures in certificate issuance do not affect service availability

## Architecture
The SSL certificate management in AgencyStack follows this architecture:

1. **Traefik** serves as the certificate manager and TLS termination point
2. **Let's Encrypt ACME Protocol** handles certificate issuance via HTTP-01 challenge
3. **Domain Validation** occurs automatically through properly configured DNS
4. **Certificate Storage** in `/opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json`

## Installation

### Prerequisites
- Port 80 must be accessible from the internet for Let's Encrypt HTTP-01 challenge
- Valid domain names must be configured with DNS pointing to the server
- Email address for certificate expiration notifications

### Automatic Installation
SSL certificate management is automatically configured when installing Traefik:

```bash
make traefik DOMAIN=yourdomain.com ADMIN_EMAIL=admin@example.com
```

### Manual Configuration
To update or configure SSL certificates for existing installations:

```bash
make ssl-certificates
```

This interactive command will:
1. Prompt for domain and admin email
2. Configure Traefik to use Let's Encrypt
3. Reset existing certificate configuration if needed
4. Restart Traefik to apply changes

### Non-interactive Configuration
For automation scripts or CI/CD pipelines:

```bash
make traefik-ssl DOMAIN=yourdomain.com ADMIN_EMAIL=admin@example.com
```

## Paths & Directories

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json` | Let's Encrypt certificate storage |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/traefik.yml` | Main Traefik configuration including ACME |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/tls.yml` | TLS configuration options |
| `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/domains.yml` | Domain-specific routing rules |

## Certificate Management

### Checking Certificate Status
To verify the status of certificates:

```bash
make ssl-certificates-status
```

This will show:
- Whether certificates have been issued
- Which domains have valid certificates
- Basic configuration status

For detailed certificate information:

```bash
cat /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json | jq
```

### Forcing Certificate Renewal
To force certificate renewal (useful if certificates were improperly issued):

```bash
make traefik-ssl DOMAIN=yourdomain.com ADMIN_EMAIL=admin@example.com FORCE=true
```

## Troubleshooting

### Common Issues

#### Certificate Issuance Failure
If certificates aren't issued after configuration:

**Solution**:
1. Verify DNS configuration: `dig +short yourdomain.com` should return your server IP
2. Check that port 80 is accessible from the internet
3. Ensure Traefik is properly configured: `cat /opt/agency_stack/clients/${CLIENT_ID}/traefik/config/traefik.yml`
4. Check Traefik logs: `docker logs traefik_default | grep "certificate\|acme"`

#### Certificate Not Renewing
Let's Encrypt certificates are valid for 90 days and should auto-renew after 60 days:

**Solution**:
1. Check if Traefik is running: `docker ps | grep traefik`
2. Verify acme.json permissions: `ls -la /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json`
3. Reset certificate storage: `echo "{}" > /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json && chmod 600 /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme/acme.json`
4. Restart Traefik: `make traefik-restart`

#### Browser Security Warnings
If browsers show security warnings despite certificate configuration:

**Solution**:
1. Verify certificate validity: `curl -vI https://yourdomain.com 2>&1 | grep "SSL certificate"`
2. Check certificate transparency logs: `https://crt.sh/?q=yourdomain.com`
3. Force certificate renewal as described above

## Implementation Details

### TLS Configuration
The default TLS configuration is designed for security and compatibility:

```yaml
tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
```

### Let's Encrypt Configuration
Let's Encrypt integration is configured in Traefik with:

```yaml
certificatesResolvers:
  myresolver:
    acme:
      email: "${ADMIN_EMAIL}"
      storage: /etc/traefik/acme/acme.json
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
      httpChallenge:
        entryPoint: web
```

## Makefile Targets

| Target | Description | Parameters |
|--------|-------------|------------|
| `make ssl-certificates` | Interactive SSL certificate configuration | None |
| `make ssl-certificates-status` | Check status of issued certificates | None |
| `make traefik-ssl` | Configure SSL non-interactively | DOMAIN, ADMIN_EMAIL |

## Security Recommendations

### Certificate Best Practices
1. **Use Valid Admin Email**: Ensure the admin email is valid to receive expiration notifications
2. **Regular Status Checks**: Periodically run `make ssl-certificates-status` to verify certificates
3. **Secure acme.json**: Ensure file permissions are set to 600 for the acme.json file
4. **Monitor Renewal**: Set up monitoring to verify certificate renewal is working properly

### Rate Limits
Let's Encrypt enforces rate limits to prevent abuse:
- 50 certificates per registered domain per week
- 100 names per certificate
- 5 duplicate certificates per week
- 5 failed validations per account, per hostname, per hour

Be mindful of these limits when testing or reconfiguring certificates frequently.

## Related Components
- [Traefik](./traefik.md) - The reverse proxy handling certificate management
- [DNS Configuration](./dns-configuration.md) - DNS setup required for proper certificate validation
- [WordPress](./wordpress.md) - Web application secured with SSL certificates
- [Keycloak](./keycloak.md) - SSO solution secured with SSL certificates
