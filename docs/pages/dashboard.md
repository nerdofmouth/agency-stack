# AgencyStack Dashboard

AgencyStack includes a comprehensive web-based dashboard for monitoring and managing all components of your infrastructure. The dashboard provides a central location to view service status, manage integrations, and resolve port conflicts.

## Dashboard Access

The dashboard is available at `http://dashboard.{YOUR_DOMAIN}` after installation. You can access it using the following methods:

| Method | Command | Description |
|--------|---------|-------------|
| Command Line | `make dashboard` | Open the dashboard via the default command |
| Command Line | `make dashboard-open` | Open the dashboard in your default browser |
| Direct URL | http://dashboard.{YOUR_DOMAIN} | Direct access via web browser |

## Dashboard Features

The AgencyStack dashboard provides three main views:

1. **Services View** - The default view showing all installed services and their status
2. **Integrations View** - Shows the status of integrations between components
3. **Port Management View** - Displays port assignments and helps resolve conflicts

### Services View

The Services view shows the status of all AgencyStack components and services:

- **Status indicators:** Running (green), Stopped (yellow), Not Installed (red)
- **Service information:** Includes domain, ports, and integration badges
- **Filtering:** Filter services by category (Core Infrastructure, Databases, etc.)
- **Service actions:** Open, Install, Start, Stop, Integrate

Each service card includes integration badges showing which integrations are active for that service. For example, a WordPress service might show badges for SSO, Email, Monitoring, and Data Bridge integrations.

### Integrations View

The Integrations view provides detailed information about the status of all integration types:

- **SSO Integration:** Single Sign-On with Keycloak for all components
- **Email Integration:** Email services with Mailu for all components
- **Monitoring Integration:** Loki and Grafana monitoring setup
- **Data Bridge Integration:** Data exchange between WordPress and ERPNext

Each integration card shows:

- **Status:** Applied ✅, Partial ⚠️, or Not Applied ❌
- **Components:** List of integrated components and their versions
- **Last Updated:** Timestamp of the last integration update

Integration actions:
- Run a specific integration (SSO, Email, Monitoring, Data Bridge)
- Run all integrations at once

### Port Management View

The Port Management view helps identify and resolve port conflicts:

- **Port Status Table:** Shows all reserved ports, their assigned services, and status
- **Conflict Detection:** Highlights ports with conflicts (system conflicts or duplicates)
- **Conflict Resolution:** Suggests alternative ports and provides one-click resolution

Port management actions:
- Detect conflicts (without making changes)
- Automatically remap conflicting ports
- Scan and update the port registry

## Dashboard Data

The dashboard displays data from several sources:

| Data | Source | Update Method |
|------|--------|---------------|
| Service Status | `/opt/agency_stack/dashboard/service_status.json` | `make dashboard-refresh` |
| Integration Status | `/opt/agency_stack/integrations/state/` | Updated by integration scripts |
| Port Assignments | `/opt/agency_stack/ports/ports.json` | Updated by port management tools |

## Real-time Updates

The dashboard data refreshes automatically:

- **Auto-refresh:** The dashboard auto-refreshes every 5 minutes
- **Manual refresh:** Click the "Refresh Dashboard" button or run `make dashboard-update`
- **Webhook updates:** Dashboard data is updated automatically when running integrations

## Adding the Dashboard to a New Installation

If you're setting up AgencyStack from scratch, the dashboard is installed by default. If you need to add it to an existing installation:

```bash
make dashboard-enable
```

This will:
1. Create the necessary Docker container
2. Set up Traefik routing
3. Generate initial service status data
4. Configure automatic updates

## Customizing the Dashboard

The dashboard can be customized by editing the files in `/opt/agency_stack/dashboard/`:

- `index.html` - Dashboard structure and layout
- `styles.css` - Visual styling and themes
- `script.js` - Dashboard functionality
- `dashboard_data.json` - Combined data source for the dashboard

## Troubleshooting

If the dashboard is not displaying correctly or showing outdated information:

1. Run `make dashboard-update` to refresh the dashboard data
2. Check that all services are running with `docker ps`
3. Verify Traefik is properly routing to the dashboard with `docker logs traefik`
4. Inspect the dashboard logs with `docker logs agencystack-dashboard`

## Best Practices

- **Regular Updates:** Run `make dashboard-update` after significant infrastructure changes
- **Port Management:** Use the dashboard to detect and resolve port conflicts before deploying new services
- **Integration Status:** Check the Integrations view before making manual changes to components
- **Documentation:** Keep the dashboard information and actual infrastructure in sync

## Related Commands

- `make dashboard` - Open the dashboard
- `make dashboard-update` - Update dashboard data
- `make dashboard-open` - Open the dashboard in browser
- `make dashboard-refresh` - Refresh the dashboard container
- `make dashboard-enable` - Enable the dashboard service
- `make detect-ports` - Detect port conflicts (also accessible from dashboard)
- `make remap-ports` - Automatically resolve port conflicts
