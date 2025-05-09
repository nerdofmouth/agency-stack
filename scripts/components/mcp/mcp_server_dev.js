/**
 * MCP Server Development Implementation
 * Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
 * Follows principles: Repository as Source of Truth, Idempotency & Automation
 */

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');

// Server configuration
const app = express();
const PORT = process.env.MCP_PORT || 3000;
const CLIENT_ID = process.env.CLIENT_ID || 'agencystack';

// Create logs directory if it doesn't exist
const logDir = path.join(__dirname, '../../../logs/mcp');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Configure logging
const logFile = path.join(logDir, 'mcp_server_dev.log');
const logStream = fs.createWriteStream(logFile, { flags: 'a' });

const log = (message) => {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  logStream.write(logMessage);
  console.log(message);
};

log('Starting MCP Development Server');
log(`CLIENT_ID: ${CLIENT_ID}`);
log(`PORT: ${PORT}`);

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Add middleware to log requests
app.use((req, res, next) => {
  log(`${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  log('Health check endpoint called');
  res.status(200).json({ 
    status: 'healthy', 
    message: 'MCP server is running',
    client_id: CLIENT_ID,
    version: '1.0.0-dev'
  });
});

// Puppeteer endpoint
app.post('/puppeteer', (req, res) => {
  log('Puppeteer endpoint called');
  log(`Request body: ${JSON.stringify(req.body)}`);
  
  res.status(200).json({
    success: true,
    message: 'Puppeteer request processed successfully',
    data: req.body,
    server_info: {
      client_id: CLIENT_ID,
      version: '1.0.0-dev'
    }
  });
});

// Taskmaster endpoint
app.post('/taskmaster', async (req, res) => {
  log('Taskmaster endpoint called');
  log(`Request body: ${JSON.stringify(req.body)}`);
  
  // Get API keys from environment
  const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  const PERPLEXITY_API_KEY = process.env.PERPLEXITY_API_KEY;
  
  log(`API Keys available: Anthropic=${!!ANTHROPIC_API_KEY}, Perplexity=${!!PERPLEXITY_API_KEY}`);
  
  // In development mode, we'll just mock the response
  res.status(200).json({
    success: true,
    message: 'Taskmaster request processed successfully',
    task: req.body.task || 'No task provided',
    server_info: {
      client_id: CLIENT_ID,
      version: '1.0.0-dev',
      api_keys: {
        anthropic: !!ANTHROPIC_API_KEY,
        perplexity: !!PERPLEXITY_API_KEY
      }
    }
  });
});

// Context7 endpoint
app.post('/context7', async (req, res) => {
  log('Context7 endpoint called');
  log(`Request body: ${JSON.stringify(req.body)}`);
  
  res.status(200).json({
    success: true,
    message: 'Context7 request processed successfully',
    context: req.body.context || 'No context provided',
    server_info: {
      client_id: CLIENT_ID,
      version: '1.0.0-dev'
    }
  });
});

// Start the server
app.listen(PORT, () => {
  log(`MCP server listening on port ${PORT}`);
  log(`Client ID: ${CLIENT_ID}`);
  log('Server ready to accept connections');
});
