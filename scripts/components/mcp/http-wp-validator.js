// WordPress Validation with HTTP Requests
// For AgencyStack MCP Server Integration
// Repository as Source of Truth - No direct host modifications

/**
 * HTTP WordPress Validator
 * Validates WordPress site and admin panel accessibility
 * 
 * Following AgencyStack Charter principles:
 * - Repository as Source of Truth
 * - Strict Containerization
 * - Proper Change Workflow
 */

const http = require('http');
const https = require('https');
const url = require('url');
const fs = require('fs');
const path = require('path');
const child_process = require('child_process');
const os = require('os');

// Logger for debugging container network issues
const logger = {
  info: (message) => console.log(`[INFO] ${message}`),
  error: (message) => console.error(`[ERROR] ${message}`),
  debug: (message) => console.log(`[DEBUG] ${message}`)
};

// Container network mapping - follows AgencyStack strict containerization principles
const CONTAINER_NETWORK_MAPPING = {
  // Direct container-to-container communication uses internal container networks
  // For WordPress containers, we need special handling due to redirects
  'pfusa_rebuilt_wordpress': { host: '172.20.0.3', port: 80, ignoreRedirects: true },
  'wordpress': { host: '172.20.0.3', port: 80, ignoreRedirects: true },
  '172.20.0.3': { keepAsIs: true, ignoreRedirects: true },
  
  // External access uses host mapping
  'host.docker.internal': { keepAsIs: true },
  'localhost': { keepAsIs: true }
};

// Track redirects to avoid loops
const redirectTracker = new Set();

/**
 * Modified URLs for different network contexts:
 * When connecting between containers, we use port 80 not 8082
 * Following AgencyStack Charter principles of proper containerization
 */
function normalizeContainerUrl(targetUrl) {
  if (!targetUrl) return targetUrl;
  
  logger.debug(`Normalizing URL: ${targetUrl}`);
  
  // Parse the URL to extract host information
  const parsedUrl = url.parse(targetUrl);
  const hostName = parsedUrl.hostname;
  
  // Check if we have a mapping for this host
  if (CONTAINER_NETWORK_MAPPING[hostName]) {
    const mapping = CONTAINER_NETWORK_MAPPING[hostName];
    
    // If we should keep as is (for external access like localhost), just return
    if (mapping.keepAsIs) {
      logger.debug(`Keeping URL as is for external access: ${targetUrl}`);
      return targetUrl;
    }
    
    // Apply container network mapping
    const protocol = parsedUrl.protocol || 'http:';
    const path = parsedUrl.path || '/';
    const port = mapping.port || 80;
    
    const containerUrl = `${protocol}//${mapping.host}:${port}${path}`;
    logger.info(`Mapped URL ${targetUrl} to container network URL ${containerUrl}`);
    return containerUrl;
  }
  
  // Default case for unknown hosts - try the original URL
  logger.debug(`No container mapping for ${hostName}, using original URL`);
  return targetUrl;
}

/**
 * Detect environment type to determine proper URL handling
 * Following AgencyStack Charter requirements for container networking
 */
function detectEnvironment() {
  // Check if running in Docker container
  const isContainer = fs.existsSync('/.dockerenv');
  
  // Check for WSL environment
  let isWSL = false;
  try {
    const osRelease = fs.readFileSync('/proc/sys/kernel/osrelease', 'utf8').toLowerCase();
    isWSL = osRelease.includes('microsoft') || osRelease.includes('wsl');
  } catch (err) {
    // Not WSL if file doesn't exist
  }
  
  return { isContainer, isWSL };
}

/**
 * Get network configuration from bridge file if available
 */
function getNetworkConfig() {
  // Try to read network configuration
  let config = null;
  const scriptDir = path.dirname(require.main ? require.main.filename : __filename);
  const repoRoot = path.resolve(scriptDir, '../../..');
  const configPaths = [
    '/etc/agency_stack/network/config.json',  // Container path
    path.join(repoRoot, 'configs/network/bridge_config.json') // Repo path
  ];
  
  for (const configPath of configPaths) {
    try {
      if (fs.existsSync(configPath)) {
        console.log(`Loading network config from ${configPath}`);
        config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        break;
      }
    } catch (err) {
      console.log(`Error reading network config from ${configPath}: ${err.message}`);
    }
  }
  
  return config;
}

/**
 * Map URL for proper container-to-container or host-to-container communication
 * This follows the AgencyStack Charter principle of ensuring containerization
 */
function mapUrl(url) {
  // Parse original URL
  const parsedUrl = new URL(url);
  const { isContainer, isWSL } = detectEnvironment();
  const config = getNetworkConfig();
  
  // Only modify URL if we're in a container and have a config
  if (isContainer && config && parsedUrl.hostname === 'localhost') {
    // Map localhost:8082 to wordpress:8082 for container-to-container communication
    if (parsedUrl.port === '8082') {
      console.log('Detected WordPress URL, remapping for container access');
      parsedUrl.hostname = 'wordpress';
    }
    // Map localhost:3000 to mcp-server:3000 for container-to-container communication
    else if (parsedUrl.port === '3000') {
      console.log('Detected MCP Server URL, remapping for container access');
      parsedUrl.hostname = 'mcp-server';
    }
  } else if (isWSL && parsedUrl.hostname === 'localhost') {
    // Keep localhost, as it will resolve correctly in WSL
    console.log('WSL environment detected, keeping localhost');
  }
  
  return parsedUrl.toString();
}

