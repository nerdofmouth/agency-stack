# AgencyStack Design System

## 🎯 Design Philosophy

The AgencyStack Design System is built on principles of sovereignty, consistency, and user empowerment. It aims to provide a unified visual language across all components of the AgencyStack ecosystem while maintaining the flexibility required for multi-tenant deployments.

### Core Principles

1. **Sovereignty First**: Components are designed to function independently without external dependencies or tracking. All assets, styles, and functionality are self-contained within the system.

2. **Composition Over Inheritance**: The design system favors composition patterns, allowing components to be assembled and customized rather than extended.

3. **Accessibility by Default**: All components meet WCAG 2.1 AA standards out of the box, ensuring that AgencyStack is usable by everyone.

4. **Themeable & Adaptable**: Support for tenant-specific theming, dark/light modes, and responsive design is built into the core of the system.

5. **Performance Optimized**: Components are built with performance in mind, using code-splitting, tree-shaking, and optimized assets.

6. **Developer Experience**: Simple, intuitive APIs that are well-documented and type-safe.

7. **AI-Ready Interfaces**: Components are designed to work seamlessly with AI-driven workflows, providing clear interaction points for autonomous agents.

## 🧩 Component Categories

### Foundational Elements
- **Typography**: Headings, body text, captions
- **Colors**: Primary, secondary, accent, and semantic colors
- **Spacing**: Consistent spacing units
- **Icons**: Custom icon set for AgencyStack

### UI Components
- **StatusCard**: Displays component status with appropriate visual indicators
- **LogViewer**: Real-time log viewing with search and filtering
- **MetricsPanel**: Displays component metrics and performance indicators
- **EmbeddedAppFrame**: Secure iframe for embedding third-party components
- **ComponentPanel**: Container for component-specific controls and information

### Layout Components
- **Grid**: Responsive grid system for dashboard layouts
- **Stack**: Vertical and horizontal stacking components
- **Sidebar**: Collapsible sidebar for navigation

## 🔧 Usage

The Design System is implemented using NextJS 14, TailwindCSS, and TypeScript, with UI primitives from ShadCN/Radix for accessible interactions.

Component usage is documented in each component file, with examples and API references.

## 🎨 Theming

The system reads tenant-specific theme configuration from:
```
/opt/agency_stack/clients/${CLIENT_ID}/config/theme.json
```

This file contains color schemes, typography preferences, and other tenant-specific customizations.

## 📦 Integration

To use the Design System in an AgencyStack component:

```tsx
import { StatusCard, LogViewer } from \"@agency-stack/design-system\";

function MyComponent() {
  return (
    <StatusCard status=\"running\" name=\"Kill Bill\" />
  );
}
```

## 🧪 Development

Follow standard AgencyStack development practices. All components should be fully tested and documented before being added to the system.
