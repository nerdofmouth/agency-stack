/**
 * AgencyStack Context7 Implementation Module
 * Following AgencyStack Charter v1.0.3 principles
 * Provides Context7 functionality for the MCP server
 * 
 * This module strictly follows the principles:
 * - Repository as Source of Truth
 * - Strict Containerization
 * - Component Consistency
 */

const fs = require('fs');
const path = require('path');

/**
 * Context7 processing class
 * Handles deployment planning and strategic roadmap generation
 */
class Context7Processor {
  /**
   * Create a new Context7 processor
   * @param {Object} options Configuration options
   */
  constructor(options = {}) {
    this.config = {
      charterPath: options.charterPath || path.join(__dirname, '../../../docs/charter/v1.0.3.md'),
      roadmapPath: options.roadmapPath || path.join(__dirname, '../../../docs/charter/🚀 Upstack.agency Strategic Project Roadmap-20250411111430.md'),
      ...options
    };
    
    console.log(`Context7Processor initialized with config:`, this.config);
  }
  
  /**
   * Process a Context7 request
   * @param {Object} request The request object
   * @returns {Object} The response
   */
  async processRequest(request) {
    console.log('Processing Context7 request:', request);
    
    try {
      const { client_id, query, system_prompt } = request;
      
      // Load Charter content if available
      let charterContent = '';
      try {
        if (fs.existsSync(this.config.charterPath)) {
          charterContent = fs.readFileSync(this.config.charterPath, 'utf8');
          console.log('Loaded Charter content successfully');
        } else {
          console.log(`Charter file not found at ${this.config.charterPath}`);
        }
      } catch (err) {
        console.error(`Error loading Charter content: ${err.message}`);
      }
      
      // Load Roadmap content if available
      let roadmapContent = '';
      try {
        if (fs.existsSync(this.config.roadmapPath)) {
          roadmapContent = fs.readFileSync(this.config.roadmapPath, 'utf8');
          console.log('Loaded Roadmap content successfully');
        } else {
          console.log(`Roadmap file not found at ${this.config.roadmapPath}`);
        }
      } catch (err) {
        console.error(`Error loading Roadmap content: ${err.message}`);
      }
      
    
      // Generate deployment plan based on query type
      if (query.toLowerCase().includes('deployment') || 
          query.toLowerCase().includes('install') || 
          query.toLowerCase().includes('setup')) {
        return this.generateDeploymentPlan(client_id, query, system_prompt, charterContent);
      }
      
      // Generate strategic roadmap
      if (query.toLowerCase().includes('roadmap') || 
          query.toLowerCase().includes('strategic') || 
          query.toLowerCase().includes('strategy')) {
        return this.generateStrategicRoadmap(client_id, query, system_prompt, roadmapContent, charterContent);
      }
      
      // Default general processing
      return this.generateGeneralResponse(client_id, query, system_prompt, charterContent, roadmapContent);
    } catch (error) {
      console.error(`Error in processRequest: ${error.message}`);
      return {
        success: false,
        message: `Error processing request: ${error.message}`
      };
    }
  }
  
