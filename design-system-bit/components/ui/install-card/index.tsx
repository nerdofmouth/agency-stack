import React, { useState, useEffect } from 'react';

export type InstallStatus = 'running' | 'failed' | 'installing' | 'restarting' | 'unknown';

export interface InstallCardProps {
  /** The name of the component being installed */
  name: string;
  /** Current installation status */
  status: InstallStatus;
  /** Last updated timestamp */
  lastUpdated?: string | Date;
  /** Optional description of the component */
  description?: string;
  /** Optional version of the component */
  version?: string;
  /** Optional callback when user clicks to view logs */
  onViewLogs?: () => void;
  /** Optional callback when user clicks to view metrics */
  onViewMetrics?: () => void;
  /** Optional callback when user clicks to restart the installation */
  onRestart?: () => void;
  /** Whether the install-card is in compact mode */
  compact?: boolean;
  /** Client ID for multi-tenant deployments */
  clientId?: string;
  /** Additional CSS classes */
  className?: string;
}

/**
 * InstallCard displays the installation status of an AgencyStack component
 * with actions to view logs, metrics, and manage installation.
 * 
 * This component follows the AgencyStack Alpha Phase Directives and
 * integrates with the system's logging and monitoring.
 */
export function InstallCard({
  name,
  status,
  lastUpdated,
  description,
  version,
  onViewLogs,
  onViewMetrics,
  onRestart,
  compact = false,
  clientId = 'default',
  className = '',
}: InstallCardProps) {
  const [isLogging, setIsLogging] = useState(false);

  // Status indicator colors and icons
  const statusConfig = {
    running: { 
      bgColor: 'bg-success', 
      textColor: 'text-success-foreground',
      icon: '✅',
      label: 'Running'
    },
    installing: { 
      bgColor: 'bg-info', 
      textColor: 'text-info-foreground',
      icon: '⏳',
      label: 'Installing'
    },
    restarting: { 
      bgColor: 'bg-warning', 
      textColor: 'text-warning-foreground',
      icon: '🔄',
      label: 'Restarting'
    },
    failed: { 
      bgColor: 'bg-destructive', 
      textColor: 'text-destructive-foreground',
      icon: '❌',
      label: 'Failed'
    },
    unknown: { 
      bgColor: 'bg-muted', 
      textColor: 'text-muted-foreground',
      icon: '❓',
      label: 'Unknown'
    },
  };

  const { bgColor, textColor, icon, label } = statusConfig[status];
  
  // Format last updated date if provided
  const formattedDate = lastUpdated 
    ? new Date(lastUpdated).toLocaleString() 
    : 'Not available';

  // Log usage to system log
  useEffect(() => {
    const logUsage = async () => {
      if (isLogging) return;
      
      setIsLogging(true);
      
      try {
        // In a real implementation, this would log to /var/log/agency_stack/ui/install-card.log
        // For now, we'll just log to console
        console.log(`[InstallCard] Component "${name}" with status "${status}" viewed for client "${clientId}"`);
        
        // In a real implementation, this would be an API call:
        // await fetch('/api/log', {
        //   method: 'POST',
        //   body: JSON.stringify({
        //     component: 'install-card',
        //     action: 'view',
        //     details: { name, status, clientId }
        //   })
        // });
      } catch (error) {
        console.error('[InstallCard] Failed to log usage:', error);
      } finally {
        setIsLogging(false);
      }
    };
    
    logUsage();
  }, [name, status, clientId, isLogging]);

  // Compact view for dashboard/grid layouts
  if (compact) {
    return (
      <div className={`rounded-lg border border-border bg-card p-3 shadow-sm hover:shadow-md transition-shadow ${className}`}>
        <div className="flex items-center justify-between mb-2">
          <div className="font-medium truncate">{name}</div>
          <div className={`flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${bgColor} ${textColor}`}>
            <span>{icon}</span>
          </div>
        </div>
        {version && (
          <div className="text-xs text-muted-foreground">v{version}</div>
        )}
      </div>
    );
  }

  // Full view with actions
  return (
    <div className={`rounded-lg border border-border bg-card p-4 shadow-sm hover:shadow-md transition-shadow ${className}`}>
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-medium text-card-foreground">{name}</h3>
        <div className={`flex items-center gap-2 rounded-full px-3 py-1 text-sm ${bgColor} ${textColor}`}>
          <span className="text-base">{icon}</span>
          <span>{label}</span>
        </div>
      </div>
      
      {description && (
        <p className="mt-2 text-sm text-muted-foreground">{description}</p>
      )}
      
      {version && (
        <div className="mt-1 text-xs text-muted-foreground">Version: {version}</div>
      )}
      
      <div className="mt-3 text-xs text-muted-foreground">
        Last updated: {formattedDate}
      </div>
      
      <div className="mt-4 flex gap-2">
        {onViewLogs && (
          <button 
            onClick={onViewLogs}
            className="inline-flex items-center rounded border border-border bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-secondary hover:text-secondary-foreground"
          >
            <span className="mr-1">📋</span> Logs
          </button>
        )}
        {onViewMetrics && (
          <button 
            onClick={onViewMetrics}
            className="inline-flex items-center rounded border border-border bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-secondary hover:text-secondary-foreground"
          >
            <span className="mr-1">📊</span> Metrics
          </button>
        )}
        {onRestart && status !== 'installing' && status !== 'restarting' && (
          <button 
            onClick={onRestart}
            className="inline-flex items-center rounded border border-border bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-secondary hover:text-secondary-foreground"
          >
            <span className="mr-1">🔄</span> Restart
          </button>
        )}
      </div>
    </div>
  );
}
