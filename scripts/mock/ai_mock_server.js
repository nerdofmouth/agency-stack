// AI Suite Mock Server
// This script creates mock servers for Agent Orchestrator, LangChain, and Resource Watcher
// to provide simulated responses for testing purposes.

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

// Initialize component servers
function createMockServer(componentName, port) {
  const app = express();
  
  // Middleware
  app.use(cors());
  app.use(bodyParser.json());
  
  // Logging middleware
  app.use((req, res, next) => {
    console.log(`[${componentName}] ${req.method} ${req.path}`);
    next();
  });
  
  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', component: componentName });
  });
  
  // Start the server
  app.listen(port, () => {
    console.log(`Mock ${componentName} server running on port ${port}`);
  });
  
  return app;
}

// Create mock servers
const agentOrchestrator = createMockServer('agent-orchestrator', 5210);
const langchain = createMockServer('langchain', 5111);
const resourceWatcher = createMockServer('resource-watcher', 5220);

// ============ AGENT ORCHESTRATOR MOCK ENDPOINTS ============

// Mock recommendations
const mockRecommendations = [
  {
    id: 'rec1',
    title: 'Clear Ollama cache to improve performance',
    description: 'Ollama is using more memory than usual. Clearing the cache can help free up resources.',
    priority: 'high',
    component: 'ollama',
    action: 'clear_cache',
    created_at: new Date().toISOString(),
    status: 'pending',
  },
  {
    id: 'rec2',
    title: 'Restart LangChain service',
    description: 'LangChain response times are increasing. A restart may improve performance.',
    priority: 'medium',
    component: 'langchain',
    action: 'restart_service',
    created_at: new Date().toISOString(),
    status: 'pending',
  },
  {
    id: 'rec3',
    title: 'Pull latest model updates',
    description: 'New model versions are available for llama2 and mistral.',
    priority: 'low',
    component: 'agent-orchestrator',
    action: 'pull_models',
    created_at: new Date().toISOString(),
    status: 'pending',
  }
];

// GET recommendations endpoint
agentOrchestrator.get('/api/recommendations', (req, res) => {
  const clientId = req.query.client_id || req.headers['x-client-id'] || 'test';
  
  // Create a copy of recommendations with client_id
  const recommendations = mockRecommendations.map(rec => ({
    ...rec,
    client_id: clientId
  }));
  
  res.json({ recommendations });
});

// POST actions endpoint
agentOrchestrator.post('/api/actions', (req, res) => {
  const { action, component, client_id } = req.body;
  
  if (!action || !component || !client_id) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  
  // Simulate action execution time
  setTimeout(() => {
    res.json({
      success: true,
      action_id: `act_${Math.random().toString(36).substring(2, 10)}`,
      action,
      component,
      status: 'completed',
      message: `Successfully executed ${action} on ${component}`,
      timestamp: new Date().toISOString()
    });
  }, 1500);
});

// Simulation endpoint for agent orchestrator
agentOrchestrator.post('/simulate', (req, res) => {
  const { simulation, client_id } = req.body;
  
  if (!simulation || !client_id) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  
  console.log(`[agent-orchestrator] Simulating event: ${simulation.type}`);
  
  // Process the simulation based on type
  switch(simulation.type) {
    case 'new_model':
      // Add a new recommendation for the model
      const newRec = {
        id: `rec_${Math.random().toString(36).substring(2, 10)}`,
        title: `New model ${simulation.model} available`,
        description: `A new model (${simulation.model}) is available from ${simulation.provider}. Consider pulling this model to keep your AI suite updated.`,
        priority: 'medium',
        component: simulation.provider,
        action: simulation.action,
        created_at: new Date().toISOString(),
        status: 'pending',
        client_id
      };
      
      mockRecommendations.push(newRec);
      
      res.json({
        success: true,
        message: `Simulated new model recommendation for ${simulation.model}`,
        recommendation: newRec
      });
      break;
      
    default:
      res.json({
        success: true,
        message: `Received simulation ${simulation.type}, but no specific handler implemented.`
      });
  }
});

// ============ LANGCHAIN MOCK ENDPOINTS ============

// Mock models
const mockModels = [
  { id: 'llama2', name: 'Llama 2', provider: 'ollama', status: 'active' },
  { id: 'mistral', name: 'Mistral 7B', provider: 'ollama', status: 'active' },
  { id: 'gpt4', name: 'GPT-4 Simulation', provider: 'mock', status: 'active' }
];

