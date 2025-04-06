# AgencyStack Control Panel Dashboard

![Control Panel Dashboard](../../assets/images/dashboard_screenshot.png)

The AgencyStack Control Panel Dashboard provides a comprehensive overview of all installed components and their current status. This interface allows administrators and clients to monitor, control, and interact with the various services that make up their sovereign infrastructure.

## 🚀 Quickstart for Local Development

To start the Control Panel UI in development mode:

```bash
# From the repository root
cd apps/control_panel
npm install
npm run dev
```

Alternatively, use the Makefile target:

```bash
make ui-dashboard-start
```

## 🧩 Component Panels

Each service in the AgencyStack ecosystem is represented by a Component Panel displaying:

- Component name, description, and version
- Current status with appropriate color coding:
  - **Green**: Running normally
  - **Yellow**: Warning state
  - **Red**: Error state 
  - **Gray**: Stopped or inactive
- Resource metrics (CPU, memory, disk, network)
- Associated tags (e.g., multi-tenant, sso, ai)
- Available actions (Start, Stop, Restart, Configure, Logs, etc.)
- Links to service URL and documentation

### Component Panel Lifecycle

1. **Loading**: The dashboard fetches component data from the registry and status files
2. **Filtering**: User can filter components by category, tag, or search term
3. **Actions**: When a user executes an action:
   - Button shows loading state
   - Request is sent to the backend
   - Success/error message is displayed
   - Component refreshes with updated status

## 🔌 Adding New Components to the Dashboard

To add a new service to the Control Panel:

1. Add the component definition to `/config/registry/component_registry.json`:

```json
{
  "id": "new-component",
  "name": "New Component",
  "description": "Description of the new component",
  "category": "application",
  "tags": ["multi-tenant", "custom-tag"],
  "serviceUrl": "https://new-component.${DOMAIN}",
  "documentationUrl": "/docs/components/new-component.md",
  "multiTenant": true,
  "actions": {
    "start": true,
    "stop": true,
    "restart": true,
    "logs": true
  }
}
```

2. Create component documentation in `/docs/components/new-component.md`

3. Run `make ui-panel-docs` to rebuild documentation links

4. Restart the Control Panel UI

## 🔐 Multi-Tenant Access Control

The Control Panel respects multi-tenant boundaries through the `useClientId` hook:

- Administrators can see and manage all components
- Client users can only see and manage components assigned to their clientId
- Components marked as `multiTenant: true` will show the associated client
- System-wide components are visible to all users but may have restricted actions

## 🛠️ Troubleshooting

If components don't appear correctly:

1. Run `make ui-panel-status` to check registry connectivity
2. Ensure the component registry and status files exist and are properly formatted
3. Check browser console for any error messages
4. Verify that `CLIENT_ID` is properly set for multi-tenant access
