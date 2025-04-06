import React, { useState } from 'react';
import axios from 'axios';
import { 
  FaBug, 
  FaMemory, 
  FaClock, 
  FaRobot, 
  FaExclamationTriangle 
} from 'react-icons/fa';

type SimulationEvent = {
  id: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  eventType: string;
};

type SimulationPanelProps = {
  clientId: string;
};

const SimulationPanel: React.FC<SimulationPanelProps> = ({ clientId }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState<{success?: boolean; message?: string; error?: string} | null>(null);

  const simulationEvents: SimulationEvent[] = [
    {
      id: 'high-memory',
      title: 'High Memory Usage',
      description: 'Simulate Ollama using excessive memory (92.5%)',
      icon: <FaMemory className="text-yellow-500" />,
      eventType: 'high_memory'
    },
    {
      id: 'slow-response',
      title: 'Slow API Response',
      description: 'Simulate LangChain responding slowly (5s latency)',
      icon: <FaClock className="text-blue-500" />,
      eventType: 'slow_response'
    },
    {
      id: 'new-model',
      title: 'New Model Available',
      description: 'Simulate a new LLM model becoming available',
      icon: <FaRobot className="text-green-500" />,
      eventType: 'new_model'
    },
    {
      id: 'error',
      title: 'Error Condition',
      description: 'Simulate a random error in a component',
      icon: <FaExclamationTriangle className="text-red-500" />,
      eventType: 'error'
    }
  ];

  const triggerSimulation = async (eventType: string) => {
    setIsLoading(true);
    setResult(null);
    
    try {
      const response = await axios.post('/api/agent/simulate', {
        event_type: eventType,
        client_id: clientId
      });
      
      setResult({
        success: true,
        message: response.data.message
      });
    } catch (error: any) {
      setResult({
        success: false,
        error: error.response?.data?.error || error.message || 'Unknown error'
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-white p-4 rounded-lg shadow mb-6">
      <div className="flex items-center mb-4">
        <FaBug className="text-indigo-600 mr-2" />
        <h2 className="text-lg font-semibold">Simulation Controls</h2>
      </div>
      
      <p className="text-sm text-gray-600 mb-4">
        Use these controls to trigger simulated events in the AI Suite. These events will generate realistic
        data and behavior in the mock environment.
      </p>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
        {simulationEvents.map((event) => (
          <button
            key={event.id}
            className="flex items-center justify-between p-3 border rounded-md hover:bg-indigo-50 transition-colors"
            onClick={() => triggerSimulation(event.eventType)}
            disabled={isLoading}
          >
            <div className="flex items-center">
              <div className="mr-3">{event.icon}</div>
              <div className="text-left">
                <div className="font-medium">{event.title}</div>
                <div className="text-xs text-gray-500">{event.description}</div>
              </div>
            </div>
          </button>
        ))}
      </div>
      
      {isLoading && (
        <div className="text-center p-3 border border-indigo-100 bg-indigo-50 rounded-md">
          <div className="animate-pulse">Simulating event...</div>
        </div>
      )}
      
      {result && (
        <div className={`p-3 border rounded-md ${result.success ? 'border-green-100 bg-green-50' : 'border-red-100 bg-red-50'}`}>
          {result.success ? (
            <div className="text-green-700">{result.message}</div>
          ) : (
            <div className="text-red-700">{result.error}</div>
          )}
        </div>
      )}
      
      <div className="mt-4 text-xs text-gray-500">
        <div className="flex justify-between">
          <span>Client ID: {clientId}</span>
          <span>Mock Mode: Active</span>
        </div>
      </div>
    </div>
  );
};

export default SimulationPanel;