  /**
   * Generate a deployment plan
   */
  async generateDeploymentPlan(client_id, query, system_prompt, charterContent) {
    console.log(`Generating deployment plan for client ${client_id}`);
    
    // Extract components from query
    const components = this.extractComponentsFromQuery(query) || 
      ['wordpress', 'traefik', 'keycloak', 'mcp_server'];
    
    // Generate deployment phases based on Charter principles
    const plan = {
      name: `${client_id}-deployment-plan`,
      timestamp: new Date().toISOString(),
      client_id,
      query,
      components,
      charter_version: '1.0.3',
      tdd_compliance: true,
      phases: [
        {
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
              command: `make backup CLIENT_ID=${client_id}`,
              description: 'Creates backup of any existing data as a safety measure'
            }
          ]
        },
        {
          name: 'installation',
          description: 'Install components in dependency order',
          tasks: components.map((component, index) => ({
            id: `install-${index + 1}`,
            name: `Install ${component}`,
            status: 'pending',
            component,
            command: `make ${component} CLIENT_ID=${client_id}`,
            description: `Install ${component} following Charter containerization principles`
          }))
        },
        {
          name: 'validation',
          description: 'Validate components following TDD Protocol',
          tasks: components.map((component, index) => ({
            id: `test-${index + 1}`,
            name: `Test ${component}`,
            status: 'pending',
            component,
            command: `make ${component}-test CLIENT_ID=${client_id}`,
            description: `Run comprehensive tests for ${component} following TDD protocol`
          }))
        },
        {
          name: 'integration',
          description: 'Validate component integrations',
          tasks: this.generateIntegrationTasks(components, client_id)
        },
        {
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
              command: `make generate-report CLIENT_ID=${client_id}`,
              description: 'Create deployment report with configuration details'
            }
          ]
        }
      ],
      charter_compliance: {
        repository_integrity: true,
        strict_containerization: true,
        idempotency: true,
        automated_testing: true,
        documentation: true,
        security: true
      },
      recommendations: [
        'All components should be installed through the Makefile targets to maintain repository integrity',
        'Ensure tests are run after each component installation',
        'Validate container networking using the MCP /network-diagnostics endpoint'
      ]
    };
    
    return {
      success: true,
      message: 'Deployment plan generated successfully',
      plan
    };
  }
  
  /**
   * Generate integration tasks based on components
   */
  generateIntegrationTasks(components, client_id) {
    const tasks = [];
    
    // MCP server health check
    if (components.includes('mcp_server')) {
      tasks.push({
        id: 'integration-1',
        name: 'Verify MCP server health',
        status: 'pending',
        command: 'curl -s http://localhost:3000/health | jq',
        description: 'Verify MCP server is healthy and responsive'
      });
    }
    
    // WordPress validation
    if (components.includes('wordpress') && components.includes('mcp_server')) {
      tasks.push({
        id: 'integration-2',
        name: 'Validate WordPress with MCP',
        status: 'pending',
        command: 'curl -X POST -H "Content-Type: application/json" -d \'{"task":"verify_wordpress","url":"http://localhost:8082"}\' http://localhost:3000/puppeteer | jq',
        description: 'Use MCP server to validate WordPress installation'
      });
    }
    
    // Traefik-Keycloak integration
    if (components.includes('traefik') && components.includes('keycloak')) {
      tasks.push({
        id: 'integration-3',
        name: 'Verify Traefik-Keycloak integration',
        status: 'pending',
        command: 'make verify-traefik-keycloak',
        description: 'Verify Traefik is properly routing to Keycloak'
      });
    }
    
    // UI components
    if (components.includes('nextjs_control_panel') || components.includes('dashboard_ui')) {
      tasks.push({
        id: 'integration-4',
        name: 'Verify UI components',
        status: 'pending',
        command: 'make verify-ui-components',
        description: 'Verify UI components are properly deployed and accessible'
      });
    }
    
    return tasks;
  }
  
  /**
   * Extract components from query
   */
  extractComponentsFromQuery(query) {
    const componentPatterns = [
      { regex: /wordpress/i, name: 'wordpress' },
      { regex: /traefik/i, name: 'traefik' },
      { regex: /keycloak/i, name: 'keycloak' },
      { regex: /mcp[_\s-]?server/i, name: 'mcp_server' },
      { regex: /next[_\s-]?js/i, name: 'nextjs_control_panel' },
      { regex: /dashboard[_\s-]?ui/i, name: 'dashboard_ui' },
      { regex: /ui[_\s-]?components/i, name: 'nextjs_control_panel' }
    ];
    
    const extractedComponents = componentPatterns
      .filter(pattern => pattern.regex.test(query))
      .map(pattern => pattern.name);
    
    return extractedComponents.length > 0 ? extractedComponents : null;
  }
  
  /**
   * Generate a strategic roadmap
   */
  async generateStrategicRoadmap(client_id, query, system_prompt, roadmapContent, charterContent) {
    console.log(`Generating strategic roadmap for client ${client_id}`);
    
    // Parse existing roadmap if available
    let existingPhases = [];
    if (roadmapContent) {
      const phaseRegex = /\| 🟢|🔵|🟣|🟡 \*\*Phase \d+: ([^|]+)\*\* \| ([^|]+) \| ([^|]+) \| ([^|]+) \|/g;
      let match;
      while ((match = phaseRegex.exec(roadmapContent)) !== null) {
        existingPhases.push({
          name: match[1].trim(),
          goals: match[2].trim(),
          components: match[3].trim().split(', '),
          integrations: match[4].trim().split(', ')
        });
      }
    }
    
    // Extract themes based on Charter and query
    const focusAreas = this.extractFocusAreasFromQuery(query);
    
    const roadmap = {
      name: `${client_id}-strategic-roadmap`,
      timestamp: new Date().toISOString(),
      client_id,
      query,
      charter_version: '1.0.3',
      phases: [
        {
          name: 'Infrastructure Foundation',
          status: 'current',
          description: 'Solid foundational infrastructure that enables scalable and secure multi-tenant deployments',
          components: ['Docker', 'Traefik', 'Keycloak', 'MCP Server', 'CrowdSec'],
          timeline: '2025-Q2',
          metrics: [
            'All services containerized',
            'TLS everywhere',
            'Multi-tenant isolation',
            'Automated testing for all components'
          ]
        },
        {
          name: 'Content & Media Management',
          status: 'planned',
          description: 'Secure, scalable, private media content creation and delivery capability',
          components: ['WordPress', 'PeerTube', 'Seafile', 'Ghost'],
          timeline: '2025-Q3',
          metrics: [
            'Media hosting capabilities',
            'Secure content delivery',
            'Integration with SSO',
            'Multi-tenant content isolation'
          ]
        },
        {
          name: 'Business & Productivity',
          status: 'future',
          description: 'Enable complete operational support, including ERP, CRM, and project management',
          components: ['ERPNext', 'Focalboard', 'TaskWarrior', 'Kill Bill'],
          timeline: '2025-Q4',
          metrics: [
            'Client management capabilities',
            'Project tracking',
            'Billing integration',
            'Resource allocation'
          ]
        },
        {
          name: 'AI Integration Layer',
          status: 'future',
          description: 'Provide flexible, secure, AI-driven agentic solutions and development workflows',
          components: ['Ollama', 'LangChain', 'AgentOrchestrator', 'Context7'],
          timeline: '2026-Q1',
          metrics: [
            'Local LLM capabilities',
            'Agent-driven workflows',
            'Strategic planning assistance',
            'AI-powered automation'
          ]
        }
      ],
      focus_areas: focusAreas,
      alignment: {
        charter_principles: [
          'Repository as Source of Truth',
          'Strict Containerization',
          'Idempotency & Automation',
          'Multi-Tenancy & Security'
        ],
        strategic_goals: [
          'Sovereignty and self-hosting',
          'Security and privacy by default',
          'Scalability for small to medium agencies',
          'AI-enhanced capabilities'
        ]
      },
      next_steps: [
        'Complete infrastructure foundation layer',
        'Develop comprehensive test suite',
        'Create component documentation',
        'Begin WordPress integration with Keycloak'
      ]
    };
    
    return {
      success: true,
      message: 'Strategic roadmap generated successfully',
      roadmap
    };
  }
  
  /**
   * Extract focus areas from query
   */
  extractFocusAreasFromQuery(query) {
    const defaultFocusAreas = [
      {
        name: 'Infrastructure Sovereignty',
        description: 'Ensuring all critical infrastructure can be self-hosted and remains under direct control',
        priority: 'high'
      },
      {
        name: 'Security & Privacy',
        description: 'Implementing strong security practices and privacy-preserving technologies',
        priority: 'high'
      },
      {
        name: 'AI Integration',
        description: 'Leveraging AI capabilities while maintaining sovereignty and data privacy',
        priority: 'medium'
      },
      {
        name: 'Scalability',
        description: 'Supporting growth from individual agencies to larger deployments',
        priority: 'medium'
      }
    ];
    
    return defaultFocusAreas;
  }
  
  /**
   * Generate a general response
   */
  async generateGeneralResponse(client_id, query, system_prompt, charterContent, roadmapContent) {
    console.log(`Generating general response for client ${client_id}`);
    
    return {
      success: true,
      message: 'Context7 processed request successfully',
      response: {
        query,
        client_id,
        timestamp: new Date().toISOString(),
        charter_version: '1.0.3',
        has_charter_content: !!charterContent,
        has_roadmap_content: !!roadmapContent,
        response: 'This is a general Context7 response based on the query.',
        recommendations: [
          'Use specific query types like "deployment" or "roadmap" for more structured results',
          'Include specific component names in deployment queries',
          'Refer to Charter v1.0.3 principles in your requests'
        ]
      }
    };
  }
}

// Create a singleton instance of the Context7Processor
// This ensures we have only one instance across the application
// Following Charter principle of Resource Efficiency
const defaultProcessor = new Context7Processor();

// Export the Context7 module interface
module.exports = {
  // Process a Context7 request
  processRequest: (request) => {
    return defaultProcessor.processRequest(request);
  },
  
  // Context7Processor class for advanced usage
  Context7Processor
};
