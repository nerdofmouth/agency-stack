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
make dashboard

# Check dashboard status
make dashboard-status

# View dashboard logs
make dashboard-logs
```

## Paths

| Purpose | Path |
|---------|------|
| Installation | `/opt/agency_stack/dashboard/` |
| Client-specific | `/opt/agency_stack/clients/${CLIENT_ID}/dashboard/` |
| Logs | `/var/log/agency_stack/components/dashboard.log` |
| Executable | `/usr/local/bin/agency-stack-dashboard` |
| Source Files | `/root/_repos/agency-stack/dashboard/` |

## Configuration

The dashboard automatically pulls configuration from:

- `/root/_repos/agency-stack/config/registry/component_registry.json`
- Component-specific `.installed_ok` markers

No additional configuration is required for basic functionality.

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

## Troubleshooting

Common issues:

1. **Dashboard shows incorrect status:**
   - Ensure component registry is up-to-date
   - Verify `.installed_ok` markers exist
   - Check component-specific status commands

2. **Missing components:**
   - Ensure components are properly registered in component registry
   - Verify installation paths

3. **jq dependency missing:**
   - Run `make dashboard` to install all dependencies properly

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
