import React, { useState } from 'react';
import { useTheme } from '../../hooks/useTheme';
import StatusCard, { ComponentStatus } from './StatusCard';
import LogViewer, { LogEntry } from './LogViewer';
import MetricsPanel, { MetricItem } from './MetricsPanel';
import EmbeddedAppFrame from './EmbeddedAppFrame';

export interface ComponentAction {
  /** Unique ID for the action */
  id: string;
  /** Display label for the action button */
  label: string;
  /** Icon or emoji for the action */
  icon?: string;
  /** Optional description */
  description?: string;
  /** Whether action is currently disabled */
  disabled?: boolean;
  /** Handler function when the action is clicked */
  onClick: () => void;
}

export interface ComponentPanelTab {
  /** Unique ID for the tab */
  id: string;
  /** Display label for the tab */
  label: string;
  /** Component to render in the tab */
  content: React.ReactNode;
}

export interface ComponentPanelProps {
  /** Component name */
  name: string;
  /** Component description */
  description?: string;
  /** Current status of the component */
  status: ComponentStatus;
  /** Last updated timestamp */
  lastUpdated?: string | Date;
  /** Optional array of logs for the component */
  logs?: LogEntry[];
  /** Optional array of metrics for the component */
  metrics?: MetricItem[];
  /** Optional embedded application URL */
  embeddedAppUrl?: string;
  /** Available actions for this component */
  actions?: ComponentAction[];
  /** Additional tabs beyond the default ones */
  additionalTabs?: ComponentPanelTab[];
  /** Optional CSS class name */
  className?: string;
  /** Callback for log fetching */
  onFetchLogs?: () => void;
  /** Callback for metric fetching */
  onFetchMetrics?: () => void;
}

/**
 * ComponentPanel acts as a container for component-specific controls, information,
 * logs, metrics, and embedded interfaces. It provides a consistent layout and UX
 * for managing different types of components.
 */
export const ComponentPanel: React.FC<ComponentPanelProps> = ({
  name,
  description,
  status,
  lastUpdated,
  logs = [],
  metrics = [],
  embeddedAppUrl,
  actions = [],
  additionalTabs = [],
  className = '',
  onFetchLogs,
  onFetchMetrics,
}) => {
  const { colors, isDarkMode } = useTheme();
  const [activeTab, setActiveTab] = useState('overview');
  
  // Define default tabs
  const defaultTabs: ComponentPanelTab[] = [
    {
      id: 'overview',
      label: 'Overview',
      content: (
        <div className="space-y-6">
          <StatusCard
            name={name}
            status={status}
            description={description}
            lastUpdated={lastUpdated}
          />
          
          {metrics.length > 0 && (
            <MetricsPanel
              title={`${name} Metrics`}
              metrics={metrics}
              lastUpdated={lastUpdated}
              compact={true}
              onRefresh={onFetchMetrics}
            />
          )}
          
          {logs.length > 0 && (
            <div className="h-64">
              <LogViewer
                logs={logs.slice(-5)} // Show only last 5 logs on overview
                maxEntries={5}
                enableFiltering={false}
                enableSearch={false}
                onFetchMore={onFetchLogs}
              />
            </div>
          )}
        </div>
      ),
    },
  ];
  
  // Add logs tab if logs are provided
  if (logs.length > 0) {
    defaultTabs.push({
      id: 'logs',
      label: 'Logs',
      content: (
        <div className="h-[600px]">
          <LogViewer
            logs={logs}
            onFetchMore={onFetchLogs}
          />
        </div>
      ),
    });
  }
  
  // Add metrics tab if metrics are provided
  if (metrics.length > 0) {
    defaultTabs.push({
      id: 'metrics',
      label: 'Metrics',
      content: (
        <MetricsPanel
          title={`${name} Metrics`}
          metrics={metrics}
          lastUpdated={lastUpdated}
          onRefresh={onFetchMetrics}
        />
      ),
    });
  }
  
  // Add admin tab if embeddedAppUrl is provided
  if (embeddedAppUrl) {
    defaultTabs.push({
      id: 'admin',
      label: 'Admin',
      content: (
        <EmbeddedAppFrame
          src={embeddedAppUrl}
          title={`${name} Admin Interface`}
          height="600px"
        />
      ),
    });
  }
  
  // Combine default and additional tabs
  const allTabs = [...defaultTabs, ...additionalTabs];
  
  return (
    <div className={`rounded-lg border border-border bg-card shadow-sm ${className}`}>
      {/* Header with actions */}
      <div className="border-b border-border p-4">
        <div className="flex flex-col space-y-4 sm:flex-row sm:items-center sm:justify-between sm:space-y-0">
          <div>
            <h2 className="text-2xl font-bold text-card-foreground">{name}</h2>
            {description && (
              <p className="mt-1 text-sm text-muted-foreground">{description}</p>
            )}
          </div>
          
          {actions.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {actions.map(action => (
                <button
                  key={action.id}
                  onClick={action.onClick}
                  disabled={action.disabled}
                  className={`inline-flex items-center gap-1.5 rounded-md px-3 py-2 text-sm font-medium shadow-sm
                    ${action.disabled
                      ? 'cursor-not-allowed bg-muted text-muted-foreground opacity-50'
                      : 'bg-primary text-primary-foreground hover:bg-primary/90'
                    }`}
                  title={action.description}
                >
                  {action.icon && <span>{action.icon}</span>}
                  {action.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
      
      {/* Tab navigation */}
      <div className="border-b border-border bg-muted">
        <div className="flex overflow-x-auto">
          {allTabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-3 text-sm font-medium transition-colors
                ${activeTab === tab.id
                  ? 'border-b-2 border-primary text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
                }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>
      
      {/* Tab content */}
      <div className="p-4">
        {allTabs.find(tab => tab.id === activeTab)?.content}
      </div>
    </div>
  );
};

export default ComponentPanel;
