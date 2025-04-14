import type { NextApiRequest, NextApiResponse } from 'next';
import axios from 'axios';

type SimulationResponse = {
  success?: boolean;
  message?: string;
  details?: any;
  error?: string;
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<SimulationResponse>
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { event_type, client_id } = req.body;
  
  if (!client_id) {
    return res.status(400).json({ error: 'client_id is required' });
  }

  if (!event_type) {
    return res.status(400).json({ error: 'event_type is required' });
  }

  // Validate that this is only used in mock mode
  const mockMode = process.env.NEXT_PUBLIC_MOCK_MODE === 'true' || req.headers['x-mock-mode'] === 'true';
  if (!mockMode) {
    return res.status(403).json({ 
      error: 'Simulation is only available in mock mode.' 
    });
  }

  try {
    // Connect to the correct service based on the event type
    let targetService = 'agent-orchestrator';
    let eventPayload: any = { client_id };
    
    switch (event_type) {
      case 'high_memory':
        targetService = 'resource-watcher';
        eventPayload.simulation = {
          type: 'high_memory',
          component: 'ollama',
          value: 92.5,
          duration: 300 // seconds
        };
        break;
        
      case 'slow_response':
        targetService = 'langchain';
        eventPayload.simulation = {
          type: 'slow_response',
          model: 'llama2',
          latency: 5000, // milliseconds
          duration: 300 // seconds
        };
        break;
        
      case 'new_model':
        targetService = 'agent-orchestrator';
        eventPayload.simulation = {
          type: 'new_model',
          model: 'llama3',
          provider: 'ollama',
          action: 'pull_model'
        };
        break;
        
      case 'error':
        targetService = Math.random() > 0.5 ? 'langchain' : 'ollama';
        eventPayload.simulation = {
          type: 'error',
          error_type: 'connection_timeout',
          message: `Simulated ${targetService} error`,
          severity: 'high'
        };
        break;
        
      default:
        return res.status(400).json({ error: `Unknown event type: ${event_type}` });
    }

    // Send the simulation request to the appropriate mock service
    const servicePort = 
      targetService === 'agent-orchestrator' ? 5210 :
      targetService === 'langchain' ? 5111 :
      targetService === 'resource-watcher' ? 5220 : 5210;
      
    const response = await axios.post(
      `http://localhost:${servicePort}/simulate`,
      eventPayload,
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Mock-Mode': 'true'
        },
        timeout: 5000
      }
    );

    // If we get here, the simulation was triggered successfully
    return res.status(200).json({
      success: true,
      message: `Successfully triggered ${event_type} simulation on ${targetService}`,
      details: response.data
    });
  } catch (error: any) {
    console.error(`Error triggering simulation:`, error.message);
    
    // Create a synthetic success response since we're in mock mode
    // This way the UI will still show something even if the backend isn't fully implemented
    if (mockMode) {
      return res.status(200).json({
        success: true,
        message: `Simulated ${event_type} event triggered (fallback mode)`,
        details: {
          note: "Fallback simulation active - backend mock service may not be fully implemented",
          timestamp: new Date().toISOString()
        }
      });
    }
    
    // If not using fallback, return the actual error
    return res.status(500).json({ 
      error: `Error triggering simulation: ${error.message}` 
    });
  }
}
