import { useState, useEffect } from 'react';
import axios from 'axios';
import { FaFilter, FaDownload, FaSync } from 'react-icons/fa';

interface AgentLogsProps {
  clientId?: string | null;
  component?: string;
  lines?: number;
}

export default function AgentLogs({ clientId, component = 'agent_orchestrator', lines = 100 }: AgentLogsProps) {
  const [logs, setLogs] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedComponent, setSelectedComponent] = useState(component);
  const [logLines, setLogLines] = useState(lines);
  const [searchFilter, setSearchFilter] = useState('');
  const [filteredLogs, setFilteredLogs] = useState<string[]>([]);
  
  const components = [
    { value: 'agent_orchestrator', label: 'Agent Orchestrator' },
    { value: 'langchain', label: 'LangChain' },
    { value: 'ollama', label: 'Ollama' }
  ];
  
  const lineOptions = [
    { value: 50, label: '50 lines' },
    { value: 100, label: '100 lines' },
    { value: 250, label: '250 lines' },
    { value: 500, label: '500 lines' }
  ];
  
  const fetchLogs = async () => {
    if (!clientId) return;
    
    try {
      setLoading(true);
      const response = await axios.get(`/api/agent/logs/${selectedComponent}`, {
        params: {
          client_id: clientId,
          lines: logLines
        }
      });
      
      setLogs(response.data.logs || []);
      setError('');
    } catch (err) {
      console.error('Error fetching logs:', err);
      setError('Failed to fetch logs. Please try again later.');
    } finally {
      setLoading(false);
    }
  };
  
  useEffect(() => {
    fetchLogs();
    // Set up polling for new logs every 10 seconds
    const interval = setInterval(fetchLogs, 10000);
    
    return () => clearInterval(interval);
  }, [clientId, selectedComponent, logLines]);
  
  useEffect(() => {
    if (searchFilter) {
      const filtered = logs.filter(log => 
        log.toLowerCase().includes(searchFilter.toLowerCase())
      );
      setFilteredLogs(filtered);
    } else {
      setFilteredLogs(logs);
    }
  }, [logs, searchFilter]);
  
  const logLevelColor = (logLine: string) => {
    if (logLine.includes('[ERROR]') || logLine.includes(' ERROR ')) {
      return 'text-red-600';
    } else if (logLine.includes('[WARN]') || logLine.includes(' WARN ')) {
      return 'text-amber-600';
    } else if (logLine.includes('[INFO]') || logLine.includes(' INFO ')) {
      return 'text-blue-600';
    } else if (logLine.includes('[DEBUG]') || logLine.includes(' DEBUG ')) {
      return 'text-gray-600';
    }
    return '';
  };

  const downloadLogs = () => {
    const logText = filteredLogs.join('\n');
    const blob = new Blob([logText], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${selectedComponent}_logs_${new Date().toISOString().slice(0, 10)}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <h2 className="text-xl font-semibold m-0">
          {components.find(c => c.value === selectedComponent)?.label} Logs
        </h2>
        
        <div className="flex flex-wrap gap-2">
          <div className="flex items-center space-x-2">
            <label htmlFor="component-select" className="text-sm text-gray-600">Component:</label>
            <select 
              id="component-select"
              className="input py-1 px-3 text-sm"
              value={selectedComponent}
              onChange={(e) => setSelectedComponent(e.target.value)}
            >
              {components.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
          
          <div className="flex items-center space-x-2">
            <label htmlFor="lines-select" className="text-sm text-gray-600">Lines:</label>
            <select 
              id="lines-select"
              className="input py-1 px-3 text-sm"
              value={logLines}
              onChange={(e) => setLogLines(Number(e.target.value))}
            >
              {lineOptions.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
          
          <button 
            onClick={fetchLogs} 
            className="btn-outline flex items-center py-1 px-3"
            title="Refresh logs"
          >
            <FaSync className="mr-1" /> Refresh
          </button>
          
          <button 
            onClick={downloadLogs} 
            className="btn-outline flex items-center py-1 px-3"
            title="Download logs"
          >
            <FaDownload className="mr-1" /> Download
          </button>
        </div>
      </div>
      
      <div className="relative">
        <div className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
          <FaFilter className="text-gray-400" />
        </div>
        <input
          type="text"
          className="input pl-10"
          placeholder="Filter logs..."
          value={searchFilter}
          onChange={(e) => setSearchFilter(e.target.value)}
        />
      </div>
      
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}
      
      <div className="card p-0 overflow-hidden bg-gray-900">
        {loading && logs.length === 0 ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-gray-200"></div>
          </div>
        ) : (
          <div className="overflow-auto max-h-[600px] p-4">
            {filteredLogs.length > 0 ? (
              <pre className="font-mono text-xs text-gray-200 whitespace-pre-wrap">
                {filteredLogs.map((log, index) => (
                  <div key={index} className={`py-1 ${logLevelColor(log)}`}>
                    {log}
                  </div>
                ))}
              </pre>
            ) : (
              <div className="text-center py-10 text-gray-400">
                {searchFilter ? 'No logs match your filter' : 'No logs available'}
              </div>
            )}
          </div>
        )}
      </div>
      
      <div className="text-sm text-gray-500 flex justify-between">
        <span>
          Showing {filteredLogs.length} of {logs.length} logs
        </span>
        <span>
          Auto-refreshes every 10 seconds
        </span>
      </div>
    </div>
  );
}
