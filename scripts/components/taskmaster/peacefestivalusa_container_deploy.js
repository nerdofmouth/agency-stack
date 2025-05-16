#!/usr/bin/env node

/**
 * PeaceFestivalUSA Container Deployment Orchestrator
 * Following AgencyStack Charter v1.0.3 principles:
 * - Repository as Source of Truth
 * - Strict Containerization
 * - Proper Change Workflow
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

// AgencyStack Charter-compliant paths
const REPO_ROOT = path.resolve(__dirname, '../../../');
const LOG_DIR = '/var/log/agency_stack/components';
const CLIENT_ID = 'peacefestivalusa';
const LOG_FILE = path.join(LOG_DIR, `${CLIENT_ID}_deployment.log`);

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  } catch (err) {
    console.error(`WARNING: Could not create log directory: ${err.message}`);
  }
}

// Logger function with timestamp
function log(message, type = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${type}] ${message}`;
  
  console.log(logMessage);
  
  try {
    // Write to log file following Charter logging standards
    fs.appendFileSync(LOG_FILE, logMessage + '\n');
  } catch (err) {
    console.error(`WARNING: Could not write to log file: ${err.message}`);
  }
}

// Function to check if running in container
async function checkIfInContainer() {
  try {
    // Check if running in container by looking for .dockerenv or cgroup
    const { stdout: dockerEnv } = await execAsync('[ -f /.dockerenv ] && echo "In Docker" || echo "Not in Docker"');
    if (dockerEnv.trim() === "In Docker") {
      return true;
    }
    
    const { stdout: cgroup } = await execAsync('grep -q "docker\\|lxc" /proc/1/cgroup && echo "In Container" || echo "Not in Container"');
    return cgroup.trim() === "In Container";
  } catch (error) {
    log(`Failed to determine if running in container: ${error.message}`, 'ERROR');
    return false;
  }
}

// Execute shell command and log output
async function executeCommand(command, cwd = REPO_ROOT) {
  log(`Executing: ${command}`, 'COMMAND');
  
  try {
    const { stdout, stderr } = await execAsync(command, { cwd });
    if (stdout) log(stdout.trim(), 'STDOUT');
    if (stderr) log(stderr.trim(), 'STDERR');
    return { success: true, stdout, stderr };
  } catch (error) {
    log(`Command failed: ${error.message}`, 'ERROR');
    if (error.stdout) log(error.stdout.trim(), 'STDOUT');
    if (error.stderr) log(error.stderr.trim(), 'STDERR');
    return { success: false, error, stdout: error.stdout, stderr: error.stderr };
  }
}

// Function to run deployment steps using the agency-stack dev container
async function runInDevContainer() {
  log('Checking for existing dev container', 'INFO');
  
  // Check if container exists
  const { stdout: containerCheck } = await execAsync('docker ps -a --filter "name=agency-stack-dev" --format "{{.Names}}"');
  const containerExists = containerCheck.trim() === 'agency-stack-dev';
  
  if (!containerExists) {
    log('Creating development container following AgencyStack Charter principles', 'INFO');
    
    // Create dev container using repository's create_base_docker_dev.sh script
    await executeCommand('bash scripts/utils/create_base_docker_dev.sh');
  } else {
    log('Development container already exists', 'INFO');
    
    // Make sure the container is running
    const { stdout: containerStatus } = await execAsync('docker inspect --format="{{.State.Running}}" agency-stack-dev');
    if (containerStatus.trim() !== 'true') {
      log('Starting existing container', 'INFO');
      await executeCommand('docker start agency-stack-dev');
    }
  }
  
  // Now execute deployment steps inside the container
  log('Running peacefestivalusa deployment in container', 'INFO');
  
  // Setup WordPress and dependencies
  await executeCommand('docker exec -it agency-stack-dev bash -c "cd /agency_stack && bash scripts/components/install_peacefestivalusa_wordpress.sh --domain peacefestivalusa.localhost --wordpress-port 8082 --admin-email admin@peacefestivalusa.com"');
  
  // Check deployment status
  await executeCommand('docker exec -it agency-stack-dev bash -c "cd /agency_stack && bash scripts/components/install_peacefestivalusa_wordpress.sh --status"');
  
  // Generate a summary of what was deployed
  log('Deployment complete! Summary:', 'SUCCESS');
  log('- PeaceFestivalUSA WordPress deployed inside container', 'SUCCESS');
  log('- Access at http://peacefestivalusa.localhost:8082 (from container networking)', 'INFO');
  
  // Instructions for the next steps
  log('', 'INFO');
  log('NEXT STEPS:', 'INFO');
  log('1. To work with the deployed services:', 'INFO');
  log('   docker exec -it agency-stack-dev bash', 'COMMAND');
  log('2. For remote deployment, follow the AgencyStack Charter remote workflow:', 'INFO');
  log('   - Add SSH key to the remote server', 'INFO');
  log('   - Execute deploy_peacefestivalusa.sh within the container', 'INFO');
}

// Main function
async function main() {
  log('Starting PeaceFestivalUSA deployment orchestration', 'START');
  log('Following AgencyStack Charter v1.0.3 principles', 'INFO');
  
  try {
    const inContainer = await checkIfInContainer();
    
    if (inContainer) {
      // We're already in a container, execute directly
      log('Running in container environment - proceeding with direct execution', 'INFO');
      
      // Create directories as per Charter
      await executeCommand('mkdir -p /var/log/agency_stack/components');
      await executeCommand('mkdir -p /opt/agency_stack/clients/peacefestivalusa');
      
      // Install WordPress
      log('Installing PeaceFestivalUSA WordPress', 'INFO');
      await executeCommand('bash scripts/components/install_peacefestivalusa_wordpress.sh --domain peacefestivalusa.localhost --wordpress-port 8082 --admin-email admin@peacefestivalusa.com');
      
      // Check status
      log('Checking installation status', 'INFO');
      await executeCommand('bash scripts/components/install_peacefestivalusa_wordpress.sh --status');
      
    } else {
      // Not in container, use Charter-compliant dev container
      log('Not running in container - will execute in dev container following Charter principles', 'WARNING');
      await runInDevContainer();
    }
    
    log('Deployment orchestration completed', 'COMPLETE');
    
  } catch (error) {
    log(`Deployment failed: ${error.message}`, 'CRITICAL');
    process.exit(1);
  }
}

// Execute
main();