// Helper function to perform HTTP request and return content
function makeRequest(targetUrl) {
  // Normalize URL for container environment
  const normalizedUrl = normalizeContainerUrl(targetUrl);
  
  // Map the URL according to environment for proper container networking
  const mappedUrl = mapUrl(normalizedUrl);
  
  if (mappedUrl !== normalizedUrl) {
    console.log(`Remapped URL: ${normalizedUrl} -> ${mappedUrl}`);
  }
  
  return new Promise((resolve, reject) => {
    // Parse the URL to determine http vs https
    const parsedUrl = new URL(mappedUrl);
    const httpModule = parsedUrl.protocol === 'https:' ? https : http;
    
    logger.info(`Making request to: ${mappedUrl} (normalized from ${targetUrl})`);
    
    // Set timeout to avoid hanging requests
    const timeoutMs = 10000; // 10 seconds
    
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
      path: parsedUrl.pathname + parsedUrl.search,
      method: 'GET',
      headers: {
        'User-Agent': 'AgencyStack-MCP-Validator/1.0',
        'Host': parsedUrl.hostname, // Important for containerized environments
        'Connection': 'close' // Don't keep connections alive in container networks
      },
      timeout: timeoutMs // Set request timeout
    };
    
    logger.debug(`Request options: ${JSON.stringify(options)}`);
    
    const req = httpModule.request(options, (res) => {
      let data = '';
      
      // Handle redirects (e.g., for wp-admin) with special handling for containerized environments
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        logger.debug(`Redirect detected from ${mappedUrl} to ${res.headers.location}`);
        
        // Special handling for WordPress container redirects that often point to wrong ports
        const redirectUrl = res.headers.location;
        const currentHostname = parsedUrl.hostname;
        
        // If this is a known container with ignoreRedirects flag, handle specially
        if (CONTAINER_NETWORK_MAPPING[currentHostname] && 
            CONTAINER_NETWORK_MAPPING[currentHostname].ignoreRedirects) {
          
          // Prevent redirect loops
          if (redirectTracker.has(normalizedUrl)) {
            logger.debug(`Avoiding redirect loop for ${normalizedUrl}`);
            // Just continue with current response instead of following redirect
            redirectTracker.clear(); // Reset for next request
          } else {
            // Track this URL to prevent loops
            redirectTracker.add(normalizedUrl);
            
            // For container redirects, use the original hostname but update the path
            try {
              const redirectUrlObj = new URL(redirectUrl);
              const newPath = redirectUrlObj.pathname + redirectUrlObj.search;
              
              // Create a normalized redirect URL using the original container network mapping
              const containerRedirectUrl = `${parsedUrl.protocol}//${parsedUrl.hostname}:${options.port}${newPath}`;
              logger.info(`Remapping container redirect to: ${containerRedirectUrl}`);
              
              return makeRequest(containerRedirectUrl)
                .then(resolve)
                .catch(reject);
            } catch (error) {
              logger.error(`Error handling container redirect: ${error.message}`);
              // Continue with response rather than failing
            }
          }
        } else {
          // Standard redirect handling for non-container or keepAsIs hosts
          logger.debug(`Following standard redirect to: ${redirectUrl}`);
          return makeRequest(redirectUrl)
            .then(resolve)
            .catch(reject);
        }
      }
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          content: data,
          ok: res.statusCode >= 200 && res.statusCode < 300
        });
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.end();
  });
}

