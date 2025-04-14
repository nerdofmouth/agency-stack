import type { NextApiRequest, NextApiResponse } from 'next';
import axios from 'axios';

type MetricsResponse = {
  metrics?: any[];
  component?: string;
  start_time?: string;
  end_time?: string;
  error?: string;
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<MetricsResponse>
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const clientId = req.query.client_id as string;
  const component = req.query.component as string;
  const timeRange = req.query.time_range as string || '1h';
  
  if (!clientId) {
    return res.status(400).json({ error: 'client_id is required' });
  }
  
  if (!component) {
    return res.status(400).json({ error: 'component is required' });
  }

  // Validate that the component is allowed
  const validComponents = ['agent_orchestrator', 'langchain', 'ollama'];
  if (!validComponents.includes(component)) {
    return res.status(400).json({ error: `Invalid component: ${component}` });
  }
  
  // Validate time range
  const validTimeRanges = ['1h', '6h', '24h', '7d'];
  if (!validTimeRanges.includes(timeRange)) {
    return res.status(400).json({ error: `Invalid time_range: ${timeRange}` });
  }

  try {
    // Connect to the Agent Orchestrator backend
    const response = await axios.get(
      `http://localhost:5210/metrics/${component}`,
      {
        params: {
          client_id: clientId,
          time_range: timeRange
        },
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 5000 // 5 second timeout
      }
    );

    return res.status(200).json(response.data);
  } catch (error: any) {
    console.error(`Error fetching metrics for ${component}:`, error.message);
    
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
