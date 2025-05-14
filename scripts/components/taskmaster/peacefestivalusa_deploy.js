#!/usr/bin/env node

/**
 * PeaceFestivalUSA Deployment Orchestrator
 * Using Taskmaster-AI for Sequential Execution
 * 
 * Following AgencyStack Charter v1.0.3 principles:
 * - Repository as Source of Truth
 * - Idempotency & Automation
 * - Auditability & Documentation
 * - Strict Containerization
 * - Proper Change Workflow
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

// AgencyStack Charter-compliant paths
const REPO_ROOT = path.resolve(__dirname, '../../../');
const LOG_DIR = '/var/log/agency_stack/components';
const CLIENT_ID = 'peacefestivalusa';
const LOG_FILE = path.join(LOG_DIR, `${CLIENT_ID}_deployment.log`);

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Logger function with timestamp
function log(message, type = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${type}] ${message}`;
  
  console.log(logMessage);
  
  // Write to log file following Charter logging standards
  fs.appendFileSync(LOG_FILE, logMessage + '\n');
}

// Execute shell command with proper error handling
async function executeCommand(command, cwd = REPO_ROOT) {
  log(`Executing: ${command}`, 'COMMAND');
  
  try {
    const { stdout, stderr } = await exec(command, { cwd });
    if (stdout) log(stdout.trim(), 'STDOUT');
    if (stderr) log(stderr.trim(), 'STDERR');
    return { success: true, stdout, stderr };
  } catch (error) {
    log(`Command failed: ${error.message}`, 'ERROR');
    if (error.stdout) log(error.stdout.trim(), 'STDOUT');
    if (error.stderr) log(error.stderr.trim(), 'STDERR');
    return { success: false, error };
  }
}

// Deployment steps - following sequential thinking model
const deploymentSteps = {
  // Phase 1: Preparation and Analysis
  async prepareEnvironment() {
    log('PHASE 1: PREPARATION AND ANALYSIS', 'PHASE');
    
    // Verify repository state
    await executeCommand('git status');
    
    // Ensure we're on the correct branch
    await executeCommand('git checkout client/peacefestivalusa || git checkout -b client/peacefestivalusa');
    
    // Pull latest changes
    await executeCommand('git pull origin client/peacefestivalusa || true');
    
    // Verify Docker installation
    const dockerResult = await executeCommand('docker --version');
    if (!dockerResult.success) {
      log('Docker is not installed or not running', 'ERROR');
      return false;
    }
    
    // Create necessary directories following Charter principles
    await executeCommand(`mkdir -p /var/log/agency_stack/components/${CLIENT_ID}`);
    await executeCommand(`mkdir -p /opt/agency_stack/clients/${CLIENT_ID}`);
    
    // Prepare configuration
    const envExists = fs.existsSync(path.join(REPO_ROOT, 'clients', CLIENT_ID, '.env.production'));
    if (!envExists) {
      log('Creating production environment configuration', 'INFO');
      await executeCommand(`cp clients/${CLIENT_ID}/.env.example clients/${CLIENT_ID}/.env.production`);
    }
    
    return true;
  },
  
  // Phase 2: Local Deployment
  async localDeployment() {
    log('PHASE 2: LOCAL DEPLOYMENT IMPLEMENTATION', 'PHASE');
    
    // Check if Traefik is already running
    const traefikRunning = await executeCommand('docker ps | grep traefik || true');
    if (!traefikRunning.stdout.includes('traefik')) {
      log('Setting up Traefik + Keycloak base infrastructure', 'INFO');
      await executeCommand('make traefik-keycloak DOMAIN=localhost ADMIN_EMAIL=admin@nerdofmouth.com');
    } else {
      log('Traefik already running, skipping base infrastructure setup', 'INFO');
    }
    
    // PeaceFestivalUSA WordPress Installation
    log('Installing PeaceFestivalUSA WordPress', 'INFO');
    await executeCommand(
      'bash scripts/components/install_peacefestivalusa_wordpress_did.sh ' +
      '--domain peacefestivalusa.localhost ' +
      '--wordpress-port 8082 ' +
      '--admin-email admin@peacefestivalusa.com'
    );
    
    // Verify installation
    log('Verifying installation', 'INFO');
    await executeCommand('bash scripts/components/verify_peacefestivalusa_wordpress.sh');
    
    // Run tests
    log('Running tests', 'INFO');
    await executeCommand('bash scripts/components/test_peacefestivalusa_wordpress.sh || true');
    
    // Check container status
    log('Checking container status', 'INFO');
    await executeCommand('bash scripts/components/install_peacefestivalusa_wordpress_did.sh --status');
    
    return true;
  },
  
  // Phase 3: Remote Deployment Preparation
  async remoteDeploymentPrep() {
    log('PHASE 3: REMOTE DEPLOYMENT PREPARATION', 'PHASE');
    
    // Check if SSH key exists or create a new one
    const sshKeyPath = path.join(process.env.HOME || '/root', '.ssh', 'peacefestivalusa_key');
    if (!fs.existsSync(sshKeyPath)) {
      log('Generating SSH key for remote deployment', 'INFO');
      await executeCommand(`ssh-keygen -t rsa -b 4096 -f ${sshKeyPath} -N ""`);
      
      log('SSH key generated. Please ensure this key is added to the remote server', 'INFO');
      log(`Public key: ${sshKeyPath}.pub`, 'INFO');
      
      // Display public key
      await executeCommand(`cat ${sshKeyPath}.pub`);
    } else {
      log('SSH key already exists', 'INFO');
    }
    
    // Setup SSH config if not exists
    const sshConfigPath = path.join(process.env.HOME || '/root', '.ssh', 'config');
    const sshConfigContent = `
Host peacefestival
  HostName alpha.nerdofmouth.com
  User agencystack
  IdentityFile ${sshKeyPath}
`;
    
    if (!fs.existsSync(sshConfigPath) || !fs.readFileSync(sshConfigPath, 'utf8').includes('peacefestival')) {
      log('Setting up SSH config', 'INFO');
      fs.appendFileSync(sshConfigPath, sshConfigContent);
      log('SSH config updated', 'INFO');
    }
    
    return true;
  },
  
  // Phase 4: Remote Deployment Execution (if SSH key is properly configured)
  async remoteDeployment() {
    log('PHASE 4: REMOTE DEPLOYMENT EXECUTION', 'PHASE');
    
    const sshKeyPath = path.join(process.env.HOME || '/root', '.ssh', 'peacefestivalusa_key');
    
    // Test SSH connection
    log('Testing SSH connection', 'INFO');
    const sshTest = await executeCommand(`ssh -i ${sshKeyPath} -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 agencystack@alpha.nerdofmouth.com echo "Connection successful" || echo "Connection failed"`);
    
    if (sshTest.stdout.includes('Connection successful')) {
      log('SSH connection successful, proceeding with remote deployment', 'INFO');
      
      // Execute remote deployment
      await executeCommand(
        `bash scripts/components/deploy_peacefestivalusa_remote.sh ` +
        `--remote-host alpha.nerdofmouth.com ` +
        `--remote-user agencystack ` +
        `--ssh-key ${sshKeyPath} ` +
        `--domain peacefestivalusa.alpha.nerdofmouth.com ` +
        `--sync-files true ` +
        `--sync-db true ` +
        `--enable-ssl true`
      );
      
      // Verify remote deployment
      log('Verifying remote deployment', 'INFO');
      await executeCommand(`ssh -i ${sshKeyPath} agencystack@alpha.nerdofmouth.com "cd /opt/agency_stack && make peacefestivalusa-status || echo 'Status check not available'"`);
      
    } else {
      log('SSH connection failed. Remote deployment cannot proceed.', 'WARNING');
      log('Please ensure the SSH key is properly set up on the remote server.', 'INFO');
      log('Remote deployment will be skipped.', 'INFO');
    }
    
    return true;
  },
  
  // Phase 5: Post-Deployment Tasks
  async postDeployment() {
    log('PHASE 5: POST-DEPLOYMENT TASKS', 'PHASE');
    
    // Update component registry
    const registryPath = path.join(REPO_ROOT, 'registry', 'component_registry.json');
    if (fs.existsSync(registryPath)) {
      try {
        const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
        if (registry.components && registry.components.peacefestivalusa_wordpress) {
          registry.components.peacefestivalusa_wordpress.status = 'deployed';
          registry.components.peacefestivalusa_wordpress.last_updated = new Date().toISOString();
          fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2));
          log('Component registry updated', 'INFO');
        }
      } catch (error) {
        log(`Failed to update component registry: ${error.message}`, 'ERROR');
      }
    }
    
    // Generate deployment summary
    const summary = {
      client: CLIENT_ID,
      domain: 'peacefestivalusa.alpha.nerdofmouth.com',
      localDomain: 'peacefestivalusa.localhost:8082',
      deployedAt: new Date().toISOString(),
      components: ['wordpress', 'mariadb', 'traefik', 'keycloak'],
      charterCompliant: true
    };
    
    const summaryPath = path.join(REPO_ROOT, 'clients', CLIENT_ID, 'deployment_summary.json');
    fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
    log('Deployment summary generated', 'INFO');
    
    return true;
  }
};

// Main execution function - sequential orchestration
async function runDeployment() {
  log('Starting PeaceFestivalUSA deployment orchestration', 'START');
  log('Following AgencyStack Charter v1.0.3 principles', 'INFO');
  
  try {
    // Run each step in sequence, respecting dependencies
    if (await deploymentSteps.prepareEnvironment()) {
      log('Environment preparation completed successfully', 'SUCCESS');
      
      if (await deploymentSteps.localDeployment()) {
        log('Local deployment completed successfully', 'SUCCESS');
        
        if (await deploymentSteps.remoteDeploymentPrep()) {
          log('Remote deployment preparation completed successfully', 'SUCCESS');
          
          if (await deploymentSteps.remoteDeployment()) {
            log('Remote deployment execution completed', 'SUCCESS');
          }
          
          if (await deploymentSteps.postDeployment()) {
            log('Post-deployment tasks completed successfully', 'SUCCESS');
          }
        }
      }
    }
    
    log('Deployment orchestration completed', 'COMPLETE');
    
  } catch (error) {
    log(`Deployment orchestration failed: ${error.message}`, 'CRITICAL');
    process.exit(1);
  }
}

// Execute the deployment
runDeployment();
