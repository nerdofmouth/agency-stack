import React from 'react';
import { useTheme } from '../../hooks/useTheme';

export interface MetricItem {
  /** Unique identifier for the metric */
  id: string;
  /** Display name for the metric */
  name: string;
  /** Current value of the metric */
  value: number | string;
  /** Optional unit to display (%, MB, req/s, etc.) */
  unit?: string;
  /** Previous value for comparison */
  previousValue?: number | string;
  /** Optional threshold values for visual indicators */
  thresholds?: {
    warning?: number;
    critical?: number;
  };
  /** Whether higher values are better (true) or worse (false) */
  higherIsBetter?: boolean;
  /** Optional category for grouping */
  category?: string;
}

export interface MetricsPanelProps {
  /** Title for the metrics panel */
  title: string;
  /** Array of metrics to display */
  metrics: MetricItem[];
  /** Optional timestamp of last update */
  lastUpdated?: string | Date;
  /** Whether to display metrics in a compact view */
  compact?: boolean;
  /** Optional function to refresh metrics */
  onRefresh?: () => void;
  /** Optional CSS class name */
  className?: string;
}

/**
 * MetricsPanel component displays a collection of metrics with visual
 * indicators for status and trends.
 */
export const MetricsPanel: React.FC<MetricsPanelProps> = ({
  title,
  metrics,
  lastUpdated,
  compact = false,
  onRefresh,
  className = '',
}) => {
  const { colors } = useTheme();
  
  const getMetricStatus = (metric: MetricItem): 'normal' | 'warning' | 'critical' => {
    // Skip status check if no thresholds defined
    if (!metric.thresholds) return 'normal';
    
    const value = typeof metric.value === 'string' ? parseFloat(metric.value) : metric.value;
    if (isNaN(value)) return 'normal';
    
    const { warning, critical } = metric.thresholds;
    const higherIsBetter = metric.higherIsBetter ?? false;
    
    if (critical !== undefined) {
      if (higherIsBetter && value < critical) return 'critical';
      if (!higherIsBetter && value > critical) return 'critical';
    }
    
    if (warning !== undefined) {
      if (higherIsBetter && value < warning) return 'warning';
      if (!higherIsBetter && value > warning) return 'warning';
    }
    
    return 'normal';
  };
  
  const getMetricStatusStyles = (status: 'normal' | 'warning' | 'critical') => {
    switch (status) {
      case 'critical':
        return 'text-destructive';
      case 'warning':
        return 'text-warning';
      default:
        return 'text-foreground';
    }
  };
  
  const getMetricTrend = (metric: MetricItem): 'up' | 'down' | 'neutral' => {
    if (metric.previousValue === undefined) return 'neutral';
    
    const current = typeof metric.value === 'string' ? parseFloat(metric.value) : metric.value;
    const previous = typeof metric.previousValue === 'string' 
      ? parseFloat(metric.previousValue) 
      : metric.previousValue;
    
    if (isNaN(current) || isNaN(previous)) return 'neutral';
    
    if (current > previous) return 'up';
    if (current < previous) return 'down';
    return 'neutral';
  };
  
  const getTrendIcon = (trend: 'up' | 'down' | 'neutral', higherIsBetter: boolean = false) => {
    if (trend === 'neutral') return '•';
    
    // Determine if trend is positive based on higher-is-better setting
    const isPositive = (trend === 'up' && higherIsBetter) || (trend === 'down' && !higherIsBetter);
    
    if (trend === 'up') {
      return isPositive ? '↑' : '↑';
    } else {
      return isPositive ? '↓' : '↓';
    }
  };
  
  const getTrendStyle = (trend: 'up' | 'down' | 'neutral', higherIsBetter: boolean = false) => {
    if (trend === 'neutral') return 'text-muted-foreground';
    
    const isPositive = (trend === 'up' && higherIsBetter) || (trend === 'down' && !higherIsBetter);
    
    return isPositive ? 'text-success' : 'text-destructive';
  };
  
  // Group metrics by category if present
  const groupedMetrics: Record<string, MetricItem[]> = {};
  
  metrics.forEach(metric => {
    const category = metric.category || 'General';
    if (!groupedMetrics[category]) {
      groupedMetrics[category] = [];
    }
    groupedMetrics[category].push(metric);
  });
  
  const categories = Object.keys(groupedMetrics);
  
  return (
    <div className={`rounded-lg border border-border bg-card p-4 shadow-sm ${className}`}>
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-medium text-card-foreground">{title}</h3>
        {onRefresh && (
          <button 
            onClick={onRefresh}
            className="flex items-center gap-1 rounded bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-secondary hover:text-secondary-foreground"
          >
            <span>↻</span>
            <span>Refresh</span>
          </button>
        )}
      </div>
      
      {lastUpdated && (
        <div className="mb-4 text-xs text-muted-foreground">
          Last updated: {typeof lastUpdated === 'string' 
            ? new Date(lastUpdated).toLocaleString() 
            : lastUpdated.toLocaleString()}
        </div>
      )}
      
      {compact ? (
        // Compact layout
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
          {metrics.map(metric => {
            const status = getMetricStatus(metric);
            const trend = getMetricTrend(metric);
            
            return (
              <div key={metric.id} className="flex flex-col">
                <span className="text-xs text-muted-foreground">{metric.name}</span>
                <div className="flex items-center gap-1">
                  <span className={`text-lg font-medium ${getMetricStatusStyles(status)}`}>
                    {metric.value}
                    {metric.unit && <span className="text-xs">{metric.unit}</span>}
                  </span>
                  {metric.previousValue !== undefined && (
                    <span className={`text-sm ${getTrendStyle(trend, metric.higherIsBetter)}`}>
                      {getTrendIcon(trend, metric.higherIsBetter)}
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        // Detailed layout with categories
        <div className="space-y-6">
          {categories.map(category => (
            <div key={category}>
              <h4 className="mb-2 text-sm font-medium text-muted-foreground">{category}</h4>
              <div className="space-y-2">
                {groupedMetrics[category].map(metric => {
                  const status = getMetricStatus(metric);
                  const trend = getMetricTrend(metric);
                  
                  return (
                    <div 
                      key={metric.id} 
                      className="flex items-center justify-between rounded border border-border bg-card p-2"
                    >
                      <span className="text-sm text-foreground">{metric.name}</span>
                      <div className="flex items-center gap-2">
                        {metric.previousValue !== undefined && (
                          <span className={`text-xs ${getTrendStyle(trend, metric.higherIsBetter)}`}>
                            {getTrendIcon(trend, metric.higherIsBetter)}
                          </span>
                        )}
                        <span className={`text-base font-medium ${getMetricStatusStyles(status)}`}>
                          {metric.value}
                          {metric.unit && <span className="ml-0.5 text-xs">{metric.unit}</span>}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default MetricsPanel;
