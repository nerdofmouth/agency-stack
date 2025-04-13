import React, { useState, useEffect } from 'react';
import { InstallCard } from '../../components/ui/install-card';

// Mock fetch function to simulate retrieving component status from component_registry.json
const fetchComponentStatus = async (clientId: string) => {
  // In a real implementation, this would read from the local file system or API:
  // /opt/agency_stack/clients/${clientId}/config/component_registry.json
  
  // Mock response data
  return {
    components: [
      {
        name: 'KillBill',
        category: 'Business Applications',
        description: 'Open-source subscription billing and invoicing',
        version: '0.24.0',
        status: 'running',
        lastUpdated: new Date().toISOString(),
        ports: {
          primary: 8080,
          admin: 9090
        }
      },
      {
        name: 'Keycloak',
        category: 'Security',
        description: 'Identity and access management',
        version: '21.0.1',
        status: 'running',
        lastUpdated: new Date(Date.now() - 1800000).toISOString(),
        ports: {
          primary: 8090
        }
      },
      {
        name: 'Seafile',
        category: 'Content & Collaboration',
        description: 'File synchronization and sharing',
        version: '10.0.1',
        status: 'failed',
        lastUpdated: new Date(Date.now() - 3600000).toISOString(),
        ports: {
          primary: 8082
        }
      },
      {
        name: 'PeerTube',
        category: 'Content & Media',
        description: 'Video streaming platform',
        version: '5.1.0',
        status: 'installing',
        lastUpdated: new Date(Date.now() - 600000).toISOString(),
        ports: {
          primary: 9000
        }
      }
    ]
  };
};

// Mock function to execute a make command to view logs
const viewComponentLogs = (componentName: string) => {
  // In a real implementation, this would run:
  // make ${componentName.toLowerCase()}-logs
  console.log(`Executing: make ${componentName.toLowerCase()}-logs`);
  
  // This would typically be handled by a terminal process or API call
  // For this example, we'll simulate writing to the UI log
  const logMessage = `[${new Date().toISOString()}] User viewed logs for ${componentName}`;
  
  // In production, this would write to:
  // /var/log/agency_stack/ui/install-card.log
  console.log('Log entry:', logMessage);
  
  // Show logs in a modal or panel
  alert(`Viewing logs for ${componentName}...\n\nThis would show the real logs from /var/log/agency_stack/components/${componentName.toLowerCase()}.log`);
};

// Mock function to execute a make command to view metrics
const viewComponentMetrics = (componentName: string) => {
  // In a real implementation, this would fetch metrics from Prometheus/Grafana
  console.log(`Fetching metrics for ${componentName}`);
  
  // Log the action
  const logMessage = `[${new Date().toISOString()}] User viewed metrics for ${componentName}`;
  console.log('Log entry:', logMessage);
  
  // Show metrics in a modal or panel
  alert(`Viewing metrics for ${componentName}...\n\nThis would show real metrics from the monitoring system.`);
};

// Mock function to restart a component 
const restartComponent = async (componentName: string) => {
  // In a real implementation, this would run:
  // make ${componentName.toLowerCase()}-restart
  console.log(`Executing: make ${componentName.toLowerCase()}-restart`);
  
  // Log the action
  const logMessage = `[${new Date().toISOString()}] User restarted ${componentName}`;
  console.log('Log entry:', logMessage);
  
  // Return promise to simulate async operation
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      alert(`${componentName} restarted successfully`);
      resolve();
    }, 2000);
  });
};

/**
 * This example demonstrates how the InstallCard component would integrate
 * with the AgencyStack dashboard, component registry, and monitoring system.
 * 
 * Following AgencyStack's sovereignty principles, all operations are:
 * 1. Local-first (using make commands and local logs)
 * 2. Tracked in repository-defined log locations
 * 3. Connected to existing AgencyStack management tools
 */
export default function DashboardIntegration() {
  const [clientId, setClientId] = useState('default');
  const [components, setComponents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [componentStatus, setComponentStatus] = useState<Record<string, string>>({});
  
  useEffect(() => {
    const loadComponents = async () => {
      setLoading(true);
      try {
        const data = await fetchComponentStatus(clientId);
        setComponents(data.components);
        
        // Initialize status map
        const statusMap: Record<string, string> = {};
        data.components.forEach((component: any) => {
          statusMap[component.name] = component.status;
        });
        setComponentStatus(statusMap);
      } catch (error) {
        console.error('Failed to load components:', error);
      } finally {
        setLoading(false);
      }
    };
    
    loadComponents();
  }, [clientId]);
  
  const handleRestart = async (componentName: string) => {
    // Update local status immediately for better UX
    setComponentStatus(prev => ({
      ...prev,
      [componentName]: 'restarting'
    }));
    
    // Execute restart and wait for completion
    await restartComponent(componentName);
    
    // Update status after restart
    setComponentStatus(prev => ({
      ...prev,
      [componentName]: 'running'
    }));
  };
  
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold">AgencyStack Dashboard</h1>
        <p className="text-muted-foreground">
          Client ID: {clientId}
        </p>
      </div>
      
      {loading ? (
        <div className="flex items-center justify-center p-12">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
          <p className="ml-2">Loading components...</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
          {components.map((component) => (
            <InstallCard
              key={component.name}
              name={component.name}
              status={componentStatus[component.name] as any}
              description={component.description}
              version={component.version}
              lastUpdated={component.lastUpdated}
              onViewLogs={() => viewComponentLogs(component.name)}
              onViewMetrics={() => viewComponentMetrics(component.name)}
              onRestart={() => handleRestart(component.name)}
              clientId={clientId}
            />
          ))}
        </div>
      )}
      
      <div className="mt-8 text-sm text-muted-foreground">
        <p>
          Note: This example demonstrates how InstallCard integrates with the AgencyStack ecosystem.
          In a real implementation, actions would:
        </p>
        <ul className="list-disc pl-5 mt-2">
          <li>Execute standard Makefile targets (e.g., make killbill-logs)</li>
          <li>Log actions to /var/log/agency_stack/ui/install-card.log</li>
          <li>Read status from /opt/agency_stack/clients/${'{CLIENT_ID}'}/config/component_registry.json</li>
        </ul>
      </div>
    </div>
  );
}
