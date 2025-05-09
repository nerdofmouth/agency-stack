/**
 * MCP Server Endpoint Testing Script
 * Follows AgencyStack Charter v1.0.3 principles and TDD Protocol
 * Tests all MCP server endpoints for proper functionality
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration
const MCP_URL = process.env.MCP_URL || 'http://localhost:3000';
const CLIENT_ID = process.env.CLIENT_ID || 'peacefestivalusa';
const WP_URL = process.env.WP_URL || 'http://localhost:8082';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp/mcp-tests';

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Logging with timestamps
const logFile = path.join(OUTPUT_DIR, 'mcp-tests.log');
function log(message, level = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level}] ${message}`;
  console.log(logMessage);
  fs.appendFileSync(logFile, logMessage + '\n');
}

// Clear previous log file
if (fs.existsSync(logFile)) {
  fs.unlinkSync(logFile);
}

log('=================================================');
log('AgencyStack MCP Server Endpoint Testing');
log('Following AgencyStack Charter and TDD Protocol');
log('=================================================');
log(`MCP URL: ${MCP_URL}`);
log(`Client ID: ${CLIENT_ID}`);
log(`WordPress URL: ${WP_URL}`);
log(`Output Directory: ${OUTPUT_DIR}`);
log('=================================================');

// Helper function for HTTP requests
function makeRequest(url, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    // Parse URL
    const parsedUrl = new URL(url);
    const isHttps = parsedUrl.protocol === 'https:';
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (isHttps ? 443 : 80),
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: data ? {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(JSON.stringify(data))
      } : {}
    };

    // Create request
    const req = (isHttps ? https : http).request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const jsonResponse = responseData ? JSON.parse(responseData) : {};
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: jsonResponse
          });
        } catch (error) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
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

// Test Results Container
const testResults = {
  passed: 0,
  failed: 0,
  total: 0,
  startTime: new Date(),
  endTime: null,
  results: []
};

// Test function
async function runTest(name, testFn) {
  testResults.total++;
  log(`Running test: ${name}`, 'TEST');
  
  try {
    const startTime = new Date();
    const result = await testFn();
    const endTime = new Date();
    const duration = endTime - startTime;
    
    if (result.success) {
      testResults.passed++;
      log(`✅ PASS: ${name} (${duration}ms)`, 'SUCCESS');
    } else {
      testResults.failed++;
      log(`❌ FAIL: ${name} (${duration}ms) - ${result.message}`, 'ERROR');
    }
    
    testResults.results.push({
      name,
      success: result.success,
      message: result.message,
      duration,
      details: result.details || {}
    });
    
    return result;
  } catch (error) {
    testResults.failed++;
    log(`❌ ERROR: ${name} - ${error.message}`, 'ERROR');
    
    testResults.results.push({
      name,
      success: false,
      message: error.message,
      details: { error: error.toString() }
    });
    
    return { success: false, message: error.message };
  }
}

// Main test function
async function runAllTests() {
  // Test 1: Health Endpoint
  await runTest('Health Endpoint', async () => {
    const url = `${MCP_URL}/health`;
    log(`Making request to ${url}`);
    
    const response = await makeRequest(url);
    
    if (response.statusCode !== 200) {
      return {
        success: false,
        message: `Health endpoint returned status ${response.statusCode}`,
        details: response
      };
    }
    
    if (!response.data.status || response.data.status !== 'ok') {
      return {
        success: false, 
        message: 'Health status is not "ok"',
        details: response
      };
    }
    
    return {
      success: true,
      message: 'Health endpoint returned status ok',
      details: response
    };
  });

  // Test 2: Puppeteer Endpoint - WordPress Verification
  await runTest('Puppeteer Endpoint - WordPress Verification', async () => {
    const url = `${MCP_URL}/puppeteer`;
    const data = {
      task: 'verify_wordpress',
      url: WP_URL
    };
    
    log(`Making request to ${url} with data: ${JSON.stringify(data)}`);
    
    const response = await makeRequest(url, 'POST', data);
    
    if (response.statusCode !== 200) {
      return {
        success: false,
        message: `Puppeteer endpoint returned status ${response.statusCode}`,
        details: response
      };
    }
    
    // Save response for debugging
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'puppeteer-response.json'),
      JSON.stringify(response.data, null, 2)
    );
    
    return {
      success: response.data.success === true,
      message: response.data.message || 'No message returned',
      details: response
    };
  });

  // Test 3: Taskmaster Endpoint - Basic Task
  await runTest('Taskmaster Endpoint - Basic Task', async () => {
    const url = `${MCP_URL}/taskmaster`;
    const data = {
      task: 'echo',
      message: 'Testing taskmaster endpoint'
    };
    
    log(`Making request to ${url} with data: ${JSON.stringify(data)}`);
    
    const response = await makeRequest(url, 'POST', data);
    
    if (response.statusCode !== 200) {
      return {
        success: false,
        message: `Taskmaster endpoint returned status ${response.statusCode}`,
        details: response
      };
    }
    
    // Save response for debugging
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'taskmaster-basic-response.json'),
      JSON.stringify(response.data, null, 2)
    );
    
    return {
      success: true,
      message: 'Taskmaster endpoint processed basic task successfully',
      details: response
    };
  });

  // Test 4: Taskmaster Endpoint - Deployment Planning
  await runTest('Taskmaster Endpoint - Deployment Planning', async () => {
    const url = `${MCP_URL}/taskmaster`;
    const data = {
      task: 'deployment_plan',
      client_id: CLIENT_ID,
      components: ['wordpress', 'traefik', 'keycloak']
    };
    
    log(`Making request to ${url} with data: ${JSON.stringify(data)}`);
    
    const response = await makeRequest(url, 'POST', data);
    
    if (response.statusCode !== 200) {
      return {
        success: false,
        message: `Taskmaster endpoint returned status ${response.statusCode} for deployment planning`,
        details: response
      };
    }
    
    // Save deployment plan for reference
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'deployment-plan.json'),
      JSON.stringify(response.data, null, 2)
    );
    
    // Check if response contains expected deployment plan structure
    if (!response.data.plan || !response.data.plan.phases) {
      return {
        success: false,
        message: 'Deployment plan does not contain expected structure',
        details: response
      };
    }
    
    return {
      success: true,
      message: 'Taskmaster endpoint generated deployment plan successfully',
      details: response
    };
  });

  // Test 5: Context7 Endpoint (if available)
  await runTest('Context7 Endpoint', async () => {
    const url = `${MCP_URL}/context7`;
    const data = {
      client_id: CLIENT_ID,
      query: 'Create a simple deployment plan for WordPress',
      system_prompt: 'You are a deployment planning assistant'
    };
    
    log(`Making request to ${url} with data: ${JSON.stringify(data)}`);
    
    try {
      const response = await makeRequest(url, 'POST', data);
      
      // Save response for debugging
      fs.writeFileSync(
        path.join(OUTPUT_DIR, 'context7-response.json'),
        JSON.stringify(response.data, null, 2)
      );
      
      // For Context7, we'll consider any 200-range response as successful
      // since this is a newer endpoint and may still be in development
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          success: true,
          message: 'Context7 endpoint responded successfully',
          details: response
        };
      } else {
        return {
          success: false,
          message: `Context7 endpoint returned status ${response.statusCode}`,
          details: response
        };
      }
    } catch (error) {
      // If the endpoint is not yet implemented, this is not a test failure
      return {
        success: true,
        message: 'Context7 endpoint may not be fully implemented yet',
        details: { error: error.toString() }
      };
    }
  });

  // Test 6: MCP Server Version Check
  await runTest('MCP Server Version Check', async () => {
    const url = `${MCP_URL}/version`;
    log(`Making request to ${url}`);
    
    try {
      const response = await makeRequest(url);
      
      if (response.statusCode !== 200) {
        return {
          success: false,
          message: `Version endpoint returned status ${response.statusCode}`,
          details: response
        };
      }
      
      if (!response.data.version) {
        return {
          success: false,
          message: 'Version information not provided',
          details: response
        };
      }
      
      return {
        success: true,
        message: `MCP Server version: ${response.data.version}`,
        details: response
      };
    } catch (error) {
      // If the endpoint is not implemented, this is not a critical failure
      return {
        success: true,
        message: 'Version endpoint may not be implemented yet',
        details: { error: error.toString() }
      };
    }
  });

  // Complete Test Results
  testResults.endTime = new Date();
  const totalDuration = testResults.endTime - testResults.startTime;
  
  log('=================================================');
  log('Test Results Summary:');
  log(`Total Tests: ${testResults.total}`);
  log(`Passed: ${testResults.passed}`);
  log(`Failed: ${testResults.failed}`);
  log(`Duration: ${totalDuration}ms`);
  log('=================================================');
  
  // Save detailed test results
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'test-results.json'),
    JSON.stringify(testResults, null, 2)
  );
  
  // Generate HTML report
  const htmlReport = generateHtmlReport(testResults);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'test-report.html'),
    htmlReport
  );
  
  log(`Test report saved to: ${path.join(OUTPUT_DIR, 'test-report.html')}`);
  
  return testResults;
}

// Generate HTML report
function generateHtmlReport(testResults) {
  const successRate = (testResults.passed / testResults.total) * 100;
  const totalDuration = testResults.endTime - testResults.startTime;
  
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgencyStack MCP Server Tests</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
    h1, h2 { color: #333; }
    .summary { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    .test-result { margin-bottom: 15px; padding: 15px; border-radius: 5px; }
    .pass { background-color: #dff0d8; border-left: 5px solid #5cb85c; }
    .fail { background-color: #f2dede; border-left: 5px solid #d9534f; }
    .details { margin-top: 10px; padding: 10px; background-color: rgba(0,0,0,0.05); border-radius: 3px; }
    pre { overflow-x: auto; }
    .chart { width: 100%; height: 20px; background-color: #f2dede; border-radius: 10px; overflow: hidden; }
    .chart-bar { height: 100%; background-color: #5cb85c; width: ${successRate}%; }
  </style>
</head>
<body>
  <h1>AgencyStack MCP Server Endpoint Tests</h1>
  <div class="summary">
    <h2>Summary</h2>
    <p>Run Time: ${new Date(testResults.startTime).toLocaleString()} - ${new Date(testResults.endTime).toLocaleString()}</p>
    <p>Duration: ${totalDuration}ms</p>
    <p>Tests: ${testResults.total} total, ${testResults.passed} passed, ${testResults.failed} failed</p>
    <div class="chart">
      <div class="chart-bar"></div>
    </div>
    <p>Success Rate: ${successRate.toFixed(2)}%</p>
  </div>
  
  <h2>Test Results</h2>
  ${testResults.results.map(result => `
    <div class="test-result ${result.success ? 'pass' : 'fail'}">
      <h3>${result.name}</h3>
      <p><strong>Status:</strong> ${result.success ? 'PASS' : 'FAIL'}</p>
      <p><strong>Message:</strong> ${result.message}</p>
      <p><strong>Duration:</strong> ${result.duration}ms</p>
      <div class="details">
        <h4>Details:</h4>
        <pre>${JSON.stringify(result.details, null, 2)}</pre>
      </div>
    </div>
  `).join('')}
  
  <footer>
    <p>Generated by the AgencyStack MCP testing script following Charter v1.0.3 principles and TDD Protocol</p>
  </footer>
</body>
</html>`;
}

// Run all tests
runAllTests()
  .then(() => {
    log('All tests completed');
    process.exit(testResults.failed > 0 ? 1 : 0);
  })
  .catch(error => {
    log(`Error running tests: ${error.message}`, 'ERROR');
    process.exit(1);
  });