// WordPress site validation function using HTTP requests
async function validateWordPressSite(targetUrl) {
  logger.info(`🔍 Validating WordPress site at ${targetUrl}`);
  
  const results = {
    success: false,
    siteFrontend: { accessible: false },
    adminPanel: { accessible: false },
    errors: []
  };
  
  // Try multiple container network approaches for WordPress validation
  // This follows AgencyStack Charter principle of container network flexibility
  const possibleUrls = [
    targetUrl, // Original URL (might be external)
    `http://pfusa_rebuilt_wordpress`, // Docker service name
    `http://172.20.0.3`, // Direct container IP
    `http://wordpress` // Docker service alias
  ];
  
  // Log all URLs we'll try
  logger.info(`Will attempt validation with these URLs: ${possibleUrls.join(', ')}`);
  
  // Try each URL until one works
  let frontendSuccess = false;
  
  for (const currentUrl of possibleUrls) {
    if (frontendSuccess) break;
    
    logger.info(`Attempting WordPress validation with URL: ${currentUrl}`);
    
    try {
      // Check site frontend
      logger.debug(`Checking site frontend at ${currentUrl}`);
      try {
        const frontendResponse = await makeRequest(currentUrl);
        
        if (!frontendResponse.ok) {
          logger.debug(`Frontend response not OK: ${frontendResponse.statusCode}`);
          continue; // Try next URL
        }
        
        const htmlContent = frontendResponse.content;
        
        // Check if it looks like WordPress
        const isWordPress = 
          htmlContent.includes('wp-content') || 
          htmlContent.includes('wp-includes') || 
          htmlContent.includes('wp-admin');
        
        if (!isWordPress) {
          logger.debug(`Response doesn't look like WordPress: ${currentUrl}`);
          continue; // Try next URL
        }
        
        // Look for title
        const titleMatch = htmlContent.match(/<title>([^<]+)<\/title>/i);
        const title = titleMatch ? titleMatch[1] : 'Unknown';
        
        results.siteFrontend = {
          accessible: frontendResponse.ok,
          statusCode: frontendResponse.statusCode,
          isWordPress,
          title,
          url: currentUrl
        };
        
        logger.info(`✅ Frontend accessible: ${title} (WordPress: ${isWordPress})`);
        frontendSuccess = true;
        
        // Now check admin panel for this successful frontend URL
        const adminUrl = `${currentUrl}/wp-admin/`;
        logger.info(`Checking admin panel at ${adminUrl}`);
        
        try {
          const adminResponse = await makeRequest(adminUrl);
          
          const adminContent = adminResponse.content;
          
          // Check if login form exists
          const loginFormExists = 
            adminContent.includes('loginform') || 
            adminContent.includes('user_login') ||
            adminContent.includes('wp-login');
          
          results.adminPanel = {
            accessible: adminResponse.ok,
            statusCode: adminResponse.statusCode,
            loginFormExists,
            url: adminUrl
          };
          
          logger.info(`✅ Admin panel accessible: ${adminResponse.statusCode} Login form exists: ${loginFormExists}`);
        } catch (error) {
          logger.error(`Error accessing admin panel: ${error.message}`);
          results.errors.push(`Admin panel error: ${error.message}`);
          results.adminPanel.error = error.message;
        }
      } catch (error) {
        logger.error(`Error accessing frontend at ${currentUrl}: ${error.message}`);
        // Continue to next URL instead of failing immediately
      }
    } catch (error) {
      logger.error(`General error with URL ${currentUrl}: ${error.message}`);
    }
  }
  
  // If we didn't find a working URL, add the original error
  if (!frontendSuccess && possibleUrls.length > 0) {
    results.errors.push(`Frontend error: Could not access WordPress at any of the attempted URLs`);
    results.siteFrontend.error = 'WordPress site not accessible via any network path';
  }
  
  // Overall success determination
  results.success = results.siteFrontend.accessible && results.adminPanel.accessible;
  
  logger.info('Validation results:');
  logger.debug(JSON.stringify(results, null, 2));
  
  return results;
}

// Network diagnostic function to help troubleshoot container connectivity
// Follows AgencyStack Charter principle of Auditability & Documentation
async function diagnoseNetworkIssues(targetUrl) {
  const diagnostics = {
    timestamp: new Date().toISOString(),
    url: targetUrl,
    environment: detectEnvironment(),
    networkConfig: getNetworkConfig(),
    dnsResolution: null,
    ping: null,
    curl: null
  };
  
  // Parse URL to get hostname
  const parsedUrl = new URL(targetUrl);
  const hostname = parsedUrl.hostname;
  
  try {
    // DNS lookup
    diagnostics.dnsResolution = await new Promise((resolve) => {
      require('dns').lookup(hostname, (err, address) => {
        if (err) resolve({ success: false, error: err.message });
        else resolve({ success: true, address });
      });
    });
    
    // Ping test (only works in container with appropriate privileges)
    try {
      const pingOutput = child_process.execSync(`ping -c 1 -W 2 ${hostname}`, { timeout: 3000 }).toString();
      diagnostics.ping = { success: true, output: pingOutput };
    } catch (err) {
      diagnostics.ping = { success: false, error: err.message };
    }
    
    // Curl test
    try {
      const curlOutput = child_process.execSync(`curl -sI ${targetUrl}`, { timeout: 5000 }).toString();
      diagnostics.curl = { success: true, output: curlOutput };
    } catch (err) {
      diagnostics.curl = { success: false, error: err.message };
    }
  } catch (err) {
    console.error(`Error during network diagnostics: ${err.message}`);
  }
  
  return diagnostics;
}

// Export validation function and network utilities
module.exports = {
  validateWordPressSite,
  diagnoseNetworkIssues,
  detectEnvironment,
  mapUrl
};

// If script is run directly, execute validation with command line arguments
if (require.main === module) {
  const siteUrl = process.argv[2] || 'http://localhost:8082';
  
  validateWordPressSite(siteUrl)
    .then(results => {
      console.log('Validation complete');
      process.exit(results.success ? 0 : 1);
    })
    .catch(error => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}
