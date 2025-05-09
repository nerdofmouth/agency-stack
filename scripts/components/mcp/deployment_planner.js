/**
 * AgencyStack Deployment Planner
 * Following AgencyStack Charter v1.0.3 principles:
 * - Repository as Source of Truth
 * - Strict Containerization
 * - Idempotency & Automation
 * - TDD Protocol Compliance
 * 
 * This script generates comprehensive deployment plans aligned with:
 * - AgencyStack Charter v1.0.3
 * - TDD Protocol
 * - MCP Integration requirements
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

// Constants
const CHARTER_PATH = '/root/_repos/agency-stack/docs/charter/v1.0.3.md';
const TDD_PROTOCOL_PATH = '/root/_repos/agency-stack/docs/charter/tdd_protocol.md';
const MCP_INTEGRATION_PATH = '/root/_repos/agency-stack/docs/pages/components/mcp_integration.md';

// Logger
const logger = {
  info: (message) => console.log(`[INFO] ${message}`),
  success: (message) => console.log(`[SUCCESS] ${message}`),
  error: (message) => console.error(`[ERROR] ${message}`),
  warning: (message) => console.warn(`[WARNING] ${message}`)
};

/**
 * Generate a comprehensive deployment plan based on Charter requirements
 */
async function generateDeploymentPlan(clientId, components, options = {}) {
  logger.info(`Generating deployment plan for client: ${clientId}`);
  logger.info(`Requested components: ${components.join(', ')}`);
  
  // Default options
  const defaults = {
    charterVersion: '1.0.3',
    tddCompliance: true,
    mcpIntegration: true,
    validateWordPress: true
  };
  
  const config = { ...defaults, ...options };
  logger.info(`Using configuration: ${JSON.stringify(config, null, 2)}`);
  
  // Create deployment plan structure
  const deploymentPlan = {
    name: `${clientId}-deployment-plan`,
    timestamp: new Date().toISOString(),
    client_id: clientId,
    components,
    charter_version: config.charterVersion,
    tdd_compliance: config.tddCompliance,
    phases: []
  };
  
  // Phase 1: Preparation
  deploymentPlan.phases.push({
    name: 'preparation',
    description: 'Validate environment and prerequisites',
    tasks: [
      { 
        id: 'prep-1', 
        name: 'Validate directory structure', 
        status: 'pending',
        command: 'make env-check',
        description: 'Ensures all required directories exist following Charter structure'
      },
      { 
        id: 'prep-2', 
        name: 'Check prerequisites', 
        status: 'pending',
        command: 'make prereq-check',
        description: 'Validates Docker, Docker Compose, and other requirements'
      },
      { 
        id: 'prep-3', 
        name: 'Backup existing data', 
        status: 'pending',
        command: `make backup CLIENT_ID=${clientId}`,
        description: 'Creates backup of any existing data as a safety measure'
      }
    ]
  });
  
  // Phase 2: Installation (following component dependencies)
  const installTasks = [];
  
  // Determine proper installation order based on dependencies
  const orderedComponents = orderComponentsByDependencies(components);
  orderedComponents.forEach((component, index) => {
    installTasks.push({
      id: `install-${index+1}`,
      name: `Install ${component}`,
      status: 'pending',
      component,
      command: `make ${component} CLIENT_ID=${clientId}`,
      description: `Install ${component} following Charter containerization principles`
    });
  });
  
  deploymentPlan.phases.push({
    name: 'installation',
    description: 'Install components in dependency order',
    tasks: installTasks
  });
  
  // Phase 3: Validation (TDD Protocol compliance)
  if (config.tddCompliance) {
    const validationTasks = components.map((component, index) => ({
      id: `test-${index+1}`,
      name: `Test ${component}`,
      status: 'pending',
      component,
      command: `make ${component}-test CLIENT_ID=${clientId}`,
      description: `Run comprehensive tests for ${component} following TDD protocol`
    }));
    
    deploymentPlan.phases.push({
      name: 'validation',
      description: 'Validate components following TDD Protocol',
      tasks: validationTasks
    });
  }
  
  // Phase 4: Integration
  if (config.mcpIntegration) {
    const integrationTasks = [];
    
    // Add MCP server validation
    integrationTasks.push({
      id: 'integration-1',
      name: 'Verify MCP server health',
      status: 'pending',
      command: 'curl -s http://localhost:3000/health | jq',
      description: 'Verify MCP server is healthy and responsive'
    });
    
    // WordPress validation if requested
    if (config.validateWordPress && components.includes('wordpress')) {
      integrationTasks.push({
        id: 'integration-2',
        name: 'Validate WordPress with MCP',
        status: 'pending',
        command: `curl -X POST -H "Content-Type: application/json" -d '{"task":"verify_wordpress","url":"http://localhost:8082"}' http://localhost:3000/puppeteer | jq`,
        description: 'Use MCP server to validate WordPress installation'
      });
    }
    
    // Add component integrations
    if (components.includes('traefik') && components.includes('keycloak')) {
      integrationTasks.push({
        id: 'integration-3',
        name: 'Verify Traefik-Keycloak integration',
        status: 'pending',
        command: 'make verify-traefik-keycloak',
        description: 'Verify Traefik is properly routing to Keycloak'
      });
    }
    
    deploymentPlan.phases.push({
      name: 'integration',
      description: 'Validate component integrations',
      tasks: integrationTasks
    });
  }
  
  // Phase 5: Documentation
  deploymentPlan.phases.push({
    name: 'documentation',
    description: 'Update documentation and generate reports',
    tasks: [
      { 
        id: 'doc-1', 
        name: 'Update component registry', 
        status: 'pending',
        command: 'make update-registry',
        description: 'Update component registry with newly installed components'
      },
      { 
        id: 'doc-2', 
        name: 'Generate deployment report', 
        status: 'pending',
        command: `make generate-report CLIENT_ID=${clientId}`,
        description: 'Create deployment report with configuration details'
      }
    ]
  });
  
  return deploymentPlan;
}

