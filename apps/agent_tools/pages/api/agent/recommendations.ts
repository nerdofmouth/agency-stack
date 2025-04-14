import type { NextApiRequest, NextApiResponse } from 'next';
import axios from 'axios';

type RecommendationResponse = {
  recommendations?: any[];
  error?: string;
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<RecommendationResponse>
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const clientId = req.query.client_id as string;
  
  if (!clientId) {
    return res.status(400).json({ error: 'client_id is required' });
  }

  try {
    // Connect to the Agent Orchestrator backend
    const response = await axios.post(
      'http://localhost:5210/recommendations',
      {
        client_id: clientId,
        context: {
          systemInfo: req.query.systemInfo || {},
          clientInfo: {
            id: clientId
          }
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 10000 // 10 second timeout
      }
    );

    return res.status(200).json(response.data);
  } catch (error: any) {
    console.error('Error fetching recommendations:', error.message);
    
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
