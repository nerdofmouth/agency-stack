# WordPress

WordPress is a powerful content management system that allows you to create and manage websites, blogs, and online stores. In AgencyStack, WordPress is deployed with enhanced security, performance optimizations, and Keycloak SSO integration.

## Features

- **Content Management**: Create, edit, and publish content easily
- **Multi-tenant Support**: Isolated WordPress instances per client
- **Keycloak SSO Integration**: Single sign-on across AgencyStack components
- **Performance Optimization**: Redis caching for improved response times
- **Secure Deployment**: HTTPS enforcement and security hardening
- **Monitoring Integration**: Health checks and status reporting

## Installation

### Prerequisites

- Docker and Docker Compose installed
- Traefik reverse proxy configured
- Domain name properly configured in DNS
- (Optional) Keycloak for SSO integration

### Standard Installation

```bash
# Basic installation
make wordpress DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com

# With client ID for multi-tenancy
make wordpress DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com CLIENT_ID=client1
```

### Installation with Keycloak SSO

```bash
# Install WordPress with Keycloak SSO integration
make wordpress DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com ENABLE_KEYCLOAK=true

# Complete secure installation with all options
make wordpress DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com ENABLE_KEYCLOAK=true ENFORCE_HTTPS=true
```

### Installation Options

The installation script supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `--domain` | Domain name for WordPress | Required |
| `--client-id` | Client identifier for multi-tenant deployments | default |
| `--admin-email` | Email for the admin account | Required |
| `--wp-version` | WordPress version to install | latest |
| `--php-version` | PHP version to use | 8.1 |
| `--enable-keycloak` | Enable Keycloak SSO integration | false |
| `--enforce-https` | Force HTTPS for secure access | true |
| `--use-host-network` | Use host network mode | true |
| `--force` | Force reinstallation if already installed | false |
| `--with-deps` | Install dependencies automatically | false |
| `--verbose` | Show detailed output during installation | false |

## Keycloak SSO Integration

WordPress integrates with Keycloak to provide secure single sign-on capabilities across all AgencyStack components.

### SSO Implementation

The SSO integration uses the following components:

1. **OpenID Connect Generic Plugin**: Installed and configured automatically
2. **Keycloak Client Registration**: Automatically registered in Keycloak
3. **Automatic User Provisioning**: New users created from Keycloak accounts
4. **Role Mapping**: Maps Keycloak roles to WordPress user roles

### Configuration Details

When installed with `--enable-keycloak`, the following configurations are applied:

- Auto login option enabled for seamless authentication
- Keycloak server endpoints configured for authentication
- User identity mapping based on Keycloak username
- Automatic linking of existing users
- User creation for new Keycloak users

### Verification

To verify that SSO integration is correctly configured:

1. Check the component registry for SSO status:
   ```bash
   make wordpress-status
   ```

2. Verify the SSO configuration files exist:
   ```bash
   ls -la /opt/agency_stack/wordpress/{domain}/sso/
   ```

3. Access WordPress admin area and verify it redirects to Keycloak login.

## Paths and Data

| Path | Description |
|------|-------------|
| `/opt/agency_stack/wordpress/{domain}` | WordPress site data |
| `/opt/agency_stack/wordpress/{domain}/wp-content` | Themes, plugins, and uploads |
| `/opt/agency_stack/wordpress/{domain}/database` | MariaDB database data |
| `/opt/agency_stack/wordpress/{domain}/sso` | SSO configuration (if enabled) |
| `/var/log/agency_stack/components/wordpress.log` | Installation log file |

## Monitoring Integration

WordPress is integrated with the AgencyStack monitoring system, providing:

- Health checks for WordPress and database
- Performance metrics for response time
- Error logging and alerting
- Status reporting via dashboard

## Traefik Integration

WordPress is automatically configured with Traefik for:

- HTTPS termination and secure access
- Automatic TLS certificate management
- Domain-based routing
- Efficient proxying of requests

## Troubleshooting

If you encounter issues during installation or operation:

1. Check the installation logs:
   ```bash
   cat /var/log/agency_stack/components/wordpress.log
   ```

2. Verify the Docker containers are running:
   ```bash
   docker ps | grep wordpress
   ```

3. Check the WordPress error logs inside the container:
   ```bash
   docker exec -it {container_name} cat /var/www/html/wp-content/debug.log
   ```

4. If SSO integration issues occur, verify Keycloak is properly configured:
   ```bash
   make keycloak-status
   ```

## Related Components

- [Keycloak](keycloak.md): Identity provider for SSO
- [Traefik](traefik.md): Routing and TLS termination
- [Dashboard](dashboard.md): Monitoring integration
