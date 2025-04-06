/**
 * Commands Page
 * 
 * Provides a GUI interface for executing CLI commands from the Makefile
 */

'use client';

import { useState, useEffect } from 'react';
import { useClientId } from '@/hooks/useClientId';

// Define the Makefile target interface
interface MakefileTarget {
  id: string;
  name: string;
  description: string;
  command: string;
  category: string;
  clientSafe: boolean; // Whether this command is safe for clients to execute
  requiresConfirmation: boolean;
  showOutput: boolean;
}

// Mock Makefile targets - in production, this would be loaded from a backend API
const makefileTargets: MakefileTarget[] = [
  {
    id: 'install-core',
    name: 'Install Core Services',
    description: 'Install essential infrastructure components (Traefik, Portainer, etc.)',
    command: 'make install-core',
    category: 'installation',
    clientSafe: false,
    requiresConfirmation: true,
    showOutput: true
  },
  {
    id: 'install-wordpress',
    name: 'Install WordPress',
    description: 'Install and configure WordPress CMS',
    command: 'make install-wordpress',
    category: 'installation',
    clientSafe: false,
    requiresConfirmation: true,
    showOutput: true
  },
  {
    id: 'backup-all',
    name: 'Backup All Systems',
    description: 'Create a complete backup of all data and configurations',
    command: 'make backup-all',
    category: 'maintenance',
    clientSafe: false,
    requiresConfirmation: true,
    showOutput: true
  },
  {
    id: 'system-status',
    name: 'System Status',
    description: 'Check the status of all services and components',
    command: 'make system-status',
    category: 'monitoring',
    clientSafe: true,
    requiresConfirmation: false,
    showOutput: true
  },
  {
    id: 'update-core',
    name: 'Update Core',
    description: 'Update all core components to latest versions',
    command: 'make update-core',
    category: 'maintenance',
    clientSafe: false,
    requiresConfirmation: true,
    showOutput: true
  },
  {
    id: 'restart-all',
    name: 'Restart All Services',
    description: 'Restart all services (use with caution)',
    command: 'make restart-all',
    category: 'maintenance',
    clientSafe: false,
    requiresConfirmation: true,
    showOutput: true
  },
  {
    id: 'clear-cache',
    name: 'Clear Cache',
    description: 'Clear all system caches',
    command: 'make clear-cache',
    category: 'maintenance',
    clientSafe: true,
    requiresConfirmation: false,
    showOutput: true
  },
  {
    id: 'security-scan',
    name: 'Security Scan',
    description: 'Run security scan on all components',
    command: 'make security-scan',
    category: 'security',
    clientSafe: false,
    requiresConfirmation: false,
    showOutput: true
  }
];

