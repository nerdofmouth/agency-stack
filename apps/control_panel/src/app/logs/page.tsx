/**
 * Logs Page
 * 
 * View and filter system logs from AgencyStack components
 */

'use client';

import { useState, useEffect } from 'react';
import { useClientId } from '@/hooks/useClientId';

// Define log entry interface
interface LogEntry {
  id: string;
  timestamp: string;
  level: 'info' | 'warning' | 'error' | 'debug';
  source: string;
  message: string;
  details?: string;
  clientId?: string;
}

// Mock log data - in production, this would be loaded from a backend API
const mockLogs: LogEntry[] = [
  {
    id: 'log1',
    timestamp: '2025-04-05T14:32:11.000Z',
    level: 'info',
    source: 'system',
    message: 'System startup completed successfully',
    details: 'All core services initialized'
  },
  {
    id: 'log2',
    timestamp: '2025-04-05T14:33:22.000Z',
    level: 'warning',
    source: 'traefik',
    message: 'Certificate renewal approaching',
    details: 'Let\'s Encrypt certificate will expire in 14 days'
  },
  {
    id: 'log3',
    timestamp: '2025-04-05T14:40:05.000Z',
    level: 'error',
    source: 'n8n',
    message: 'Service failed to start',
    details: 'Container exited with code 1, see container logs for details'
  },
  {
    id: 'log4',
    timestamp: '2025-04-05T14:45:30.000Z',
    level: 'info',
    source: 'wordpress',
    message: 'Plugin updated',
    details: 'WooCommerce updated to version 8.1.0',
    clientId: 'client_alpha'
  },
  {
    id: 'log5',
    timestamp: '2025-04-05T14:50:11.000Z',
    level: 'info',
    source: 'backup',
    message: 'Backup completed',
    details: 'Daily backup completed successfully. Size: 256MB'
  },
  {
    id: 'log6',
    timestamp: '2025-04-05T15:01:45.000Z',
    level: 'debug',
    source: 'ai_system',
    message: 'AI system processing request',
    details: 'Processing content generation request for marketing campaign'
  },
  {
    id: 'log7',
    timestamp: '2025-04-05T15:10:22.000Z',
    level: 'info',
    source: 'ai_system',
    message: 'Content generation complete',
    details: 'Generated 5 marketing emails based on campaign parameters',
    clientId: 'client_beta'
  },
  {
    id: 'log8',
    timestamp: '2025-04-05T15:15:33.000Z',
    level: 'warning',
    source: 'database',
    message: 'High database load',
    details: 'Database CPU usage exceeded 80% for more than 5 minutes'
  },
  {
    id: 'log9',
    timestamp: '2025-04-05T15:20:18.000Z',
    level: 'error',
    source: 'erp',
    message: 'API integration failed',
    details: 'Failed to connect to external payment gateway: timeout',
    clientId: 'client_alpha'
  },
  {
    id: 'log10',
    timestamp: '2025-04-05T15:25:55.000Z',
    level: 'info',
    source: 'health',
    message: 'Health check passed',
    details: 'All services reported healthy status'
  }
];

