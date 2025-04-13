import React, { useState, useEffect } from 'react';
import { useTheme } from '../../hooks/useTheme';

export interface LogEntry {
  /** Unique identifier for the log entry */
  id: string;
  /** Timestamp (ISO string or Date object) */
  timestamp: string | Date;
  /** Log level (info, warn, error, debug) */
  level: 'info' | 'warn' | 'error' | 'debug';
  /** The log message content */
  message: string;
  /** Optional source (component, service name) */
  source?: string;
  /** Any additional metadata for the log entry */
  metadata?: Record<string, any>;
}

export interface LogViewerProps {
  /** Array of log entries to display */
  logs: LogEntry[];
  /** Maximum number of logs to show (scrolls automatically) */
  maxEntries?: number;
  /** Whether to auto-scroll to bottom on new entries */
  autoScroll?: boolean;
  /** Optional function to fetch more logs (pagination) */
  onFetchMore?: () => void;
  /** Allow filtering logs by level */
  enableFiltering?: boolean;
  /** Allow searching log content */
  enableSearch?: boolean;
  /** Optional CSS class name */
  className?: string;
}

/**
 * LogViewer component displays log entries with syntax highlighting and filtering
 * capabilities for monitoring component activity.
 */
export const LogViewer: React.FC<LogViewerProps> = ({
  logs,
  maxEntries = 100,
  autoScroll = true,
  onFetchMore,
  enableFiltering = true,
  enableSearch = true,
  className = '',
}) => {
  const { colors } = useTheme();
  const [filteredLogs, setFilteredLogs] = useState<LogEntry[]>(logs);
  const [searchTerm, setSearchTerm] = useState('');
  const [levelFilter, setLevelFilter] = useState<string[]>(['info', 'warn', 'error', 'debug']);
  const logEndRef = React.useRef<HTMLDivElement>(null);
  
  // Apply filters and search when logs, filters or search terms change
  useEffect(() => {
    let result = logs;
    
    // Apply level filtering
    if (levelFilter.length < 4) {
      result = result.filter(log => levelFilter.includes(log.level));
    }
    
    // Apply search
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      result = result.filter(log => 
        log.message.toLowerCase().includes(term) || 
        (log.source && log.source.toLowerCase().includes(term))
      );
    }
    
    // Limit to max entries
    if (result.length > maxEntries) {
      result = result.slice(result.length - maxEntries);
    }
    
    setFilteredLogs(result);
  }, [logs, levelFilter, searchTerm, maxEntries]);
  
  // Auto-scroll to bottom when new logs are added
  useEffect(() => {
    if (autoScroll && logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [filteredLogs, autoScroll]);
  
  // Get appropriate styling for log level
  const getLevelStyles = (level: string) => {
    switch(level) {
      case 'error':
        return 'text-destructive font-semibold';
      case 'warn':
        return 'text-warning font-semibold';
      case 'info':
        return 'text-info';
      case 'debug':
        return 'text-muted-foreground';
      default:
        return 'text-foreground';
    }
  };
  
  const toggleLevelFilter = (level: string) => {
    if (levelFilter.includes(level)) {
      // Remove level if only one is left
      if (levelFilter.length > 1) {
        setLevelFilter(levelFilter.filter(l => l !== level));
      }
    } else {
      setLevelFilter([...levelFilter, level]);
    }
  };
  
  const formatTimestamp = (timestamp: string | Date) => {
    return new Date(timestamp).toLocaleTimeString();
  };
  
  return (
    <div className={`flex flex-col rounded-lg border border-border bg-card shadow-sm ${className}`}>
      {/* Header with filters and search */}
      {(enableFiltering || enableSearch) && (
        <div className="border-b border-border p-3">
          <div className="flex flex-wrap items-center gap-2">
            {enableFiltering && (
              <div className="flex flex-wrap gap-1">
                <span className="text-sm text-muted-foreground">Filter:</span>
                {['info', 'warn', 'error', 'debug'].map(level => (
                  <button
                    key={level}
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      levelFilter.includes(level) 
                        ? getLevelStyles(level) + ' bg-muted' 
                        : 'text-muted-foreground'
                    }`}
                    onClick={() => toggleLevelFilter(level)}
                  >
                    {level}
                  </button>
                ))}
              </div>
            )}
            
            {enableSearch && (
              <div className="ml-auto flex">
                <input
                  type="text"
                  value={searchTerm}
                  onChange={e => setSearchTerm(e.target.value)}
                  placeholder="Search logs..."
                  className="h-8 rounded-md border border-input bg-background px-2 text-sm text-foreground focus:border-ring focus:outline-none"
                />
                {searchTerm && (
                  <button 
                    className="ml-1 rounded-md bg-muted p-1 text-xs text-muted-foreground"
                    onClick={() => setSearchTerm('')}
                  >
                    Clear
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      )}
      
      {/* Log entries container */}
      <div className="flex-1 overflow-y-auto p-1">
        <pre className="font-mono text-xs leading-tight">
          {filteredLogs.length > 0 ? (
            <div className="space-y-1">
              {filteredLogs.map(log => (
                <div key={log.id} className="rounded p-1 hover:bg-muted">
                  <span className="text-muted-foreground">[{formatTimestamp(log.timestamp)}]</span>
                  {log.source && (
                    <span className="text-accent-foreground"> {log.source}: </span>
                  )}
                  <span className={getLevelStyles(log.level)}>
                    [{log.level.toUpperCase()}]
                  </span>
                  <span className="ml-1 text-foreground">{log.message}</span>
                  
                  {log.metadata && Object.keys(log.metadata).length > 0 && (
                    <div className="mt-1 text-muted-foreground">
                      {JSON.stringify(log.metadata, null, 2)}
                    </div>
                  )}
                </div>
              ))}
              <div ref={logEndRef} />
            </div>
          ) : (
            <div className="p-4 text-center text-muted-foreground">
              No logs matching current filters
            </div>
          )}
        </pre>
      </div>
      
      {/* Footer with controls */}
      <div className="border-t border-border p-2">
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground">
            Showing {filteredLogs.length} {filteredLogs.length === 1 ? 'entry' : 'entries'}
          </span>
          <div className="flex gap-2">
            <button 
              className="rounded bg-muted px-2 py-1 text-xs text-muted-foreground hover:bg-secondary hover:text-secondary-foreground"
              onClick={() => {
                // Clear filters and search
                setLevelFilter(['info', 'warn', 'error', 'debug']);
                setSearchTerm('');
              }}
            >
              Reset Filters
            </button>
            {onFetchMore && (
              <button 
                className="rounded bg-secondary px-2 py-1 text-xs text-secondary-foreground"
                onClick={onFetchMore}
              >
                Load More
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default LogViewer;
