'use client';

import React, { useState } from 'react';
import { useTheme } from '../hooks/useTheme';
import { StatusCard } from '../components/ui/StatusCard';
import { LogViewer } from '../components/ui/LogViewer';
import { MetricsPanel } from '../components/ui/MetricsPanel';
import { EmbeddedAppFrame } from '../components/ui/EmbeddedAppFrame';
import KillBillPanel from '../examples/KillBillPanel';

export default function HomePage() {
  const { isDarkMode, setDarkMode, setClientTheme } = useTheme();
  const [clientId, setClientId] = useState('default');
  
  // Sample data for demonstration
  const sampleLogs = [
    {
      id: '1',
      timestamp: new Date(Date.now() - 3600000),
      level: 'info',
      message: 'System startup complete',
      source: 'system',
    },
    {
      id: '2',
      timestamp: new Date(Date.now() - 1800000),
      level: 'debug',
      message: 'Configuration loaded from /opt/agency_stack/config.json',
      source: 'config-service',
    },
    {
      id: '3',
      timestamp: new Date(Date.now() - 900000),
      level: 'warn',
      message: 'High memory usage detected',
      source: 'monitoring',
      metadata: {
        usage: '85%',
        threshold: '80%',
      },
    },
    {
      id: '4',
      timestamp: new Date(Date.now() - 300000),
      level: 'error',
      message: 'Failed to connect to database',
      source: 'database',
      metadata: {
        error: 'Connection timeout',
        retries: 3,
      },
    },
    {
      id: '5',
      timestamp: new Date(),
      level: 'info',
      message: 'User logged in',
      source: 'auth-service',
      metadata: {
        userId: 'user-123',
      },
    },
  ];
  
  const sampleMetrics = [
    {
      id: 'users',
      name: 'Active Users',
      value: 1234,
      previousValue: 1200,
      higherIsBetter: true,
      category: 'Usage',
    },
    {
      id: 'cpu',
      name: 'CPU Usage',
      value: 45,
      unit: '%',
      previousValue: 50,
      thresholds: {
        warning: 70,
        critical: 90,
      },
      higherIsBetter: false,
      category: 'System',
    },
    {
      id: 'memory',
      name: 'Memory Usage',
      value: 2.4,
      unit: 'GB',
      previousValue: 2.1,
      thresholds: {
        warning: 3.5,
        critical: 4,
      },
      higherIsBetter: false,
      category: 'System',
    },
  ];
  
  const handleClientChange = (newClientId: string) => {
    setClientId(newClientId);
    setClientTheme(newClientId);
  };
  
  return (
    <div className="space-y-10">
      <section className="mb-8">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-3xl font-bold">AgencyStack Design System</h2>
          <div className="flex items-center gap-4">
            <select
              value={clientId}
              onChange={(e) => handleClientChange(e.target.value)}
              className="rounded-md border border-input bg-background px-3 py-2 text-sm"
            >
              <option value="default">Default Theme</option>
              <option value="client1">Client 1 Theme</option>
              <option value="client2">Client 2 Theme</option>
            </select>
            <button
              onClick={() => setDarkMode(!isDarkMode)}
              className="rounded-md bg-primary px-3 py-2 text-sm text-primary-foreground"
            >
              {isDarkMode ? '☀️ Light Mode' : '🌙 Dark Mode'}
            </button>
          </div>
        </div>
        <p className="mb-6 text-muted-foreground">
          This design system provides a consistent set of UI components for building
          AgencyStack interfaces. The components are designed to be accessible, themeable,
          and work well with Keycloak, Kill Bill, and other integrated services.
        </p>
        
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-lg border border-border bg-card p-4 shadow-sm">
            <h3 className="mb-2 text-lg font-medium">🎨 Themeable</h3>
            <p className="text-sm text-muted-foreground">
              Supports client-specific themes with dark mode and customizable colors
            </p>
          </div>
          <div className="rounded-lg border border-border bg-card p-4 shadow-sm">
            <h3 className="mb-2 text-lg font-medium">♿ Accessible</h3>
            <p className="text-sm text-muted-foreground">
              WCAG 2.1 AA compliant with keyboard navigation and screen reader support
            </p>
          </div>
          <div className="rounded-lg border border-border bg-card p-4 shadow-sm">
            <h3 className="mb-2 text-lg font-medium">🔐 Secure</h3>
            <p className="text-sm text-muted-foreground">
              Built with security best practices for embedded applications
            </p>
          </div>
        </div>
      </section>
      
      <section className="mb-8">
        <h2 className="mb-4 text-2xl font-bold">Basic Components</h2>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
          <StatusCard
            name="PeerTube"
            status="running"
            description="Video streaming platform"
            lastUpdated={new Date()}
          />
          <StatusCard
            name="Keycloak"
            status="warning"
            description="Identity and access management"
            lastUpdated={new Date(Date.now() - 1800000)}
          />
          <StatusCard
            name="Mailu"
            status="error"
            description="Email server"
            lastUpdated={new Date(Date.now() - 3600000)}
          />
        </div>
      </section>
      
      <section className="mb-8">
        <h2 className="mb-4 text-2xl font-bold">Log Viewer</h2>
        <div className="h-[400px]">
          <LogViewer
            logs={sampleLogs}
            enableFiltering={true}
            enableSearch={true}
            onFetchMore={() => console.log('Fetching more logs...')}
          />
        </div>
      </section>
      
      <section className="mb-8">
        <h2 className="mb-4 text-2xl font-bold">Metrics Panel</h2>
        <MetricsPanel
          title="System Metrics"
          metrics={sampleMetrics}
          lastUpdated={new Date()}
          onRefresh={() => console.log('Refreshing metrics...')}
        />
      </section>
      
      <section className="mb-8">
        <h2 className="mb-4 text-2xl font-bold">Embedded App Frame</h2>
        <div className="h-[400px]">
          <EmbeddedAppFrame
            src="https://example.com"
            title="Example External App"
            showHeader={true}
            showLoading={true}
          />
        </div>
      </section>
      
      <section className="mb-8">
        <h2 className="mb-4 text-2xl font-bold">Complete Component Example</h2>
        <KillBillPanel />
      </section>
    </div>
  );
}