export default function LogsPage() {
  const { clientId, isAdmin } = useClientId();
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [selectedSource, setSelectedSource] = useState<string | null>(null);
  const [selectedLevel, setSelectedLevel] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [autoRefresh, setAutoRefresh] = useState(false);
  const [showDetails, setShowDetails] = useState<string | null>(null);
  
  // Get unique log sources
  const sources = Array.from(new Set(mockLogs.map(log => log.source)));
  
  // Log levels for filtering
  const logLevels = ['info', 'warning', 'error', 'debug'];
  
  // Load logs on component mount and filter changes
  useEffect(() => {
    // In a real implementation, this would fetch logs from an API endpoint
    
    // Apply filters to the mock logs
    let filtered = [...mockLogs];
    
    // Filter by level
    if (selectedLevel) {
      filtered = filtered.filter(log => log.level === selectedLevel);
    }
    
    // Filter by source
    if (selectedSource) {
      filtered = filtered.filter(log => log.source === selectedSource);
    }
    
    // Filter by search term
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(log => 
        log.message.toLowerCase().includes(term) || 
        (log.details && log.details.toLowerCase().includes(term))
      );
    }
    
    // Filter by date range
    if (startDate) {
      const startTimestamp = new Date(startDate).getTime();
      filtered = filtered.filter(log => new Date(log.timestamp).getTime() >= startTimestamp);
    }
    
    if (endDate) {
      const endTimestamp = new Date(endDate).getTime();
      filtered = filtered.filter(log => new Date(log.timestamp).getTime() <= endTimestamp);
    }
    
    // If not admin, only show logs for current client
    if (!isAdmin()) {
      filtered = filtered.filter(log => !log.clientId || log.clientId === clientId);
    }
    
    // Sort by timestamp (newest first)
    filtered.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
    
    setLogs(filtered);
    
    // Set up auto-refresh
    let interval: NodeJS.Timeout;
    if (autoRefresh) {
      interval = setInterval(() => {
        // In a real implementation, this would fetch fresh logs
        // For the mock, we'll just re-apply the filters
        setLogs([...filtered]);
      }, 5000);
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [selectedLevel, selectedSource, searchTerm, startDate, endDate, autoRefresh, clientId, isAdmin]);
  
  // Get appropriate CSS class for log level
  const getLevelClass = (level: string) => {
    const baseClasses = "text-xs font-medium px-2.5 py-0.5 rounded-full";
    
    const levelClasses = {
      info: `${baseClasses} bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200`,
      warning: `${baseClasses} bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200`,
      error: `${baseClasses} bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200`,
      debug: `${baseClasses} bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200`
    };
    
    return levelClasses[level as keyof typeof levelClasses] || levelClasses.info;
  };
  
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-agency-800 dark:text-agency-100">
          System Logs
        </h1>
        <p className="mt-1 text-agency-600 dark:text-agency-300">
          View and filter audit, health, and AI system logs
        </p>
      </div>
      
      {/* Filters */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Log Source Filter */}
        <div>
          <select
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={selectedSource || ''}
            onChange={(e) => setSelectedSource(e.target.value === '' ? null : e.target.value)}
          >
            <option value="">All Sources</option>
            {sources.map((source) => (
              <option key={source} value={source}>
                {source.charAt(0).toUpperCase() + source.slice(1)}
              </option>
            ))}
          </select>
        </div>
        
        {/* Log Level Filter */}
        <div>
          <select
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={selectedLevel || ''}
            onChange={(e) => setSelectedLevel(e.target.value === '' ? null : e.target.value)}
          >
            <option value="">All Levels</option>
            {logLevels.map((level) => (
              <option key={level} value={level}>
                {level.charAt(0).toUpperCase() + level.slice(1)}
              </option>
            ))}
          </select>
        </div>
        
        {/* Start Date Filter */}
        <div>
          <input
            type="datetime-local"
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            placeholder="Start Date"
          />
        </div>
        
        {/* End Date Filter */}
        <div>
          <input
            type="datetime-local"
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            placeholder="End Date"
          />
        </div>
      </div>
      
      {/* Search Bar */}
      <div className="relative">
        <div className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
          <svg className="w-4 h-4 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
          </svg>
        </div>
        <input
          type="search"
          className="block w-full p-2.5 pl-10 text-sm border rounded-lg bg-white dark:bg-agency-800 border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200"
          placeholder="Search logs..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>
      
      {/* Log Controls */}
      <div className="flex justify-between items-center">
        <div className="flex items-center">
          <input
            id="auto-refresh"
            type="checkbox"
            className="w-4 h-4 text-agency-600 bg-gray-100 border-gray-300 rounded focus:ring-agency-500 dark:focus:ring-agency-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            checked={autoRefresh}
            onChange={(e) => setAutoRefresh(e.target.checked)}
          />
          <label htmlFor="auto-refresh" className="ml-2 text-sm font-medium text-agency-700 dark:text-agency-300">
            Auto-refresh
          </label>
        </div>
        
        <button
          className="btn btn-secondary text-sm"
          onClick={() => {
            // Reset all filters
            setSelectedSource(null);
            setSelectedLevel(null);
            setSearchTerm('');
            setStartDate('');
            setEndDate('');
          }}
        >
          Clear Filters
        </button>
      </div>
      
      {/* Logs Table */}
      <div className="relative overflow-x-auto shadow-md rounded-lg">
        <table className="w-full text-sm text-left text-agency-800 dark:text-agency-200">
          <thead className="text-xs text-agency-700 uppercase bg-agency-100 dark:bg-agency-800 dark:text-agency-300">
            <tr>
              <th scope="col" className="px-6 py-3">Timestamp</th>
              <th scope="col" className="px-6 py-3">Level</th>
              <th scope="col" className="px-6 py-3">Source</th>
              <th scope="col" className="px-6 py-3">Message</th>
              {isAdmin() && <th scope="col" className="px-6 py-3">Client ID</th>}
              <th scope="col" className="px-6 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr 
                key={log.id} 
                className="bg-white border-b dark:bg-agency-900 dark:border-agency-800 hover:bg-agency-50 dark:hover:bg-agency-800"
              >
                <td className="px-6 py-4 whitespace-nowrap">
                  {new Date(log.timestamp).toLocaleString()}
                </td>
                <td className="px-6 py-4">
                  <span className={getLevelClass(log.level)}>
                    {log.level.charAt(0).toUpperCase() + log.level.slice(1)}
                  </span>
                </td>
                <td className="px-6 py-4">
                  {log.source}
                </td>
                <td className="px-6 py-4">
                  {log.message}
                </td>
                {isAdmin() && (
                  <td className="px-6 py-4">
                    {log.clientId || 'system'}
                  </td>
                )}
                <td className="px-6 py-4">
                  <button
                    className="font-medium text-agency-600 dark:text-agency-400 hover:underline"
                    onClick={() => setShowDetails(showDetails === log.id ? null : log.id)}
                  >
                    {showDetails === log.id ? 'Hide' : 'Details'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      {/* Log Details */}
      {showDetails && (
        <div className="card mt-4">
          <h3 className="text-lg font-medium text-agency-800 dark:text-agency-100 mb-2">
            Log Details
          </h3>
          <div className="bg-agency-50 dark:bg-agency-800 p-4 rounded-lg font-mono text-sm whitespace-pre-wrap">
            {logs.find(log => log.id === showDetails)?.details || 'No details available'}
          </div>
        </div>
      )}
      
      {logs.length === 0 && (
        <div className="text-center py-10">
          <p className="text-agency-600 dark:text-agency-400">
            No logs match your filters.
          </p>
        </div>
      )}
    </div>
  );
}