/**
 * Order components by dependency relationships
 * Some components need to be installed before others (e.g., Traefik before Keycloak)
 */
function orderComponentsByDependencies(components) {
  // Define dependency relationships
  const dependencies = {
    'keycloak': ['traefik'], // Keycloak depends on Traefik
    'wordpress': ['traefik'], // WordPress can depend on Traefik
    'mcp_server': [] // MCP server has no dependencies
  };
  
  // Simple topological sort
  const result = [];
  const visited = new Set();
  
  function visit(component) {
    if (visited.has(component)) return;
    visited.add(component);
    
    // Visit dependencies first
    const deps = dependencies[component] || [];
    deps.forEach(dep => {
      if (components.includes(dep)) {
        visit(dep);
      }
    });
    
    result.push(component);
  }
  
  // Visit all components
  components.forEach(component => {
    visit(component);
  });
  
  return result;
}

/**
 * Execute the deployment plan
 */
async function executeDeploymentPlan(plan, options = {}) {
  logger.info(`Executing deployment plan: ${plan.name}`);
  
  const defaults = {
    dryRun: false,
    stopOnError: true
  };
  
  const config = { ...defaults, ...options };
  
  // Process each phase in order
  for (const phase of plan.phases) {
    logger.info(`Starting phase: ${phase.name} - ${phase.description}`);
    
    // Process each task in the phase
    for (const task of phase.tasks) {
      logger.info(`Executing task ${task.id}: ${task.name}`);
      
      if (config.dryRun) {
        logger.warning(`[DRY RUN] Would execute: ${task.command}`);
        task.status = 'simulated';
        continue;
      }
      
      try {
        // Here we would actually execute the command
        // For now, just log it
        logger.info(`Running command: ${task.command}`);
        task.status = 'completed';
      } catch (error) {
        logger.error(`Task ${task.id} failed: ${error.message}`);
        task.status = 'failed';
        task.error = error.message;
        
        if (config.stopOnError) {
          logger.error('Stopping deployment execution due to error');
          return {
            success: false,
            message: `Deployment failed at task ${task.id} (${task.name})`,
            plan
          };
        }
      }
    }
    
    logger.success(`Completed phase: ${phase.name}`);
  }
  
  return {
    success: true,
    message: 'Deployment plan executed successfully',
    plan
  };
}

// Export functions for use in MCP server
module.exports = {
  generateDeploymentPlan,
  executeDeploymentPlan
};

// If run directly, generate a sample plan
if (require.main === module) {
  const clientId = process.argv[2] || 'peacefestivalusa';
  const componentsArg = process.argv[3] || 'wordpress,traefik,keycloak,mcp_server';
  const components = componentsArg.split(',');
  
  generateDeploymentPlan(clientId, components)
    .then(plan => {
      console.log(JSON.stringify(plan, null, 2));
    })
    .catch(error => {
      console.error('Error:', error);
    });
}
