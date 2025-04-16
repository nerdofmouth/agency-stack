import type { NextApiRequest, NextApiResponse } from 'next';
import axios from 'axios';

type PromptResponse = {
  response?: string;
  error?: string;
};

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<PromptResponse>
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { client_id, prompt, model, parameters } = req.body;
  
  if (!client_id) {
    return res.status(400).json({ error: 'client_id is required' });
  }

  if (!prompt || typeof prompt !== 'string' || prompt.trim() === '') {
    return res.status(400).json({ error: 'A valid prompt is required' });
  }

  try {
    // Connect to the LangChain API via Agent Orchestrator
    const response = await axios.post(
      'http://localhost:5210/prompt',
      {
        client_id,
        prompt,
        model: model || 'default',
        parameters: parameters || {
          temperature: 0.7,
          max_tokens: 500
        }
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 60000 // 60 second timeout for LLM processing
      }
    );

    return res.status(200).json({ response: response.data.response });
  } catch (error: any) {
    console.error('Error processing prompt:', error.message);
    
    // Return a more specific error based on the axios error
    if (error.code === 'ECONNREFUSED') {
      return res.status(503).json({ error: 'Agent Orchestrator is not available' });
    }
    
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      return res.status(error.response.status).json({ 
        error: `Error: ${error.response.data.message || error.response.statusText}` 
      });
    } else if (error.request) {
      // The request was made but no response was received
      return res.status(504).json({ error: 'Timeout connecting to Agent Orchestrator or LLM processing took too long' });
    } else {
      // Something happened in setting up the request that triggered an Error
      return res.status(500).json({ error: `Error: ${error.message}` });
    }
  }
}
