/**
 * AgencyStack Context7 Server
 * Follows AgencyStack Charter v1.0.3 principles
 * Standalone Context7 server that can be deployed as a separate container
 */

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Import local Context7 implementation
const context7 = require('./context7-impl');
console.log('Local Context7 implementation loaded');

// Create Express app
const app = express();
const PORT = process.env.CONTEXT7_PORT || 3007;
const CLIENT_ID = process.env.CLIENT_ID || 'peacefestivalusa';

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Add request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    message: 'Context7 server is running',
    timestamp: new Date().toISOString()
  });
});

// Main Context7 endpoint
app.post('/process', async (req, res) => {
  console.log('Context7 request received:', req.body);
  
  try {
    const result = await context7.processRequest(req.body);
    res.status(200).json(result);
  } catch (error) {
    console.error(`Error processing Context7 request: ${error.message}`);
    res.status(500).json({
      success: false,
      message: `Error processing Context7 request: ${error.message}`
    });
  }
});

// Version endpoint
app.get('/version', (req, res) => {
  res.status(200).json({
    version: '1.0.0',
    name: 'Context7 Server',
    charter_compliance: true,
    timestamp: new Date().toISOString()
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Context7 server listening on port ${PORT}`);
  console.log(`Client ID: ${CLIENT_ID}`);
});