export default function CommandsPage() {
  const { clientId, isAdmin } = useClientId();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [runningCommand, setRunningCommand] = useState<string | null>(null);
  const [commandOutput, setCommandOutput] = useState<string>('');
  const [confirmingCommand, setConfirmingCommand] = useState<string | null>(null);
  
  // Get all unique categories
  const categories = Array.from(new Set(makefileTargets.map(target => target.category)));
  
  // Filter targets based on search term, category, and client access permissions
  const filteredTargets = makefileTargets.filter(target => {
    const matchesSearch = searchTerm === '' || 
      target.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      target.description.toLowerCase().includes(searchTerm.toLowerCase());
      
    const matchesCategory = selectedCategory === null || target.category === selectedCategory;
    
    // Only admins can see non-clientSafe commands
    const hasPermission = isAdmin() || target.clientSafe;
    
    return matchesSearch && matchesCategory && hasPermission;
  });
  
  // Execute a command
  const executeCommand = (targetId: string) => {
    const target = makefileTargets.find(t => t.id === targetId);
    
    if (!target) return;
    
    if (target.requiresConfirmation && confirmingCommand !== targetId) {
      setConfirmingCommand(targetId);
      return;
    }
    
    // Reset confirmation state
    setConfirmingCommand(null);
    
    // Set as running
    setRunningCommand(targetId);
    setCommandOutput('Executing command...\n');
    
    // In a real implementation, this would make an API call to execute the command
    // For now, we'll simulate the command execution with a timeout
    setTimeout(() => {
      // Mock command output
      setCommandOutput(prev => prev + `\n$ ${target.command}\nRunning ${target.name}...\n`);
      
      // Simulate command progress
      const interval = setInterval(() => {
        setCommandOutput(prev => prev + '.\n');
      }, 500);
      
      // Simulate command completion
      setTimeout(() => {
        clearInterval(interval);
        setCommandOutput(prev => prev + `\nCommand completed successfully.\n`);
        setRunningCommand(null);
      }, 3000);
    }, 1000);
  };
  
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-agency-800 dark:text-agency-100">
          Commands
        </h1>
        <p className="mt-1 text-agency-600 dark:text-agency-300">
          Execute AgencyStack CLI commands from the web interface
        </p>
      </div>
      
      {/* Filters */}
      <div className="flex flex-col md:flex-row gap-4">
        {/* Search Filter */}
        <div className="flex-1">
          <div className="relative">
            <div className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
              <svg className="w-4 h-4 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
              </svg>
            </div>
            <input
              type="search"
              className="block w-full p-2.5 pl-10 text-sm border rounded-lg bg-white dark:bg-agency-800 border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200"
              placeholder="Search commands..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        {/* Category Filter */}
        <div className="md:w-64">
          <select
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={selectedCategory || ''}
            onChange={(e) => setSelectedCategory(e.target.value === '' ? null : e.target.value)}
          >
            <option value="">All Categories</option>
            {categories.map((category) => (
              <option key={category} value={category}>
                {category.charAt(0).toUpperCase() + category.slice(1)}
              </option>
            ))}
          </select>
        </div>
      </div>
      
      {/* Command List */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {filteredTargets.map((target) => (
          <div 
            key={target.id}
            className="card hover:shadow-lg transition-shadow"
          >
            <div className="flex flex-col h-full">
              <div>
                <h3 className="text-lg font-medium text-agency-800 dark:text-agency-100">
                  {target.name}
                </h3>
                <p className="text-sm text-agency-600 dark:text-agency-400">
                  {target.description}
                </p>
                <div className="mt-2">
                  <span className="inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-agency-100 text-agency-800 dark:bg-agency-800 dark:text-agency-200">
                    {target.category}
                  </span>
                  {!target.clientSafe && (
                    <span className="ml-2 inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                      Admin Only
                    </span>
                  )}
                </div>
              </div>
              
              <div className="mt-4 pt-4 border-t border-gray-200 dark:border-agency-700 flex-grow flex flex-col justify-end">
                <div className="flex items-center justify-between">
                  <code className="text-xs bg-agency-100 dark:bg-agency-800 px-2 py-1 rounded">
                    {target.command}
                  </code>
                  
                  {runningCommand === target.id ? (
                    <button 
                      className="btn btn-secondary text-sm py-1 opacity-50 cursor-not-allowed"
                      disabled
                    >
                      Running...
                    </button>
                  ) : confirmingCommand === target.id ? (
                    <div className="flex gap-2">
                      <button 
                        className="btn btn-danger text-sm py-1"
                        onClick={() => executeCommand(target.id)}
                      >
                        Confirm
                      </button>
                      <button 
                        className="btn btn-secondary text-sm py-1"
                        onClick={() => setConfirmingCommand(null)}
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button 
                      className="btn btn-primary text-sm py-1"
                      onClick={() => executeCommand(target.id)}
                    >
                      Execute
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
      
      {/* Command Output */}
      {runningCommand && (
        <div className="mt-8">
          <h3 className="text-lg font-medium mb-2 text-agency-800 dark:text-agency-100">
            Command Output
          </h3>
          <div className="bg-black text-green-400 p-4 rounded-lg font-mono text-sm overflow-auto max-h-96">
            <pre>{commandOutput}</pre>
          </div>
        </div>
      )}
      
      {filteredTargets.length === 0 && (
        <div className="text-center py-10">
          <p className="text-agency-600 dark:text-agency-400">
            No commands match your filters.
          </p>
        </div>
      )}
    </div>
  );
}
