// WordPress Deployment Script using MCP
const fetch = require('node-fetch');
const { exec } = require('child_process');

// MCP Server endpoints
const MCP_SERVER = "http://localhost:3000";
const PUPPETEER_ENDPOINT = `${MCP_SERVER}/puppeteer`;
const TASKMASTER_ENDPOINT = `${MCP_SERVER}/taskmaster`;

// WordPress deployment configuration
const CLIENT_ID = process.env.CLIENT_ID || "peacefestivalusa";
const DOMAIN = process.env.DOMAIN || "localhost";
const WP_PORT = process.env.WP_PORT || "8082";
const DB_PORT = process.env.DB_PORT || "33061";

// Installation script paths
const SCRIPTS_DIR = "/root/_repos/agency-stack/scripts/components";
const LAUNCHER_SCRIPT = `${SCRIPTS_DIR}/launch_peacefestivalusa_wordpress.sh`;

/**
 * Validate script compliance with AgencyStack Charter
 * @param {string} scriptPath Path to the script to analyze
 * @returns {Promise<boolean>} Whether the script is compliant
 */
async function validateScriptCompliance(scriptPath) {
  console.log(`Validating script compliance: ${scriptPath}`);
  
  try {
    const response = await fetch(PUPPETEER_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        task: 'script_analysis',
        repository: '/root/_repos/agency-stack',
        patterns: [scriptPath]
      })
    });
    
    const result = await response.json();
    console.log(`Script compliance result:`, result);
    
    return result.success;
  } catch (error) {
    console.error(`Error validating script compliance: ${error.message}`);
    return false;
  }
}

/**
 * Execute a shell command
 * @param {string} command Command to execute
 * @returns {Promise<string>} Command output
 */
function executeCommand(command) {
  return new Promise((resolve, reject) => {
    console.log(`Executing: ${command}`);
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error(`Command error: ${error.message}`);
        return reject(error);
      }
      
      if (stderr) {
        console.warn(`Command stderr: ${stderr}`);
      }
      
      console.log(`Command stdout: ${stdout}`);
      resolve(stdout);
    });
  });
}

/**
 * Connect the MCP server container to WordPress network
 * This is required for container-to-container and container-to-host communication
 * @returns {Promise<boolean>} Whether network connection was successful
 */
async function setupMcpNetworking() {
  console.log('Setting up MCP server networking for WordPress validation');
  
  try {
    // Connect to both potential networks that WordPress might be on
    // Following AgencyStack principle of strict containerization
    const networkCommands = [
      'docker network connect peacefestivalusa_peacefestival_network mcp-server',
      'docker network connect pfusa_network mcp-server'
    ];
    
    for (const cmd of networkCommands) {
      try {
        await executeCommand(cmd);
        console.log(`Successfully connected to network: ${cmd}`);
      } catch (networkError) {
        console.warn(`Network connection warning (this might be ok): ${networkError.message}`);
        // Continue with other networks even if one fails
      }
    }
    
    return true;
  } catch (error) {
    console.error(`Error setting up MCP networking: ${error.message}`);
    return false;
  }
}

/**
 * Verify WordPress installation using multiple networking approaches
 * @param {string} domain Domain or hostname
 * @param {string} port Port number
 * @returns {Promise<Object>} Verification results with detailed data
 */
async function verifyWordPress(domain, port) {
  const urls = [
    // External URL (accessible from host)
    `http://${domain}:${port}`,
    // Docker special hostname (container-to-host)
    'http://host.docker.internal:8082',
    // Internal container name (container-to-container)
    'http://wordpress',
    // Alternative container name (container-to-container)
    'http://pfusa_rebuilt_wordpress'
  ];
  
  console.log('Verifying WordPress through multiple networking paths');
  
  let successfulVerification = null;
  const verificationResults = {};
  
  // Try each URL until one succeeds
  for (const url of urls) {
    console.log(`Attempting to verify WordPress at: ${url}`);
    
    try {
      const response = await fetch(PUPPETEER_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          task: 'verify_wordpress',
          url
        })
      });
      
      const result = await response.json();
      verificationResults[url] = result;
      
      console.log(`WordPress verification result for ${url}:`, result);
      
      // If this verification succeeded, we can stop trying other URLs
      if (result.success) {
        console.log(`✅ Successfully verified WordPress at: ${url}`);
        successfulVerification = {
          url,
          result
        };
        break;
      }
    } catch (error) {
      console.error(`Error verifying WordPress at ${url}: ${error.message}`);
      verificationResults[url] = { success: false, error: error.message };
    }
  }
  
  return {
    success: successfulVerification !== null,
    bestResult: successfulVerification,
    allResults: verificationResults
  };
}

