// API endpoint to get status of all components
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

// Function to safely execute a make command and capture its output
const runMakeCommand = (component, action = 'status') => {
  try {
    const command = `cd /opt/agency_stack/repo && make ${component}-${action}`;
    const output = execSync(command, { encoding: 'utf8', timeout: 10000 });
    return { success: true, output };
  } catch (error) {
    return { 
      success: false, 
      output: error.message || 'Command execution failed',
      error: true 
    };
  }
};

// Function to check if component is installed by looking for marker file
const isComponentInstalled = (component, clientId = 'default') => {
  const markerPath = path.join('/opt/agency_stack/clients', clientId, component, '.installed_ok');
  return fs.existsSync(markerPath);
};

// Function to read component logs
const readComponentLogs = (component, lines = 10) => {
  const logPath = path.join('/var/log/agency_stack/components', `${component}.log`);
  
  if (!fs.existsSync(logPath)) {
    return { exists: false, content: [] };
  }
  
  try {
    const log = fs.readFileSync(logPath, 'utf8');
    const logLines = log.split('\n').slice(-lines);
    return { exists: true, content: logLines };
  } catch (error) {
    return { exists: false, error: error.message, content: [] };
  }
};

// Function to check component status
const checkComponentStatus = (component) => {
  // Check if component is installed
  const installed = isComponentInstalled(component);
  
  // Get status from make command
  const status = runMakeCommand(component);
  
  // Parse the status output to determine if running
  const isRunning = !status.error && !status.output.includes('not running') && 
                    !status.output.includes('not installed') && 
                    !status.output.includes('❌');
  
  // Get recent logs
  const logs = readComponentLogs(component);
  
  // Determine status icon
  let statusIcon = '⚠️'; // Default to warning
  if (installed && isRunning) {
    statusIcon = '✅'; // Success
  } else if (!installed) {
    statusIcon = '❓'; // Not installed
  } else if (!isRunning) {
    statusIcon = '❌'; // Installed but not running
  }
  
  return {
    component,
    installed,
    running: isRunning,
    statusIcon,
    statusOutput: status.output,
    logs: logs.content,
    timestamp: new Date().toISOString()
  };
};

// Get all components from component registry
const getComponentsFromRegistry = () => {
  try {
    const registryPath = '/opt/agency_stack/repo/component_registry.json';
    
    if (!fs.existsSync(registryPath)) {
      // Fallback to a list of known components
      return [
        'traefik', 'keycloak', 'dashboard', 'posthog', 'prometheus', 
        'grafana', 'mailu', 'chatwoot', 'wordpress', 'peertube'
      ];
    }
    
    const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
    return registry.map(comp => comp.name);
  } catch (error) {
    console.error('Error reading component registry:', error);
    // Fallback to core components
    return ['traefik', 'keycloak', 'dashboard'];
  }
};

export default async function handler(req, res) {
  const clientId = req.query.clientId || 'default';
  
  try {
    // Get list of components
    const components = getComponentsFromRegistry();
    
    // Check status for each component
    const statuses = components.map(component => checkComponentStatus(component));
    
    // Calculate system-wide status
    const systemStatus = {
      total: statuses.length,
      running: statuses.filter(s => s.running).length,
      installed: statuses.filter(s => s.installed).length,
      timestamp: new Date().toISOString()
    };
    
    // Include system status in the response
    res.status(200).json({
      success: true,
      systemStatus,
      components: statuses
    });
  } catch (error) {
    console.error('API error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Unknown error'
    });
  }
}