// GET models endpoint
langchain.get('/api/models', (req, res) => {
  res.json({ models: mockModels });
});

// POST prompt endpoint
langchain.post('/api/prompt', (req, res) => {
  const { prompt, model, params, client_id } = req.body;
  
  if (!prompt || !model || !client_id) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  
  // Select response time based on simulation state
  let responseTime = Math.random() * 1000 + 500; // 500-1500ms by default
  
  // Check if slow response simulation is active
  if (global.slowResponseSimulation && global.slowResponseSimulation.model === model) {
    responseTime = global.slowResponseSimulation.latency;
  }
  
  // Simulate processing time
  setTimeout(() => {
    // Generate a mock response
    const responses = [
      "This is a simulated response from the LangChain mock service. In a real environment, this would be generated by the actual LLM.",
      "I'm a mock LLM running in the AI Suite test harness. My responses are pre-defined for testing purposes.",
      "The mock mode is working correctly! This response is coming from the LangChain simulator, not a real LLM.",
      "Testing, testing, 1-2-3. This is your friendly neighborhood mock LLM, ready for all your testing needs."
    ];
    
    const randomResponse = responses[Math.floor(Math.random() * responses.length)];
    
    res.json({
      success: true,
      model,
      response: randomResponse,
      tokens: {
        prompt: prompt.split(' ').length,
        completion: randomResponse.split(' ').length,
        total: prompt.split(' ').length + randomResponse.split(' ').length
      },
      timing: {
        total_ms: responseTime
      }
    });
  }, responseTime);
});

// Simulation endpoint for langchain
langchain.post('/simulate', (req, res) => {
  const { simulation, client_id } = req.body;
  
  if (!simulation || !client_id) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  
  console.log(`[langchain] Simulating event: ${simulation.type}`);
  
  switch(simulation.type) {
    case 'slow_response':
      // Set global simulation state
      global.slowResponseSimulation = {
        model: simulation.model,
        latency: simulation.latency,
        active: true
      };
      
      // Set timeout to clear the simulation after duration
      setTimeout(() => {
        global.slowResponseSimulation = null;
        console.log(`[langchain] Ended slow response simulation`);
      }, simulation.duration * 1000);
      
      res.json({
        success: true,
        message: `Simulating slow responses (${simulation.latency}ms) for ${simulation.duration} seconds`,
        simulation: global.slowResponseSimulation
      });
      break;
      
    case 'error':
      // Instead of setting a global simulation, we'll just respond with success
      // The error will be simulated when actual API calls are made
      res.json({
        success: true,
        message: `Simulating errors: ${simulation.message}`,
        simulation: simulation
      });
      break;
      
    default:
      res.json({
        success: true,
        message: `Received simulation ${simulation.type}, but no specific handler implemented.`
      });
  }
});

// ============ RESOURCE WATCHER MOCK ENDPOINTS ============

// Mock metrics
const generateMockMetrics = (component) => {
  // Base metrics with some randomization
  const metrics = {
    cpu: {
      usage: Math.random() * 30 + 10, // 10-40%
      cores: 4,
      limit: 100
    },
    memory: {
      usage: Math.random() * 40 + 20, // 20-60%
      used_mb: Math.floor(Math.random() * 1000 + 500),
      total_mb: 4096,
      limit: 100
    },
    disk: {
      usage: Math.random() * 20 + 30, // 30-50%
      used_gb: Math.floor(Math.random() * 10 + 20),
      total_gb: 100,
      limit: 100
    },
    network: {
      rx_mbps: Math.random() * 5,
      tx_mbps: Math.random() * 3,
      connections: Math.floor(Math.random() * 30 + 5)
    }
  };
  
  // Apply special cases for components
  if (component === 'ollama' && global.highMemorySimulation) {
    metrics.memory.usage = global.highMemorySimulation.value;
    metrics.memory.used_mb = Math.floor(global.highMemorySimulation.value * 4096 / 100);
  }
  
  return metrics;
};

// GET metrics endpoint
resourceWatcher.get('/api/metrics/:component', (req, res) => {
  const { component } = req.params;
  const clientId = req.query.client_id || req.headers['x-client-id'] || 'test';
  
  if (!component) {
    return res.status(400).json({ error: 'Component is required' });
  }
  
  const metrics = generateMockMetrics(component);
  
  res.json({
    component,
    client_id: clientId,
    timestamp: new Date().toISOString(),
    metrics
  });
});

