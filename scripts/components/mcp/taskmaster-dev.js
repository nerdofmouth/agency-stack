#!/usr/bin/env node
/**
 * Taskmaster-AI Development Implementation
 * Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
 * Follows principles: Repository as Source of Truth, Idempotency & Automation
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

// Create logs directory if it doesn't exist
const logDir = path.join(__dirname, '../../../logs/mcp');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Configure logging
const logFile = path.join(logDir, 'taskmaster_dev.log');
const logStream = fs.createWriteStream(logFile, { flags: 'a' });

function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  logStream.write(logMessage);
  console.log(message);
}

// Parse command line arguments
const args = process.argv.slice(2);
const helpArg = args.find(arg => arg === '--help' || arg === '-h');
const versionArg = args.find(arg => arg === '--version' || arg === '-v');
const port = process.env.MCP_PORT || 3008;
const clientId = process.env.CLIENT_ID || 'agencystack';

// Get API keys from environment
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const PERPLEXITY_API_KEY = process.env.PERPLEXITY_API_KEY;

// Handle help command
if (helpArg) {
  console.log(`
  Taskmaster-AI Development Tool

  Usage:
    taskmaster-dev [options] [command]

  Options:
    --help, -h     Show help information
    --version, -v  Show version information

  Commands:
    create         Create a new task
    list           List all tasks
    execute        Execute a task
  `);
  process.exit(0);
}

// Handle version command
if (versionArg) {
  console.log('Taskmaster-AI Development Tool v1.0.0');
  process.exit(0);
}

// If no command specified, start the service
log('Starting Taskmaster-AI Development Tool');
log(`Client ID: ${clientId}`);
log(`Port: ${port}`);
log(`API Keys: Anthropic=${!!ANTHROPIC_API_KEY}, Perplexity=${!!PERPLEXITY_API_KEY}`);

// Start a simple HTTP server for local testing
const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/taskmaster') {
    let body = '';
    
    req.on('data', chunk => {
      body += chunk.toString();
    });
    
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        log(`Request received: ${JSON.stringify(data)}`);
        
        const response = {
          success: true,
          message: 'Taskmaster-AI request processed successfully',
          task: data.task || 'No task provided',
          client_id: clientId,
          api_info: {
            anthropic: !!ANTHROPIC_API_KEY,
            perplexity: !!PERPLEXITY_API_KEY
          },
          version: '1.0.0-dev'
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
      } catch (error) {
        log(`Error processing request: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: error.message }));
      }
    });
  } else if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', service: 'taskmaster-ai', client_id: clientId }));
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(port, () => {
  log(`Taskmaster-AI service listening on port ${port}`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  log('Shutting down Taskmaster-AI service');
  server.close(() => {
    log('Service stopped');
    process.exit(0);
  });
});
