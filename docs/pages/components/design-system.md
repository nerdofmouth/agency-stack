# AgencyStack Design System (Bit.dev Integration)

The AgencyStack Design System is a component library and UI framework that provides consistent, sovereign UI components for all AgencyStack interfaces, built with [Bit](https://bit.dev/).

## Overview

The design system provides reusable UI components for AgencyStack, enabling consistency across components, dashboards, and control panels while maintaining sovereignty and multi-tenant support.

**Key Features:**
- Component development environment with Bit.dev
- Real-time component preview and testing
- Integration with AgencyStack dashboard
- Standardized logging to `/var/log/agency_stack/ui/`
- Multi-tenant theme support

## Installation

The design system can be installed using the standard AgencyStack Makefile target:

```bash
make design-system [--client-id=<client-id>] [--port=<port>] [--bit-port=<bit-port>] [--enable-cloud]
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `client-id` | Client ID for multi-tenant deployments | `default` |
| `port` | Port for design system dashboard | `3333` |
| `bit-port` | Port for Bit dev server | `3000` |
| `enable-cloud` | Enable Bit.dev cloud features | Off (sovereign mode) |

## Paths and Ports

| Purpose | Path |
|---------|------|
| Installation directory | `/opt/agency_stack/clients/${CLIENT_ID}/design-system/` |
| Logs | `/var/log/agency_stack/components/design-system.log` |
| Dashboard service | Port 3333 |
| Bit dev server | Port 3000 |
| Components source | `/design-system-bit/components/ui/` |

## Managing the Design System

### Status Check

```bash
make design-system-status
```

This displays:
- Dashboard service status
- Bit dev server status
- URLs for accessing the dashboard and Bit dev environment

### Viewing Logs

```bash
make design-system-logs
```

This shows the last 50 lines of the design system logs, including component usage and API requests.

### Restarting

```bash
make design-system-restart
```

This restarts both:
- The dashboard integration service
- The Bit dev server

## Component Development

The AgencyStack Design System follows a strict component lifecycle:

1. Create a new component: `bit create react-component <component-name>`
2. Implement the component using Tailwind and ShadCN patterns
3. Document with MDX (`.docs.mdx`)
4. Create compositions for preview (`.compositions.tsx`)
5. Write tests (`.spec.tsx`)

All components must adhere to the AgencyStack naming convention:
- Use kebab-case for folders (`install-card`)
- Use PascalCase for React components (`InstallCard.tsx`)

### Required Files per Component

- `index.tsx`: Main component implementation
- `index.ts`: Exports
- `<component-name>.docs.mdx`: Documentation
- `<component-name>.compositions.tsx`: Examples
- `<component-name>.spec.tsx`: Tests

## Integration with AgencyStack

The design system integrates with the AgencyStack ecosystem:

1. **Component Registry**: Components are registered in `component_registry.json`
2. **Dashboard**: Preview links are available in the AgencyStack dashboard
3. **Logging**: Usage is logged to standard AgencyStack log paths
4. **Multi-tenant**: Supports client-specific theming

## Security Considerations

The design system follows the AgencyStack security guidelines:

- **Sovereignty**: No external tracking or data collection
- **Offline-First**: Fully functional without internet access
- **Self-Contained**: All assets are included in the system
- **Permission-Based**: Respects AgencyStack's multi-tenant permissions

## Troubleshooting

### Dashboard Not Accessible

If the design system dashboard is not accessible:

1. Check the service status: `systemctl status agencystack-design-system.service`
2. View logs: `journalctl -u agencystack-design-system.service`
3. Restart the service: `make design-system-restart`

### Bit Dev Server Not Running

If the Bit dev server is not running:

1. Check process status: `ps aux | grep "bit dev"`
2. View Bit logs: `cat /var/log/agency_stack/components/design-system.log.bit-dev`
3. Restart Bit dev: `cd /opt/agency_stack/clients/${CLIENT_ID}/design-system && bit dev --port 3000`
