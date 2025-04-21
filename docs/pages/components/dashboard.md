# AgencyStack Dashboard

## SSO & TLS Migration Update (2025-04-20)

> **Note:** As of April 2025, dashboard installation now enforces SSO and HTTPS/TLS via unified preflight checks in `common.sh`. All Keycloak SSO logic is managed through the `--enable-keycloak` install flag and validated by the `preflight_check_agencystack` function. Deprecated fix scripts have been removed.

The AgencyStack Dashboard provides a real-time overview of all installed components and their current status. It serves as a central hub for monitoring and managing your AgencyStack installation.

## Purpose

The dashboard component fulfills these core functions:

- Provides real-time status monitoring of all AgencyStack components
- Displays which components are running, stopped, or experiencing errors
- Shows feature flags for each component (SSO, TLS, Multi-tenant, etc.)
- Offers direct access to component logs and management functions
- Supports both CLI and web-based interfaces

## Installation

```bash
# Install the dashboard component
make dashboard DOMAIN=yourdomain.com

# Check dashboard status
make dashboard-status

# View dashboard logs
make dashboard-logs
```

### FQDN Access Configuration

The dashboard installation now automatically configures Traefik routes to ensure proper FQDN access. This includes:

- Routing for the root domain to display the dashboard on the homepage
- A dedicated `/dashboard` path for accessing the dashboard via path-based routing
- Support for both HTTP and HTTPS access methods
- Automatic configuration based on your DOMAIN and CLIENT_ID settings

## Keycloak SSO Integration

The AgencyStack Dashboard supports secure authentication through Keycloak SSO integration. This provides:

- Single Sign-On (SSO) for the dashboard and other AgencyStack components
- Role-based access control through Keycloak's powerful RBAC system
- Integration with external identity providers (OpenID Connect, SAML)
- Secure token-based authentication with proper session management

### Enabling Keycloak SSO

To enable Keycloak SSO integration during dashboard installation:

```bash
# Install dashboard with Keycloak SSO integration enabled
make dashboard DOMAIN=yourdomain.com --enable-keycloak

# For more control over configuration options
scripts/components/install_dashboard.sh --domain yourdomain.com --enable-keycloak --keycloak-realm myrealm
```

### TLS/SSO Validation

After installation with Keycloak SSO enabled, you can verify the configuration:

```bash
# Verify SSO integration status
make dashboard-sso-check DOMAIN=yourdomain.com

# Check complete SSO status including realm configuration
make sso-status DOMAIN=yourdomain.com

# Verify TLS configuration for secure access
make tls-verify DOMAIN=yourdomain.com
```

These verification commands ensure that:
1. The dashboard is properly registered as a Keycloak client
2. Authentication flows work correctly
3. TLS certificates are valid and HTTPS redirection is working

### Configuration Options

The following Keycloak-related options are available:

| Option | Description | Default |
|--------|-------------|---------|
| `--enable-keycloak` | Enable Keycloak SSO integration | false |
| `--keycloak-realm` | Keycloak realm to use | agency_stack |
| `--keycloak-client-id` | Client ID for dashboard | dashboard |
| `--enforce-https` | Force HTTPS redirection for secure access | false |

### Verification

After installation with Keycloak SSO enabled, you can verify the configuration:

1. The component registry will show `sso_configured: true` for the dashboard
2. The dashboard login should redirect to the Keycloak login page
3. Authentication tokens will be properly managed for secure sessions

If Keycloak is not available during installation, the dashboard will still be configured for SSO but will fall back to local authentication until Keycloak becomes available.

## HTTPS Enforcement

For production deployments, it's recommended to enforce HTTPS to ensure secure access to the dashboard:

```bash
# Install dashboard with enforced HTTPS
make dashboard DOMAIN=yourdomain.com ENFORCE_HTTPS=true

# Combined with Keycloak SSO for maximum security
make dashboard DOMAIN=yourdomain.com --enable-keycloak ENFORCE_HTTPS=true
```

When HTTPS enforcement is enabled, all HTTP traffic will be automatically redirected to HTTPS for secure access.

## Paths

| Purpose | Path |
|---------|------|
| Installation | `/opt/agency_stack/apps/dashboard/` |
| Client-specific | `/opt/agency_stack/clients/${CLIENT_ID}/dashboard/` |
| Logs | `/var/log/agency_stack/components/dashboard.log` |
| Traefik Route | `/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/dashboard-route.yml` |
| Source Files | `/root/_repos/agency-stack/dashboard/` |

## Configuration

The dashboard automatically pulls configuration from:

- `/root/_repos/agency-stack/config/registry/component_registry.json`
- Component-specific `.installed_ok` markers

No additional configuration is required for basic functionality.

## Access Methods

### Direct Access

The dashboard is accessible directly at:
```
http://SERVER_IP:3001
```

### FQDN Access

When properly configured with Traefik, the dashboard is accessible via:
```
http://yourdomain.com
http://yourdomain.com/dashboard
https://yourdomain.com (if TLS is configured)
```

## Security & Access

- All dashboard access is now enforced over HTTPS by default. SSO is enabled via Keycloak if configured during installation.
- After installation, the installer will verify TLS status and flag the dashboard as secure in the component registry.
- If you encounter access issues, use the provided `verify_tls.sh` utility to manually check HTTPS availability.

## Registry Flags

- `traefik_tls: true` — HTTPS verified and enforced
- `sso_configured: true` — SSO is active and validated
- `monitoring: true` — Dashboard monitoring is enabled

## Troubleshooting

### Common Issues

#### Dashboard not accessible via FQDN

**Check DNS resolution:**
```bash
dig +short yourdomain.com
```
This should return your server's IP address.

**Check Traefik configuration:**
```bash
make traefik-status
```

**Ensure ports 80/443 are accessible:**
```bash
# Check if ports are in use
sudo lsof -i:80
sudo lsof -i:443
```

**Verify Traefik routes:**
```bash
cat /opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic/dashboard-route.yml
```

#### Dashboard shows errors or blank screen

**Check dashboard logs:**
```bash
make dashboard-logs
```

**Restart the dashboard:**
```bash
make dashboard-restart
```

## Usage

### CLI Dashboard

Run the dashboard directly from the command line:

```bash
# Using the symlink
agency-stack-dashboard

# Using make target
make dashboard
```

### Web UI Integration

The dashboard specification (`dashboard/agency_stack_dashboard_spec.json`) provides a complete blueprint for integration with the AgencyStack NextJS Control Panel. Frontend developers can use this specification to implement the web-based dashboard.

## Security Considerations

- The dashboard does not require authentication for CLI usage
- For web UI integration, all authentication should be handled by the Control Panel
- The dashboard only reads status information and does not modify component configurations

## Logs

Dashboard logs are stored in:
```
/var/log/agency_stack/components/dashboard.log
```

Common log entries include:
- Component status checks
- Dashboard initialization
- Error conditions when components cannot be properly monitored

## Restart Methods

```bash
# Restart the dashboard service
make dashboard-restart

# Alternatively, manually kill and restart
pkill -f "agency-stack-dashboard"
agency-stack-dashboard &
```

## Integration with Other Components

The dashboard integrates with all other AgencyStack components through:

1. Reading from the component registry
2. Executing `make <component>-status` commands
3. Checking installation markers
4. Displaying feature flags from registry

## Multi-tenant Support

When used with the `--client-id` flag, the dashboard will:
- Install to client-specific paths
- Only show components relevant to that client
- Respect client-specific configuration
