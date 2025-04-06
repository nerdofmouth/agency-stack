import type { NextApiRequest, NextApiResponse } from 'next';
import axios from 'axios';

type ActionResponse = {
  success?: boolean;
  message?: string;
  details?: any;
  error?: string;
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ActionResponse>
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { client_id, action } = req.body;
  
  if (!client_id) {
    return res.status(400).json({ error: 'client_id is required' });
  }

  if (!action || !action.action_type || !action.target) {
    return res.status(400).json({ error: 'Invalid action format. action_type and target are required.' });
  }

  // Validate that the action is safe (add any additional safety checks here)
  const safeActions = ['restart_service', 'sync_logs', 'pull_model', 'clear_cache', 'run_test'];
  if (!safeActions.includes(action.action_type)) {
    return res.status(403).json({ 
      error: `Action type '${action.action_type}' is not allowed for security reasons.` 
    });
  }

  try {
    // Connect to the Agent Orchestrator backend
    const response = await axios.post(
      'http://localhost:5210/actions',
      {
        client_id,
        action: {
          action_type: action.action_type,
          target: action.target,
          description: action.description || '',
          parameters: action.parameters || {}
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 30000 // 30 second timeout for actions
      }
    );

    return res.status(200).json(response.data);
  } catch (error: any) {
    console.error('Error executing action:', error.message);
    
    // Return a more specific error based on the axios error
    if (error.code === 'ECONNREFUSED') {
      return res.status(503).json({ error: 'Agent Orchestrator is not available' });
    }
    
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      return res.status(error.response.status).json({ 
        error: `Agent Orchestrator returned an error: ${error.response.data.message || error.response.statusText}` 
      });
    } else if (error.request) {
      // The request was made but no response was received
      return res.status(504).json({ error: 'Timeout connecting to Agent Orchestrator' });
    } else {
      // Something happened in setting up the request that triggered an Error
      return res.status(500).json({ error: `Error: ${error.message}` });
    }
  }
}
