// API endpoint to read the component registry
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

export default async function handler(req, res) {
  try {
    // Try to read component registry from the standard location
    let registryPath = '/opt/agency_stack/repo/component_registry.json';
    
    // Fallback paths if the primary one doesn't exist
    const fallbackPaths = [
      '/opt/agency_stack/config/registry/component_registry.json',
      '/root/_repos/agency-stack/config/registry/component_registry.json'
    ];
    
    // Check if primary path exists, if not try fallbacks
    if (!fs.existsSync(registryPath)) {
      for (const fallbackPath of fallbackPaths) {
        if (fs.existsSync(fallbackPath)) {
          registryPath = fallbackPath;
          break;
        }
      }
    }
    
    // If we found a valid registry file, read and parse it
    let registry = [];
    if (fs.existsSync(registryPath)) {
      const registryContent = fs.readFileSync(registryPath, 'utf8');
      registry = JSON.parse(registryContent);
    } else {
      // Fallback to core components if no registry is found
      registry = [
        { 
          name: "traefik", 
          category: "infrastructure",
          description: "Traefik reverse proxy",
          flags: { installed: true, makefile: true }
        },
        { 
          name: "keycloak", 
          category: "security",
          description: "Keycloak identity provider",
          flags: { installed: true, makefile: true, sso: true }
        },
        { 
          name: "dashboard", 
          category: "monitoring",
          description: "Status dashboard",
          flags: { installed: true, makefile: true }
        },
        { 
          name: "posthog", 
          category: "monitoring",
          description: "Analytics platform",
          flags: { installed: false, makefile: true }
        }
      ];
    }
    
    // Return the registry data
    res.status(200).json({
      success: true,
      registry,
      registryPath,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error reading component registry:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to read component registry'
    });
  }
}
