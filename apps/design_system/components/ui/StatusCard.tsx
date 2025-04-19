import React from 'react';
import { useTheme } from '../../hooks/useTheme';

export type ComponentStatus = 'running' | 'stopped' | 'warning' | 'error' | 'unknown';

export interface StatusCardProps {
  /** The name of the component */
  name: string;
  /** Current status of the component */
  status: ComponentStatus;
  /** Optional description text */
  description?: string;
  /** Last time the status was updated (ISO string or Date object) */
  lastUpdated?: string | Date;
  /** Optional click handler */
  onClick?: () => void;
  /** Optional className for extending styles */
  className?: string;
}

/**
 * StatusCard component displays the current status of a system component
 * with appropriate visual indicators based on status.
 */
export const StatusCard: React.FC<StatusCardProps> = ({
  name,
  status,
  description,
  lastUpdated,
  onClick,
  className = '',
}) => {
  const { colors } = useTheme();
  
  // Status indicator colors and icons
  const statusConfig = {
    running: { 
      bgColor: 'bg-success', 
      textColor: 'text-success-foreground',
      icon: '✓',
      label: 'Running'
    },
    stopped: { 
      bgColor: 'bg-muted', 
      textColor: 'text-muted-foreground',
      icon: '◼',
      label: 'Stopped'
    },
    warning: { 
      bgColor: 'bg-warning', 
      textColor: 'text-warning-foreground',
      icon: '⚠',
      label: 'Warning'
    },
    error: { 
      bgColor: 'bg-destructive', 
      textColor: 'text-destructive-foreground',
      icon: '✗',
      label: 'Error'
    },
    unknown: { 
      bgColor: 'bg-muted', 
      textColor: 'text-muted-foreground',
      icon: '?',
      label: 'Unknown'
    },
  };

  const { bgColor, textColor, icon, label } = statusConfig[status];
  
  // Format last updated date if provided
  const formattedDate = lastUpdated 
    ? new Date(lastUpdated).toLocaleString() 
    : 'Not available';

  return (
    <div 
      className={`rounded-lg border border-border bg-card p-4 shadow-sm transition-all hover:shadow-md ${className}`}
      onClick={onClick}
      role={onClick ? 'button' : 'region'}
      tabIndex={onClick ? 0 : undefined}
    >
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
      
      <div className="mt-3 text-xs text-muted-foreground">
        Last updated: {formattedDate}
      </div>
    </div>
  );
};

export default StatusCard;