// Mock logs
const generateMockLogs = (component, count = 10) => {
  const logLevels = ['INFO', 'WARN', 'ERROR', 'DEBUG'];
  const logMessages = {
    'ollama': [
      'Model loaded successfully',
      'Processing inference request',
      'Cache hit for token prediction',
      'Memory optimizations applied',
      'CUDA acceleration active',
      'BLAS operations offloaded to CPU',
      'Connection pool expanded',
      'Request timeout after 10s',
      'Failed to allocate GPU memory',
      'Model unloaded to free resources'
    ],
    'langchain': [
      'Chain execution started',
      'Retrieved 5 documents from vector store',
      'Prompt tokens: 156',
      'Completion tokens: 423',
      'Total tokens: 579',
      'Chat memory updated',
      'Using cached embedding',
      'LLM API request initiated',
      'Response streaming started',
      'Chain execution completed in 2.3s'
    ],
    'agent-orchestrator': [
      'Scheduled recommendation check',
      'Generated 3 recommendations',
      'Action executed: restart_service',
      'Client connected: test',
      'Updated component status',
      'Syncing configuration with registry',
      'Processed telemetry data',
      'Healthcheck passed for all components',
      'Authorization verified for client',
      'Rate limit applied to client requests'
    ],
    'resource-watcher': [
      'Collecting system metrics',
      'Memory threshold warning: 85%',
      'CPU usage normal',
      'Storage utilization increased',
      'Alert triggered for component',
      'Metrics stored in time-series database',
      'Rolling up hourly statistics',
      'Network throughput spike detected',
      'Resource prediction model updated',
      'Purged metrics older than 30 days'
    ]
  };
  
  // Use default messages if component not recognized
  const messages = logMessages[component] || logMessages['agent-orchestrator'];
  
  // Generate logs with timestamps going backward from now
  const logs = [];
  const now = Date.now();
  
  for (let i = 0; i < count; i++) {
    const timestamp = new Date(now - (i * 60000)).toISOString(); // Each log 1 minute apart
    const level = logLevels[Math.floor(Math.random() * logLevels.length)];
    const message = messages[Math.floor(Math.random() * messages.length)];
    
    logs.push({
      timestamp,
      level,
      component,
      message
    });
  }
  
  return logs;
};

// GET logs endpoint
resourceWatcher.get('/api/logs/:component', (req, res) => {
  const { component } = req.params;
  const clientId = req.query.client_id || req.headers['x-client-id'] || 'test';
  const count = parseInt(req.query.count) || 20;
  
  if (!component) {
    return res.status(400).json({ error: 'Component is required' });
  }
  
  const logs = generateMockLogs(component, count);
  
  res.json({
    component,
    client_id: clientId,
    logs
  });
});

// Simulation endpoint for resource watcher
resourceWatcher.post('/simulate', (req, res) => {
  const { simulation, client_id } = req.body;
  
  if (!simulation || !client_id) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }
  
  console.log(`[resource-watcher] Simulating event: ${simulation.type}`);
  
  switch(simulation.type) {
    case 'high_memory':
      // Set global simulation state
      global.highMemorySimulation = {
        component: simulation.component,
        value: simulation.value,
        active: true
      };
      
      // Set timeout to clear the simulation after duration
      setTimeout(() => {
        global.highMemorySimulation = null;
        console.log(`[resource-watcher] Ended high memory simulation`);
      }, simulation.duration * 1000);
      
      // Also trigger a recommendation in the agent orchestrator
      const recommendation = {
        id: `rec_${Math.random().toString(36).substring(2, 10)}`,
        title: `High memory usage detected in ${simulation.component}`,
        description: `${simulation.component} is using ${simulation.value}% memory. Consider clearing cache or restarting the service.`,
        priority: 'high',
        component: simulation.component,
        action: 'clear_cache',
        created_at: new Date().toISOString(),
        status: 'pending',
        client_id
      };
      
      mockRecommendations.push(recommendation);
      
      res.json({
        success: true,
        message: `Simulating high memory (${simulation.value}%) for ${simulation.component} for ${simulation.duration} seconds`,
        simulation: global.highMemorySimulation,
        recommendation
      });
      break;
      
    default:
      res.json({
        success: true,
        message: `Received simulation ${simulation.type}, but no specific handler implemented.`
      });
  }
});

console.log('AI Suite Mock Server is running');
console.log('- Agent Orchestrator: http://localhost:5210');
console.log('- LangChain: http://localhost:5111');
console.log('- Resource Watcher: http://localhost:5220');
