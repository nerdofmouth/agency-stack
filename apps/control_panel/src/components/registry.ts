/**
 * Component Registry Loader
 * 
 * Loads and merges component registry data from:
 * - /config/registry/component_registry.json (component definitions)
 * - /var/log/agency_stack/components_status.json (runtime status)
 */

// Component type definitions
export interface ComponentDefinition {
  id: string;
  name: string;
  description: string;
  category: string;
  tags: string[];
  serviceUrl?: string;
  documentationUrl?: string;
  multiTenant: boolean;
  actions: {
    start?: boolean;
    stop?: boolean;
    restart?: boolean;
    logs?: boolean;
    backup?: boolean;
    restore?: boolean;
    configure?: boolean;
  };
}

export interface ComponentStatus {
  id: string;
  status: 'running' | 'stopped' | 'error' | 'warning' | 'unknown';
  version?: string;
  lastUpdated: string;
  message?: string;
  metrics?: {
    cpu?: number;
    memory?: number;
    disk?: number;
    network?: number;
  };
  clientId?: string; // For multi-tenant components
}

export interface Component extends ComponentDefinition {
  status: ComponentStatus;
}

/**
 * Load component registry and merge with runtime status
 */
export async function loadComponentRegistry(): Promise<Component[]> {
  try {
    // In a real implementation, these would be API calls to fetch the data
    // For now, we'll use mock data for development
    
    // Mock data for component definitions
    const componentDefinitions: ComponentDefinition[] = [
      {
        id: 'traefik',
        name: 'Traefik',
        description: 'Edge router and reverse proxy for all services',
        category: 'infrastructure',
        tags: ['routing', 'proxy', 'https'],
        serviceUrl: 'https://traefik.${DOMAIN}',
        documentationUrl: '/docs/components/traefik.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          configure: true
        }
      },
      {
        id: 'portainer',
        name: 'Portainer',
        description: 'Container management interface',
        category: 'infrastructure',
        tags: ['management', 'docker'],
        serviceUrl: 'https://portainer.${DOMAIN}',
        documentationUrl: '/docs/components/portainer.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'wordpress',
        name: 'WordPress',
        description: 'CMS and website platform',
        category: 'application',
        tags: ['cms', 'website', 'multi-tenant'],
        serviceUrl: 'https://wordpress.${DOMAIN}',
        documentationUrl: '/docs/components/wordpress.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true,
          restore: true,
          configure: true
        }
      },
      {
        id: 'n8n',
        name: 'n8n',
        description: 'Workflow automation platform',
        category: 'automation',
        tags: ['automation', 'workflow', 'integration'],
        serviceUrl: 'https://n8n.${DOMAIN}',
        documentationUrl: '/docs/components/n8n.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true
        }
      },
      {
        id: 'ollama',
        name: 'Ollama',
        description: 'Local LLM runner',
        category: 'ai',
        tags: ['ai', 'llm', 'local'],
        serviceUrl: 'https://ollama.${DOMAIN}',
        documentationUrl: '/docs/components/ollama.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          configure: true
        }
      },
      {
        id: 'langchain',
        name: 'LangChain',
        description: 'LLM application framework',
        category: 'ai',
        tags: ['ai', 'framework', 'integration'],
        documentationUrl: '/docs/components/langchain.md',
        multiTenant: false,
        actions: {
          logs: true,
          configure: true
        }
      },
      {
        id: 'ai-dashboard',
        name: 'AI Dashboard',
        description: 'AI system management and monitoring',
        category: 'ai',
        tags: ['ai', 'dashboard', 'monitoring'],
        serviceUrl: 'https://ai.${DOMAIN}',
        documentationUrl: '/docs/components/ai-dashboard.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'prometheus',
        name: 'Prometheus',
        description: 'Metrics collection and monitoring',
        category: 'monitoring',
        tags: ['monitoring', 'metrics'],
        serviceUrl: 'https://prometheus.${DOMAIN}',
        documentationUrl: '/docs/components/prometheus.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'loki',
        name: 'Loki',
        description: 'Log aggregation system',
        category: 'monitoring',
        tags: ['logging', 'monitoring'],
        serviceUrl: 'https://loki.${DOMAIN}',
        documentationUrl: '/docs/components/loki.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'grafana',
        name: 'Grafana',
        description: 'Metrics visualization and dashboards',
        category: 'monitoring',
        tags: ['visualization', 'dashboard', 'monitoring'],
        serviceUrl: 'https://grafana.${DOMAIN}',
        documentationUrl: '/docs/components/grafana.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'keycloak',
        name: 'Keycloak',
        description: 'Identity and access management',
        category: 'security',
        tags: ['auth', 'sso', 'security'],
        serviceUrl: 'https://auth.${DOMAIN}',
        documentationUrl: '/docs/components/keycloak.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true,
          restore: true,
          configure: true
        }
      },
      {
        id: 'minio',
        name: 'MinIO',
        description: 'S3-compatible object storage',
        category: 'storage',
        tags: ['storage', 's3', 'object-storage'],
        serviceUrl: 'https://minio.${DOMAIN}',
        documentationUrl: '/docs/components/minio.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true
        }
      },
      {
        id: 'postgres',
        name: 'PostgreSQL',
        description: 'Relational database',
        category: 'database',
        tags: ['database', 'sql'],
        documentationUrl: '/docs/components/postgres.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true,
          restore: true
        }
      },
      {
        id: 'redis',
        name: 'Redis',
        description: 'In-memory data store',
        category: 'database',
        tags: ['cache', 'database', 'nosql'],
        documentationUrl: '/docs/components/redis.md',
        multiTenant: false,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true
        }
      },
      {
        id: 'peertube',
        name: 'PeerTube',
        description: 'Video hosting platform',
        category: 'application',
        tags: ['video', 'streaming', 'multi-tenant'],
        serviceUrl: 'https://peertube.${DOMAIN}',
        documentationUrl: '/docs/components/peertube.md',
        multiTenant: true,
        actions: {
          start: true,
          stop: true,
          restart: true,
          logs: true,
          backup: true,
          restore: true,
          configure: true
        }
      }
    ];
    
    // Mock data for runtime status
    const componentStatuses: ComponentStatus[] = [
      {
        id: 'traefik',
        status: 'running',
        version: '2.10.5',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 2.5,
          memory: 120,
          network: 15.2
        }
      },
      {
        id: 'portainer',
        status: 'running',
        version: '2.19.1',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 1.2,
          memory: 85,
          network: 3.4
        }
      },
      {
        id: 'wordpress',
        status: 'running',
        version: '6.4.2',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 5.8,
          memory: 340,
          network: 25.7
        },
        clientId: 'client_alpha'
      },
      {
        id: 'n8n',
        status: 'error',
        version: '1.14.0',
        lastUpdated: new Date().toISOString(),
        message: 'Service exited with error code 1',
        metrics: {
          cpu: 0,
          memory: 0,
          network: 0
        }
      },
      {
        id: 'ollama',
        status: 'running',
        version: '0.1.17',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 15.2,
          memory: 1250,
          network: 8.3
        }
      },
      {
        id: 'langchain',
        status: 'running',
        version: '0.0.310',
        lastUpdated: new Date().toISOString()
      },
      {
        id: 'ai-dashboard',
        status: 'running',
        version: '1.0.0',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 3.1,
          memory: 150,
          network: 2.5
        }
      },
      {
        id: 'prometheus',
        status: 'running',
        version: '2.47.2',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 4.3,
          memory: 320,
          network: 18.5
        }
      },
      {
        id: 'loki',
        status: 'running',
        version: '2.9.2',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 6.7,
          memory: 450,
          network: 25.3
        }
      },
      {
        id: 'grafana',
        status: 'running',
        version: '10.2.0',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 2.8,
          memory: 180,
          network: 5.7
        }
      },
      {
        id: 'keycloak',
        status: 'running',
        version: '22.0.4',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 7.2,
          memory: 520,
          network: 12.3
        }
      },
      {
        id: 'minio',
        status: 'warning',
        version: '2023.10.7',
        lastUpdated: new Date().toISOString(),
        message: 'Storage usage above 80%',
        metrics: {
          cpu: 3.5,
          memory: 210,
          disk: 83.2,
          network: 45.7
        },
        clientId: 'client_beta'
      },
      {
        id: 'postgres',
        status: 'running',
        version: '16.0',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 8.5,
          memory: 750,
          disk: 45.3,
          network: 12.8
        }
      },
      {
        id: 'redis',
        status: 'running',
        version: '7.2.3',
        lastUpdated: new Date().toISOString(),
        metrics: {
          cpu: 1.8,
          memory: 95,
          network: 3.2
        }
      },
      {
        id: 'peertube',
        status: 'stopped',
        version: '5.2.0',
        lastUpdated: new Date().toISOString(),
        message: 'Service manually stopped',
        metrics: {
          cpu: 0,
          memory: 0,
          network: 0
        }
      }
    ];

    // In a real application, we would fetch these files:
    // const componentDefinitions = await fetch('/config/registry/component_registry.json').then(res => res.json());
    // const componentStatuses = await fetch('/var/log/agency_stack/components_status.json').then(res => res.json());
    
    // Merge component definitions with their runtime status
    const components: Component[] = componentDefinitions.map(definition => {
      const status = componentStatuses.find(status => status.id === definition.id) || {
        id: definition.id,
        status: 'unknown',
        lastUpdated: new Date().toISOString()
      };
      
      return {
        ...definition,
        status
      };
    });
    
    return components;
  } catch (error) {
    console.error('Failed to load component registry:', error);
    return [];
  }
}

/**
 * Get all unique component categories
 */
export function getAllCategories(components: Component[]): string[] {
  const categories = Array.from(new Set(components.map(component => component.category)));
  return categories;
}

/**
 * Get all unique component tags
 */
export function getAllTags(components: Component[]): string[] {
  const allTags = components.flatMap(component => component.tags);
  const uniqueTags = Array.from(new Set(allTags));
  return uniqueTags;
}

/**
 * Execute a component action
 */
export async function executeComponentAction(
  componentId: string, 
  action: string,
  clientId?: string
): Promise<{success: boolean; message: string}> {
  // In a real implementation, this would make an API call to execute the action
  
  console.log(`Executing ${action} on component ${componentId} ${clientId ? `for client ${clientId}` : ''}`);
  
  // Simulate API call delay
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Mock success response
  return {
    success: true,
    message: `${action.charAt(0).toUpperCase() + action.slice(1)} action completed successfully on ${componentId}`
  };
}