/**
 * Main deployment function
 */
async function deployWordPress() {
  console.log(`\n=== Starting WordPress Deployment for ${CLIENT_ID} ===\n`);
  
  try {
    // Step 1: Validate script compliance
    console.log('\n--- Step 1: Validating script compliance with AgencyStack Charter ---');
    const isCompliant = await validateScriptCompliance(LAUNCHER_SCRIPT);
    
    if (!isCompliant) {
      throw new Error('Script is not compliant with AgencyStack Charter. Deployment aborted.');
    }
    
    console.log('Script compliance validation passed.');
    
    // Step 2: Notify MCP server of deployment start
    console.log('\n--- Step 2: Notifying MCP server of deployment ---');
    await fetch(TASKMASTER_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        task: 'deployment_notification',
        client: CLIENT_ID,
        component: 'wordpress',
        status: 'started',
        metadata: {
          domain: DOMAIN,
          wp_port: WP_PORT,
          db_port: DB_PORT
        }
      })
    });
    
    // Step 3: Execute WordPress launch script
    console.log('\n--- Step 3: Launching WordPress ---');
    const launchCommand = `bash ${LAUNCHER_SCRIPT}`;
    await executeCommand(launchCommand);
    
    // Step 4: Setup MCP networking for WordPress validation
    console.log('\n--- Step 4: Setting up MCP networking for validation ---');
    await setupMcpNetworking();
    
    // Step 5: Verify WordPress installation
    console.log('\n--- Step 5: Verifying WordPress installation ---');
    const verificationResults = await verifyWordPress(DOMAIN, WP_PORT);
    
    if (!verificationResults.success) {
      console.warn('⚠️ WordPress verification challenges:');
      console.warn(JSON.stringify(verificationResults.allResults, null, 2));
      throw new Error('WordPress verification failed. Deployment may have issues.');
    }
    
    const verifiedUrl = verificationResults.bestResult.url;
    const verifiedDetails = verificationResults.bestResult.result.data;
    
    // Log details about the verified WordPress site
    console.log('\n--- WordPress Verification Details ---');
    console.log(`Frontend title: ${verifiedDetails.siteFrontend.title}`);
    console.log(`Admin accessible: ${verifiedDetails.adminPanel.accessible}`);
    console.log(`WordPress detected: ${verifiedDetails.siteFrontend.isWordPress}`);
    
    // Step 6: Notify MCP server of deployment completion
    console.log('\n--- Step 6: Notifying MCP server of deployment completion ---');
    await fetch(TASKMASTER_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        task: 'deployment_notification',
        client: CLIENT_ID,
        component: 'wordpress',
        status: 'completed',
        metadata: {
          domain: DOMAIN,
          wp_port: WP_PORT,
          db_port: DB_PORT,
          url: `http://${DOMAIN}:${WP_PORT}`,
          verificationDetails: verifiedDetails
        }
      })
    });
    
    console.log(`\n=== WordPress Deployment for ${CLIENT_ID} Completed Successfully ===\n`);
    console.log(`WordPress URL: http://${DOMAIN}:${WP_PORT}`);
    console.log(`WordPress Admin: http://${DOMAIN}:${WP_PORT}/wp-admin`);
    console.log(`Database Port: ${DB_PORT}`);
    
    return true;
  } catch (error) {
    console.error(`\n=== WordPress Deployment Failed: ${error.message} ===\n`);
    
    // Notify MCP server of deployment failure
    try {
      await fetch(TASKMASTER_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          task: 'deployment_notification',
          client: CLIENT_ID,
          component: 'wordpress',
          status: 'failed',
          metadata: {
            error: error.message
          }
        })
      });
    } catch (notifyError) {
      console.error(`Failed to notify MCP server of deployment failure: ${notifyError.message}`);
    }
    
    return false;
  }
}

// Execute the deployment if this script is run directly
if (require.main === module) {
  deployWordPress()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error(`Unhandled error: ${error.message}`);
      process.exit(1);
    });
}

module.exports = { deployWordPress, validateScriptCompliance, verifyWordPress, setupMcpNetworking };
