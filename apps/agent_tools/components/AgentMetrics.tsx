import { useState, useEffect } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import { format } from 'date-fns';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ChartData,
  ChartOptions
} from 'chart.js';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

interface Metric {
  name: string;
  timestamps: string[];
  values: number[];
  unit: string;
}

interface MetricsResponse {
  metrics: Metric[];
  component: string;
  start_time: string;
  end_time: string;
}

interface AgentMetricsProps {
  clientId?: string | null;
  component?: string;
  timeRange?: '1h' | '6h' | '24h' | '7d';
}

export default function AgentMetrics({ clientId, component = 'agent_orchestrator', timeRange = '1h' }: AgentMetricsProps) {
  const [metrics, setMetrics] = useState<Metric[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedComponent, setSelectedComponent] = useState(component);
  const [selectedTimeRange, setSelectedTimeRange] = useState(timeRange);
  
  const components = [
    { value: 'agent_orchestrator', label: 'Agent Orchestrator' },
    { value: 'langchain', label: 'LangChain' },
    { value: 'ollama', label: 'Ollama' }
  ];
  
  const timeRanges = [
    { value: '1h', label: 'Last Hour' },
    { value: '6h', label: 'Last 6 Hours' },
    { value: '24h', label: 'Last 24 Hours' },
    { value: '7d', label: 'Last 7 Days' }
  ];

  useEffect(() => {
    if (!clientId) return;
    
    const fetchMetrics = async () => {
      try {
        setLoading(true);
        const response = await axios.get(`/api/agent/metrics/${selectedComponent}`, {
          params: {
            client_id: clientId,
            time_range: selectedTimeRange
          }
        });
        
        setMetrics(response.data.metrics || []);
        setError('');
      } catch (err) {
        console.error('Error fetching metrics:', err);
        setError('Failed to fetch metrics. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchMetrics();
    // Set up polling for fresh metrics every minute
    const interval = setInterval(fetchMetrics, 60000);
    
    return () => clearInterval(interval);
  }, [clientId, selectedComponent, selectedTimeRange]);

  const prepareChartData = (metric: Metric): ChartData<'line'> => {
    // Format timestamps for display
    const labels = metric.timestamps.map(ts => {
      return format(new Date(ts), 
        selectedTimeRange === '1h' || selectedTimeRange === '6h' ? 'HH:mm' : 'MM/dd HH:mm'
      );
    });
    
    return {
      labels,
      datasets: [
        {
          label: `${metric.name} (${metric.unit})`,
          data: metric.values,
          borderColor: getMetricColor(metric.name),
          backgroundColor: getMetricColor(metric.name, 0.1),
          tension: 0.2,
          fill: true,
          pointRadius: 2,
          pointHoverRadius: 5
        }
      ]
    };
  };
  
  const chartOptions: ChartOptions<'line'> = {
    responsive: true,
    plugins: {
      legend: {
        position: 'top' as const,
      },
      tooltip: {
        mode: 'index',
        intersect: false,
      },
    },
    scales: {
      y: {
        beginAtZero: false,
      },
    },
    interaction: {
      mode: 'nearest',
      axis: 'x',
      intersect: false
    }
  };
  
  // Helper function to get consistent colors for metrics
  const getMetricColor = (metricName: string, alpha = 1) => {
    const colorMap: {[key: string]: string} = {
      cpu_usage: `rgba(54, 162, 235, ${alpha})`,
      memory_usage: `rgba(255, 99, 132, ${alpha})`,
      request_count: `rgba(75, 192, 192, ${alpha})`,
      response_time: `rgba(153, 102, 255, ${alpha})`,
      error_rate: `rgba(255, 159, 64, ${alpha})`,
      queue_size: `rgba(255, 205, 86, ${alpha})`,
      throughput: `rgba(76, 175, 80, ${alpha})`,
      latency: `rgba(103, 58, 183, ${alpha})`,
      success_rate: `rgba(139, 195, 74, ${alpha})`
    };
    
    return colorMap[metricName.toLowerCase()] || `rgba(128, 128, 128, ${alpha})`;
  };

  // Get a summary of the current state for each metric
  const getMetricSummary = (metric: Metric) => {
    if (!metric.values.length) return { current: 'N/A', trend: 'neutral' };
    
    const current = metric.values[metric.values.length - 1];
    const previous = metric.values.length > 1 ? metric.values[metric.values.length - 2] : current;
    const percentChange = previous !== 0 ? ((current - previous) / previous) * 100 : 0;
    
    let trend: 'up' | 'down' | 'neutral' = 'neutral';
    if (Math.abs(percentChange) > 1) {
      trend = percentChange > 0 ? 'up' : 'down';
    }
    
    // For error rates and latency, down is good
    if (metric.name.toLowerCase().includes('error') || 
        metric.name.toLowerCase().includes('latency')) {
      trend = trend === 'up' ? 'down' : trend === 'down' ? 'up' : 'neutral';
    }
    
    return {
      current: `${current.toFixed(2)} ${metric.unit}`,
      trend
    };
  };
  
  const trendColors = {
    up: 'text-green-500',
    down: 'text-red-500',
    neutral: 'text-gray-500'
  };
  
  const trendIcons = {
    up: '↑',
    down: '↓',
    neutral: '→'
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <h2 className="text-xl font-semibold m-0">{components.find(c => c.value === selectedComponent)?.label} Metrics</h2>
        
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
            <label htmlFor="timerange-select" className="text-sm text-gray-600">Time Range:</label>
            <select 
              id="timerange-select"
              className="input py-1 px-3 text-sm"
              value={selectedTimeRange}
              onChange={(e) => setSelectedTimeRange(e.target.value as '1h' | '6h' | '24h' | '7d')}
            >
              {timeRanges.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>
      
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
          {error}
        </div>
      )}
      
      {loading && metrics.length === 0 ? (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div>
        </div>
      ) : metrics.length === 0 ? (
        <div className="card p-6 text-center">
          <h3 className="text-lg font-medium text-gray-600">No Metrics Available</h3>
          <p className="text-gray-500 mt-2">
            The selected component does not have any metrics data for the selected time range.
          </p>
        </div>
      ) : (
        <>
          {/* Metrics Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            {metrics.map(metric => {
              const summary = getMetricSummary(metric);
              
              return (
                <div key={metric.name} className="card">
                  <h3 className="text-base font-medium text-gray-700">{metric.name}</h3>
                  <div className="flex items-baseline mt-2">
                    <div className="text-2xl font-bold">{summary.current}</div>
                    <div className={`ml-2 ${trendColors[summary.trend]}`}>
                      {trendIcons[summary.trend]}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
          
          {/* Metric Charts */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {metrics.map(metric => (
              <div key={metric.name} className="card">
                <h3 className="text-base font-medium mb-4">{metric.name}</h3>
                <div className="h-64">
                  <Line
                    data={prepareChartData(metric)}
                    options={chartOptions}
                  />
                </div>
              </div>
            ))}
          </div>
        </>
      )}
      
      <div className="text-sm text-gray-500 text-right">
        Last updated: {new Date().toLocaleString()} (refreshes every minute)
      </div>
    </div>
  );
}
