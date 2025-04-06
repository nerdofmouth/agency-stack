/**
 * Component Registry
 * 
 * This file defines the dynamic component registry that powers
 * the AgencyStack control panel UI. Components can be registered
 * and discovered dynamically for maximum extensibility.
 */

export interface ComponentStatus {
  status: 'healthy' | 'warning' | 'error' | 'inactive';
  message?: string;
  lastUpdated: string;
}

export interface AgencyComponent {
  id: string;
  name: string;
  description: string;
  category: 'core' | 'business' | 'content' | 'collaboration' | 'marketing' | 'integration' | 'monitoring';
  icon: string; // React icon component name
  url?: string;
  makefile_target?: string;
  status: ComponentStatus;
  clientAccess: boolean; // Whether clients can access this component
  adminOnly: boolean;
}

// Initial component registry - in production, this would be loaded from a server/API
export const componentRegistry: AgencyComponent[] = [
  {
    id: 'traefik',
    name: 'Traefik',
    description: 'Edge router and reverse proxy',
    category: 'core',
    icon: 'SiTraefik',
    url: '/traefik',
    makefile_target: 'traefik-status',
    status: {
      status: 'healthy',
      message: 'Running',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: false,
    adminOnly: true
  },
  {
    id: 'portainer',
    name: 'Portainer',
    description: 'Container management UI',
    category: 'core',
    icon: 'SiDocker',
    url: '/portainer',
    makefile_target: 'portainer-status',
    status: {
      status: 'healthy',
      message: 'Running',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: false,
    adminOnly: true
  },
  {
    id: 'droneci',
    name: 'DroneCI',
    description: 'Continuous Integration server',
    category: 'core',
    icon: 'SiDrone',
    url: '/drone',
    makefile_target: 'drone-status',
    status: {
      status: 'healthy',
      message: 'Running',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: false,
    adminOnly: true
  },
  {
    id: 'wordpress',
    name: 'WordPress',
    description: 'Content management system',
    category: 'content',
    icon: 'SiWordpress',
    url: '/wordpress',
    makefile_target: 'wordpress-status',
    status: {
      status: 'inactive',
      message: 'Not installed',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: true,
    adminOnly: false
  },
  {
    id: 'erp',
    name: 'ERPNext',
    description: 'Enterprise Resource Planning',
    category: 'business',
    icon: 'SiSap',
    url: '/erp',
    makefile_target: 'erp-status',
    status: {
      status: 'warning',
      message: 'Config needed',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: true,
    adminOnly: false
  },
  {
    id: 'listmonk',
    name: 'Listmonk',
    description: 'Newsletter and mailing list manager',
    category: 'marketing',
    icon: 'SiMailchimp',
    url: '/listmonk',
    makefile_target: 'listmonk-status',
    status: {
      status: 'inactive',
      message: 'Not installed',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: true,
    adminOnly: false
  },
  {
    id: 'netdata',
    name: 'Netdata',
    description: 'Performance monitoring',
    category: 'monitoring',
    icon: 'SiGrafana',
    url: '/netdata',
    makefile_target: 'netdata-status',
    status: {
      status: 'healthy',
      message: 'Running',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: false,
    adminOnly: true
  },
  {
    id: 'n8n',
    name: 'n8n',
    description: 'Workflow automation',
    category: 'integration',
    icon: 'SiZapier',
    url: '/n8n',
    makefile_target: 'n8n-status',
    status: {
      status: 'error',
      message: 'Service unavailable',
      lastUpdated: new Date().toISOString()
    },
    clientAccess: true,
    adminOnly: false
  }
];

/**
 * Get component by ID
 */
export const getComponentById = (id: string): AgencyComponent | undefined => {
  return componentRegistry.find(component => component.id === id);
};

/**
 * Get components by category
 */
export const getComponentsByCategory = (category: string): AgencyComponent[] => {
  return componentRegistry.filter(component => component.category === category);
};

/**
 * Get components filtered by client access
 */
export const getComponentsByClientAccess = (clientAccess: boolean): AgencyComponent[] => {
  return componentRegistry.filter(component => component.clientAccess === clientAccess);
};

/**
 * Get all component categories
 */
export const getAllCategories = (): string[] => {
  const categories = new Set<string>();
  componentRegistry.forEach(component => categories.add(component.category));
  return Array.from(categories);
};
