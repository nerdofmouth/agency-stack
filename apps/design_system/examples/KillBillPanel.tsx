import React, { useState, useEffect } from 'react';
import { ComponentPanel } from '../components/ui/ComponentPanel';
import { LogEntry } from '../components/ui/LogViewer';
import { MetricItem } from '../components/ui/MetricsPanel';
import { useTheme } from '../hooks/useTheme';

export default function KillBillPanel() {
  const { setClientTheme, isDarkMode, setDarkMode } = useTheme();
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [metrics, setMetrics] = useState<MetricItem[]>([]);
  const [status, setStatus] = useState<'running' | 'stopped' | 'warning' | 'error'>('running');
  
  // Example of loading client-specific theme
  useEffect(() => {
    // In a real implementation, this would get the client ID from context or config
    const clientId = 'client1';
    setClientTheme(clientId);
  }, [setClientTheme]);
  
  // Simulate fetching logs
  const fetchLogs = () => {
    // In a real implementation, this would make an API call
    const newLogs: LogEntry[] = [
      {
        id: `log-${Date.now()}-1`,
        timestamp: new Date(),
        level: 'info',
        message: 'Kill Bill invoice generation completed',
        source: 'killbill-server',
      },
      {
        id: `log-${Date.now()}-2`,
        timestamp: new Date(),
        level: 'debug',
        message: 'Processing subscription renewal',
        source: 'subscription-service',
      },
      {
        id: `log-${Date.now()}-3`,
        timestamp: new Date(Date.now() - 60000),
        level: 'warn',
        message: 'Payment retries threshold reached for account XYZ',
        source: 'payment-service',
        metadata: {
          accountId: 'acc-12345',
          attempts: 3,
        },
      },
    ];
    
    setLogs(prev => [...prev, ...newLogs]);
  };
  
  // Simulate fetching metrics
  const fetchMetrics = () => {
    // In a real implementation, this would make an API call
    const updatedMetrics: MetricItem[] = [
      {
        id: 'active-accounts',
        name: 'Active Accounts',
        value: 1248,
        previousValue: 1235,
        higherIsBetter: true,
        category: 'Business',
      },
      {
        id: 'mrr',
        name: 'Monthly Recurring Revenue',
        value: 12560,
        unit: '$',
        previousValue: 12350,
        higherIsBetter: true,
        category: 'Business',
      },
      {
        id: 'cpu-usage',
        name: 'CPU Usage',
        value: 42,
        unit: '%',
        previousValue: 38,
        thresholds: {
          warning: 70,
          critical: 90,
        },
        higherIsBetter: false,
        category: 'System',
      },
      {
        id: 'memory-usage',
        name: 'Memory Usage',
        value: 768,
        unit: 'MB',
        previousValue: 715,
        thresholds: {
          warning: 1500,
          critical: 2000,
        },
        higherIsBetter: false,
        category: 'System',
      },
      {
        id: 'api-latency',
        name: 'API Latency',
        value: 235,
        unit: 'ms',
        previousValue: 242,
        thresholds: {
          warning: 500,
          critical: 1000,
        },
        higherIsBetter: false,
        category: 'Performance',
      },
    ];
    
    setMetrics(updatedMetrics);
  };
  
  // Initial data fetch
  useEffect(() => {
    fetchLogs();
    fetchMetrics();
  }, []);
  
  // Define available actions for the component
  const actions = [
    {
      id: 'restart',
      label: 'Restart',
      icon: '🔄',
      description: 'Restart the Kill Bill service',
      onClick: () => {
        // Simulate restarting the service
        setStatus('warning');
        setTimeout(() => {
          setStatus('running');
          fetchLogs();
          fetchMetrics();
        }, 3000);
      },
    },
    {
      id: 'clear-cache',
      label: 'Clear Cache',
      icon: '🧹',
      description: 'Clear Kill Bill cache',
      onClick: () => {
        // Simulate clearing cache
        const clearLog: LogEntry = {
          id: `log-${Date.now()}`,
          timestamp: new Date(),
          level: 'info',
          message: 'Cache cleared successfully',
          source: 'admin-action',
        };
        setLogs(prev => [...prev, clearLog]);
      },
    },
    {
      id: 'toggle-theme',
      label: isDarkMode ? 'Light Mode' : 'Dark Mode',
      icon: isDarkMode ? '☀️' : '🌙',
      description: 'Toggle light/dark theme',
      onClick: () => setDarkMode(!isDarkMode),
    },
  ];
  
  return (
    <div className="container mx-auto py-6">
      <ComponentPanel
        name="Kill Bill"
        description="Open-source subscription billing and payment platform"
        status={status}
        lastUpdated={new Date()}
        logs={logs}
        metrics={metrics}
        embeddedAppUrl="https://killbill.example.com:9090/kaui"
        actions={actions}
        onFetchLogs={fetchLogs}
        onFetchMetrics={fetchMetrics}
        className="mb-6"
      />
      
      <div className="text-sm text-muted-foreground mt-4">
        <p>
          Note: This is a demonstration of the AgencyStack Design System components. 
          In a production environment, data would be fetched from actual services.
        </p>
      </div>
    </div>
  );
}
