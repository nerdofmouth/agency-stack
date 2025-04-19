import { useState, useEffect } from 'react';
import { FaCog, FaSync, FaCogs, FaBroom, FaVial } from 'react-icons/fa';
import axios from 'axios';

interface Action {
  action_type: string;
  target: string;
  description: string;
  parameters?: Record<string, any>;
}

interface ActionCategory {
  name: string;
  icon: React.ReactNode;
  actions: Action[];
}

interface AgentActionsProps {
  clientId?: string | null;
}

export default function AgentActions({ clientId }: AgentActionsProps) {
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [selectedAction, setSelectedAction] = useState<Action | null>(null);
  const [actionResult, setActionResult] = useState<any>(null);
  
  // Predefined safe actions grouped by category
  const actionCategories: ActionCategory[] = [
    {
      name: 'Service Management',
      icon: <FaCog />,
      actions: [
        {
          action_type: 'restart_service',
          target: 'langchain',
          description: 'Restart the LangChain service'
        },
        {
          action_type: 'restart_service',
          target: 'ollama',
          description: 'Restart the Ollama service'
        },
        {
          action_type: 'restart_service',
          target: 'agent_orchestrator',
          description: 'Restart the Agent Orchestrator'
        }
      ]
    },
    {
      name: 'Data Management',
      icon: <FaSync />,
      actions: [
        {
          action_type: 'sync_logs',
          target: 'langchain',
          description: 'Synchronize LangChain logs'
        },
        {
          action_type: 'sync_logs',
          target: 'ollama',
          description: 'Synchronize Ollama logs'
        },
        {
          action_type: 'sync_logs',
          target: 'agent_orchestrator',
          description: 'Synchronize Agent Orchestrator logs'
        }
      ]
    },
    {
      name: 'Model Management',
      icon: <FaCogs />,
      actions: [
        {
          action_type: 'pull_model',
          target: 'ollama',
          description: 'Pull LLM model for Ollama',
          parameters: {
            model_name: 'llama2',
            version: 'latest'
          }
        },
        {
          action_type: 'pull_model',
          target: 'ollama',
          description: 'Pull CodeLlama model for Ollama',
          parameters: {
            model_name: 'codellama',
            version: 'latest'
          }
        }
      ]
    },
    {
      name: 'Cache Management',
      icon: <FaBroom />,
      actions: [
        {
          action_type: 'clear_cache',
          target: 'langchain',
          description: 'Clear LangChain cache'
        },
        {
          action_type: 'clear_cache',
          target: 'ollama',
          description: 'Clear Ollama cache'
        },
        {
          action_type: 'clear_cache',
          target: 'agent_orchestrator',
          description: 'Clear Agent Orchestrator cache'
        }
      ]
    },
    {
      name: 'Diagnostics',
      icon: <FaVial />,
      actions: [
        {
          action_type: 'run_test',
          target: 'langchain',
          description: 'Run LangChain diagnostic test'
        },
        {
          action_type: 'run_test',
          target: 'ollama',
          description: 'Run Ollama diagnostic test'
        },
        {
          action_type: 'run_test',
          target: 'agent_orchestrator',
          description: 'Run Agent Orchestrator diagnostic test'
        }
      ]
    }
  ];

  const executeAction = async (action: Action) => {
    if (!clientId) {
      setError('Client ID is required to execute actions');
      return;
    }
    
    setLoading(true);
    setMessage('');
    setError('');
    setActionResult(null);
    
    try {
      const response = await axios.post('/api/agent/actions', {
        client_id: clientId,
        action: {
          action_type: action.action_type,
          target: action.target,
          description: action.description,
          parameters: action.parameters
        }
      });
      
      setActionResult(response.data);
      setMessage(`Action executed successfully: ${action.description}`);
    } catch (err: any) {
      console.error('Error executing action:', err);
      setError(err.response?.data?.message || 'Failed to execute action');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <h1>Available Agent Actions</h1>
      
      {message && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded relative mb-4">
          {message}
        </div>
      )}
      
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4">
          {error}
        </div>
      )}
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {actionCategories.map((category) => (
          <div key={category.name} className="card">
            <div className="flex items-center mb-4">
              <span className="text-primary text-xl mr-2">{category.icon}</span>
              <h2 className="text-xl font-semibold m-0">{category.name}</h2>
            </div>
            
            <div className="space-y-3">
              {category.actions.map((action, idx) => (
                <div 
                  key={`${action.action_type}-${action.target}-${idx}`}
                  className="border border-gray-200 rounded-md p-3 hover:bg-gray-50 transition-colors"
                >
                  <div className="flex justify-between items-center">
                    <div>
                      <div className="font-medium">{action.description}</div>
                      <div className="text-sm text-gray-500 mt-1">
                        {action.action_type} &bull; {action.target}
                        {action.parameters && (
                          <span> &bull; {Object.keys(action.parameters).length} parameters</span>
                        )}
                      </div>
                    </div>
                    <button 
                      className="btn-outline text-sm"
                      onClick={() => {
                        setSelectedAction(action);
                        executeAction(action);
                      }}
                      disabled={loading}
                    >
                      {loading && selectedAction?.action_type === action.action_type && 
                       selectedAction?.target === action.target ? (
                        <span className="flex items-center">
                          <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                          </svg>
                          Running...
                        </span>
                      ) : 'Execute'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
      
      {actionResult && (
        <div className="card mt-6">
          <h3 className="text-lg font-semibold mb-3">Action Result</h3>
          <div className="bg-gray-100 p-4 rounded-md">
            <pre className="whitespace-pre-wrap text-sm font-mono text-gray-800">
              {JSON.stringify(actionResult, null, 2)}
            </pre>
          </div>
        </div>
      )}
    </div>
  );
}
