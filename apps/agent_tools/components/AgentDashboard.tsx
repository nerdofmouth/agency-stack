import { useState, useEffect } from 'react';
import { FaInfoCircle, FaExclamationTriangle, FaCheck } from 'react-icons/fa';
import axios from 'axios';

interface Recommendation {
  id: string;
  title: string;
  description: string;
  action_type: string;
  target: string;
  urgency: 'low' | 'medium' | 'high';
  timestamp: string;
}

interface AgentDashboardProps {
  clientId?: string | null;
}

export default function AgentDashboard({ clientId }: AgentDashboardProps) {
  const [recommendations, setRecommendations] = useState<Recommendation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!clientId) return;

    const fetchRecommendations = async () => {
      try {
        setLoading(true);
        const response = await axios.get('/api/agent/recommendations', {
          params: { client_id: clientId }
        });
        setRecommendations(response.data.recommendations || []);
        setError('');
      } catch (err) {
        console.error('Error fetching recommendations:', err);
        setError('Failed to fetch recommendations. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchRecommendations();
    // Set up polling for new recommendations every 30 seconds
    const interval = setInterval(fetchRecommendations, 30000);
    
    return () => clearInterval(interval);
  }, [clientId]);

  const getUrgencyIcon = (urgency: string) => {
    switch (urgency) {
      case 'high':
        return <FaExclamationTriangle className="text-red-500" />;
      case 'medium':
        return <FaInfoCircle className="text-amber-500" />;
      case 'low':
        return <FaCheck className="text-green-500" />;
      default:
        return <FaInfoCircle className="text-blue-500" />;
    }
  };

  const getUrgencyClass = (urgency: string) => {
    switch (urgency) {
      case 'high':
        return 'border-red-500 bg-red-50';
      case 'medium':
        return 'border-amber-500 bg-amber-50';
      case 'low':
        return 'border-green-500 bg-green-50';
      default:
        return 'border-blue-500 bg-blue-50';
    }
  };

  const executeAction = async (recommendation: Recommendation) => {
    try {
      await axios.post('/api/agent/actions', {
        client_id: clientId,
        action: {
          action_type: recommendation.action_type,
          target: recommendation.target,
          description: recommendation.description
        }
      });
      
      // Remove the recommendation from the list after execution
      setRecommendations(recommendations.filter(r => r.id !== recommendation.id));
      
    } catch (err) {
      console.error('Error executing action:', err);
      setError('Failed to execute action. Please try again.');
    }
  };

  if (loading && recommendations.length === 0) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1>AI Agent Recommendations</h1>
        <div className="text-sm text-gray-500">Auto-refreshes every 30 seconds</div>
      </div>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      {recommendations.length === 0 && !loading ? (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
          <FaInfoCircle className="mx-auto text-blue-500 text-3xl mb-2" />
          <h3 className="text-lg font-medium text-blue-800">No Recommendations</h3>
          <p className="text-blue-600">
            All systems are operating normally. The AI agent has no recommendations at this time.
          </p>
        </div>
      ) : (
        <div className="grid gap-6 md:grid-cols-2">
          {recommendations.map((recommendation) => (
            <div 
              key={recommendation.id} 
              className={`card border-l-4 ${getUrgencyClass(recommendation.urgency)}`}
            >
              <div className="flex items-start">
                <div className="mr-3 mt-1">
                  {getUrgencyIcon(recommendation.urgency)}
                </div>
                <div className="flex-1">
                  <h3 className="font-bold text-lg">{recommendation.title}</h3>
                  <p className="text-gray-700 mb-4">{recommendation.description}</p>
                  
                  <div className="flex justify-between items-center">
                    <div>
                      <span className="badge-info mr-2">{recommendation.action_type}</span>
                      <span className="badge-warning">{recommendation.target}</span>
                    </div>
                    <button 
                      onClick={() => executeAction(recommendation)}
                      className="btn-primary text-sm"
                    >
                      Execute Action
                    </button>
                  </div>
                  
                  <div className="mt-3 text-xs text-gray-500">
                    {new Date(recommendation.timestamp).toLocaleString()}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
