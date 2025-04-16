// API endpoint to perform actions on components (restart, logs)
import { execSync } from 'child_process';
import fs from 'fs';

// Function to safely execute a make command
const runMakeCommand = (component, action) => {
  try {
    const command = `cd /opt/agency_stack/repo && make ${component}-${action}`;
    const output = execSync(command, { encoding: 'utf8', timeout: 20000 });
    return { success: true, output };
  } catch (error) {
    return { 
      success: false, 
      output: error.message || 'Command execution failed',
      error: true 
    };
  }
};

// Function to read a component's logs
const getComponentLogs = (component, lines = 100) => {
  const logPath = `/var/log/agency_stack/components/${component}.log`;
  
  if (!fs.existsSync(logPath)) {
    return { exists: false, content: "Log file does not exist." };
  }
  
  try {
    // Use tail to get the last N lines
    const output = execSync(`tail -n ${lines} ${logPath}`, { encoding: 'utf8' });
    return { exists: true, content: output };
  } catch (error) {
    return { exists: false, error: error.message, content: "Failed to read log file." };
  }
};

export default async function handler(req, res) {
  // Only allow GET requests for safety
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }
  
  const { component, action } = req.query;
  
  // Validate component name to prevent command injection
  if (!component || !/^[a-z0-9-]+$/.test(component)) {
    return res.status(400).json({ success: false, error: 'Invalid component name' });
  }
  
  // Handle different actions
  switch (action) {
    case 'restart':
      const restartResult = runMakeCommand(component, 'restart');
      return res.status(restartResult.success ? 200 : 500).json({
        success: restartResult.success,
        action: 'restart',
        component,
        output: restartResult.output,
        timestamp: new Date().toISOString()
      });
      
    case 'logs':
      const logs = getComponentLogs(component);
      return res.status(logs.exists ? 200 : 404).json({
        success: logs.exists,
        action: 'logs',
        component,
        logs: logs.content,
        timestamp: new Date().toISOString()
      });
      
    case 'status':
      const statusResult = runMakeCommand(component, 'status');
      return res.status(statusResult.success ? 200 : 500).json({
        success: statusResult.success,
        action: 'status',
        component,
        output: statusResult.output,
        timestamp: new Date().toISOString()
      });
      
    default:
      return res.status(400).json({
        success: false,
        error: `Unsupported action: ${action}`
      });
  }
}
