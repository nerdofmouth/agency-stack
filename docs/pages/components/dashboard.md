# AgencyStack Dashboard

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

- Proper HTTP and HTTPS routes for root domain and /dashboard path
- DNS resolution verification
- Port accessibility checks
- Automatic Traefik configuration

After installation, the dashboard will be accessible via:
- http://yourdomain.com
- http://yourdomain.com/dashboard
- https://yourdomain.com (if TLS is configured)
- https://yourdomain.com/dashboard (if TLS is configured)

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
