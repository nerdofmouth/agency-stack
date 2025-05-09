/**
 * Direct MCP Server Endpoint Testing Script
 * Follows AgencyStack Charter v1.0.3 principles and TDD Protocol
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

// Get container IP from argument or default to localhost
const MCP_IP = process.argv[2] || '172.21.0.2';
const MCP_PORT = 3000;
const MCP_URL = `http://${MCP_IP}:${MCP_PORT}`;

console.log(`Testing MCP server at ${MCP_URL}`);

// Helper function for HTTP requests
function makeRequest(url, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      method: method,
      headers: data ? {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(JSON.stringify(data))
      } : {}
    };

    const req = http.request(url, options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const jsonResponse = responseData ? JSON.parse(responseData) : {};
          resolve({
            statusCode: res.statusCode,
            data: jsonResponse
          });
        } catch (error) {
          resolve({
            statusCode: res.statusCode,
            data: responseData,
            parseError: error.message
          });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Run tests for all endpoints
async function testAllEndpoints() {
  try {
    console.log('1. Testing /health endpoint...');
    const healthResponse = await makeRequest(`${MCP_URL}/health`);
    console.log(`Health Status: ${healthResponse.statusCode}`);
    console.log(JSON.stringify(healthResponse.data, null, 2));
    console.log('-'.repeat(40));
    
    console.log('2. Testing /puppeteer endpoint...');
    const puppeteerResponse = await makeRequest(`${MCP_URL}/puppeteer`, 'POST', {
      task: 'verify_wordpress',
      url: 'http://localhost:8082'
    });
    console.log(`Puppeteer Status: ${puppeteerResponse.statusCode}`);
    console.log(JSON.stringify(puppeteerResponse.data, null, 2));
    console.log('-'.repeat(40));
    
    console.log('3. Testing /taskmaster endpoint...');
    const taskmasterResponse = await makeRequest(`${MCP_URL}/taskmaster`, 'POST', {
      task: 'echo',
      message: 'Testing taskmaster'
    });
    console.log(`Taskmaster Status: ${taskmasterResponse.statusCode}`);
    console.log(JSON.stringify(taskmasterResponse.data, null, 2));
    console.log('-'.repeat(40));
    
    console.log('4. Testing /taskmaster endpoint with deployment_plan...');
    const deploymentResponse = await makeRequest(`${MCP_URL}/taskmaster`, 'POST', {
      task: 'deployment_plan',
      client_id: 'peacefestivalusa',
      components: ['wordpress', 'traefik', 'keycloak']
    });
    console.log(`Deployment Plan Status: ${deploymentResponse.statusCode}`);
    console.log(JSON.stringify(deploymentResponse.data, null, 2));
    console.log('-'.repeat(40));
    
    console.log('5. Testing /context7 endpoint...');
    try {
      const context7Response = await makeRequest(`${MCP_URL}/context7`, 'POST', {
        client_id: 'peacefestivalusa',
        query: 'Create a simple deployment plan',
        system_prompt: 'You are a deployment planning assistant'
      });
      console.log(`Context7 Status: ${context7Response.statusCode}`);
      console.log(JSON.stringify(context7Response.data, null, 2));
    } catch (error) {
      console.log(`Context7 endpoint error: ${error.message}`);
      console.log('This may be expected if endpoint is not yet implemented');
    }
    console.log('-'.repeat(40));
    
    console.log('6. Testing /version endpoint...');
    try {
      const versionResponse = await makeRequest(`${MCP_URL}/version`);
      console.log(`Version Status: ${versionResponse.statusCode}`);
      console.log(JSON.stringify(versionResponse.data, null, 2));
    } catch (error) {
      console.log(`Version endpoint error: ${error.message}`);
      console.log('This may be expected if endpoint is not yet implemented');
    }
    
    console.log('\n=== TEST SUMMARY ===');
    console.log('✅ Tests completed');
    console.log('Check above results for endpoint status');
    
  } catch (error) {
    console.error(`Test execution error: ${error.message}`);
  }
}

// Execute tests
testAllEndpoints();
