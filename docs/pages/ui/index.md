# AgencyStack Control Panel UI

The AgencyStack Control Panel provides a modern web interface for managing your sovereign infrastructure. This document serves as an index of all UI components and pages available in the control panel.

## 📋 Main Pages

| Page | Description | Path |
|------|-------------|------|
| [Dashboard](./dashboard.md) | Overview of all components and their status | `/dashboard` |
| [Commands](./commands.md) | Execute CLI commands through a GUI interface | `/commands` |
| [Logs](./logs.md) | View and filter system logs | `/logs` |

## 🧩 UI Components

| Component | Description | Usage |
|-----------|-------------|-------|
| ComponentPanel | Displays component status and actions | Dashboard page |
| Sidebar | Navigation and client switching | All pages |
| LogViewer | Advanced log filtering and display | Logs page |
| CommandExecutor | Command execution with confirmation | Commands page |

## 🛠️ Development Tools

| Tool | Description | Command |
|------|-------------|---------|
| UI Development Server | Run the UI in development mode | `make ui-dashboard-start` |
| Component Status Check | Validate component registry | `make ui-panel-status` |
| Documentation Rebuild | Refresh component docs links | `make ui-panel-docs` |
| Alpha Check | Verify UI is ready for alpha | `make ui-alpha-check` |

## 🔄 Directory Structure

```
apps/control_panel/
├── public/                # Static assets
├── src/
│   ├── app/               # Next.js pages
│   │   ├── dashboard/     # Dashboard page
│   │   ├── commands/      # Commands page
│   │   ├── logs/          # Logs page
│   │   └── layout.tsx     # Main layout with sidebar
│   ├── components/        # Reusable UI components
│   │   ├── ComponentPanel.tsx  # Component status panel
│   │   ├── Sidebar.tsx    # Navigation sidebar
│   │   └── registry.ts    # Component registry loader
│   ├── hooks/             # Custom React hooks
│   │   └── useClientId.ts # Multi-tenant client context
│   └── styles/            # Global styles
├── Dockerfile             # Container build config
└── docker-compose.yml     # Container orchestration
```

## 🚀 Alpha Status

See the [Alpha Status](./alpha_status.md) document for the current state of the UI components and upcoming features planned for the release.
