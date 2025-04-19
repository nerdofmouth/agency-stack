# AgencyStack Design System (Bit-Enabled)

This is the official AgencyStack Design System built with [Bit](https://bit.dev/) to provide a sovereign, composable component library for all AgencyStack interfaces.

## 🧠 Philosophy

- **Design system = infrastructure**: UI components are treated with the same rigor as any other part of the AgencyStack ecosystem
- **Sovereignty first**: Components are self-contained, exportable, and observable without external dependencies
- **Every piece is versioned**: Each component is independently versioned, documented, and tested

## 🔧 Structure

- `/components/ui/`: Contains all UI components
- `/compositions/`: Interactive examples and playground
- `/docs/`: Documentation in MDX format

## 📋 Component Lifecycle

1. Create a new component: `bit create react-component component-name`
2. Implement the component using Tailwind and ShadCN patterns
3. Document with MDX (`.docs.mdx`)
4. Create compositions for preview (`.compositions.tsx`)
5. Write tests (`.spec.tsx`)
6. Preview with `bit dev`
7. Tag version: `bit tag component-name 1.0.0 --message "Alpha UI release"`
8. Optionally export to a registry: `bit export nerdofmouth.design-system/component-name`

## 🔒 Sovereign Configuration

All components adhere to AgencyStack Alpha Phase Directives:

- No external dependencies or tracking
- Self-hosted by default
- Fully functional offline
- Log usage to proper log locations
- All code changes tracked in repository

## 🧩 Available Components

### InstallCard

The `InstallCard` component displays installation status of AgencyStack components with logs and metrics integration.

```tsx
import { InstallCard } from '@nerdofmouth.design-system/ui/install-card';

function MyComponent() {
  return (
    <InstallCard
      name="Kill Bill"
      status="running"
      description="Subscription billing and invoicing"
      version="0.24.0"
      lastUpdated={new Date()}
      onViewLogs={() => {}}
      onViewMetrics={() => {}}
      onRestart={() => {}}
    />
  );
}
```

## 🔄 Integration with AgencyStack

Each component integrates with the AgencyStack ecosystem:

1. **Component Registry**: Components can read from and write to the component registry
2. **Logging**: Usage is logged to `/var/log/agency_stack/ui/`
3. **Monitoring**: Status is monitored through the dashboard
4. **Multi-tenant**: Client-specific themes and configurations are supported

## 🛠️ Development

### Prerequisites

- Node.js 18+
- Bit CLI: `npm install -g @teambit/bvm && bvm install`

### Getting Started

1. Clone the repository
2. Run `bit install` to install dependencies
3. Run `bit dev` to start the development server
4. Access the playground at http://localhost:3000

## 🧪 Testing

Run all tests:

```bash
bit test
```

Test a specific component:

```bash
bit test install-card
```

## 📦 Building for Production

Tag components for release:

```bash
bit tag --all --message "Release version"
```

Export components:

```bash
bit export
```

## 📄 License

This design system is part of the AgencyStack project.
