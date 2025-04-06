/**
 * ComponentPanel.tsx
 * 
 * Reusable UI component for displaying component status and actions
 */

'use client';

import { useState } from 'react';
import { Component, executeComponentAction } from './registry';
import { useClientId } from '@/hooks/useClientId';

interface ComponentPanelProps {
  component: Component;
  onActionComplete?: () => void;
}

export default function ComponentPanel({ component, onActionComplete }: ComponentPanelProps) {
  const { clientId, isAdmin, readOnlyMode, canPerformActions } = useClientId();
  const [isExpanded, setIsExpanded] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  
  // Get appropriate status color
  const getStatusColor = (status: string) => {
    const colorMapping = {
      running: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      stopped: 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200',
      warning: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
      error: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
      unknown: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    };
    
    return colorMapping[status as keyof typeof colorMapping] || colorMapping.unknown;
  };
  
  // Format action name for display
  const formatActionName = (action: string): string => {
    return action.charAt(0).toUpperCase() + action.slice(1);
  };
  
  // Check if component is accessible to current user
  const isAccessible = (): boolean => {
    // If component is multi-tenant, check if current user has access
    if (component.multiTenant && !isAdmin()) {
      return component.status.clientId === clientId;
    }
    return true;
  };
  
  // Execute component action
  const handleAction = async (action: string) => {
    // If in read-only mode, show message but don't execute action
    if (readOnlyMode) {
      setActionMessage("Read-only mode: Actions disabled for demo/testing");
      return;
    }
    
    try {
      setActionLoading(action);
      setActionMessage(null);
      
      const result = await executeComponentAction(
        component.id, 
        action, 
        component.multiTenant ? clientId || undefined : undefined
      );
      
      setActionMessage(result.message);
      
      // Notify parent of completed action
      if (onActionComplete) {
        onActionComplete();
      }
    } catch (error) {
      setActionMessage(`Failed to execute ${action}: ${error}`);
    } finally {
      setActionLoading(null);
    }
  };
  
  // Replace ${DOMAIN} placeholder in URLs
  const formatUrl = (url: string | undefined): string | undefined => {
    if (!url) return undefined;
    return url.replace('${DOMAIN}', 'agency-stack.local'); // Would use actual domain in production
  };
  
  // Check if client can access this component
  const canAccess = isAccessible();
  
  return (
    <div className={`card hover:shadow-lg transition-shadow ${!canAccess ? 'opacity-50' : ''}`}>
      <div className="flex justify-between items-start">
        <div className="flex items-center">
          <div className={`p-2 rounded-lg ${getStatusColor(component.status.status)}`}>
            {/* Icon based on category */}
            {component.category === 'infrastructure' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path fillRule="evenodd" d="M3 5a2 2 0 012-2h10a2 2 0 012 2v8a2 2 0 01-2 2h-2.22l.123.489.804.804A1 1 0 0113 18H7a1 1 0 01-.707-1.707l.804-.804L7.22 15H5a2 2 0 01-2-2V5zm5.771 7H5V5h10v7H8.771z" clipRule="evenodd" />
              </svg>
            )}
            {component.category === 'application' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
              </svg>
            )}
            {component.category === 'ai' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" />
              </svg>
            )}
            {component.category === 'monitoring' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 0l-2 2a1 1 0 101.414 1.414L8 10.414l1.293 1.293a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            )}
            {component.category === 'database' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3c0 1.657-3.134 3-7 3s-7-1.343-7-3z" />
                <path d="M3 7v3c0 1.657 3.134 3 7 3s7-1.343 7-3V7c0 1.657-3.134 3-7 3S3 8.657 3 7z" />
                <path d="M17 5c0 1.657-3.134 3-7 3S3 6.657 3 5s3.134-3 7-3 7 1.343 7 3z" />
              </svg>
            )}
            {component.category === 'security' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            )}
            {component.category === 'storage' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4z" />
                <path fillRule="evenodd" d="M18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z" clipRule="evenodd" />
              </svg>
            )}
            {component.category === 'automation' && (
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M5 3a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2V5a2 2 0 00-2-2H5zM5 11a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2v-2a2 2 0 00-2-2H5zM11 5a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V5zM14 11a1 1 0 011 1v1h1a1 1 0 110 2h-1v1a1 1 0 11-2 0v-1h-1a1 1 0 110-2h1v-1a1 1 0 011-1z" />
              </svg>
            )}
          </div>
          <div className="ml-4">
            <h3 className="text-lg font-medium text-agency-800 dark:text-agency-100">
              {component.name}
              {component.status.version && (
                <span className="text-xs ml-2 text-agency-600 dark:text-agency-400">
                  v{component.status.version}
                </span>
              )}
            </h3>
            <p className="text-sm text-agency-600 dark:text-agency-400">
              {component.description}
            </p>
          </div>
        </div>
        
        <div className="flex flex-col items-end">
          <span className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${getStatusColor(component.status.status)}`}>
            {component.status.status.charAt(0).toUpperCase() + component.status.status.slice(1)}
          </span>
          
          {component.multiTenant && component.status.clientId && (
            <span className="text-xs mt-1 text-agency-600 dark:text-agency-400">
              Client: {component.status.clientId}
            </span>
          )}
          
          {readOnlyMode && (
            <span className="text-xs mt-1 text-amber-600 dark:text-amber-400 font-medium">
              Read-only Mode
            </span>
          )}
        </div>
      </div>
      
      <div className="mt-2 flex flex-wrap gap-2">
        {component.tags.map(tag => (
          <span key={tag} className="inline-flex items-center text-xs font-medium px-2 py-0.5 rounded-full bg-agency-100 text-agency-800 dark:bg-agency-800 dark:text-agency-200">
            {tag}
          </span>
        ))}
      </div>
      
      {/* Expandable content */}
      {isExpanded && (
        <div className="mt-4 pt-4 border-t border-gray-200 dark:border-agency-700">
          {/* Component Metrics */}
          {component.status.metrics && (
            <div className="mb-4">
              <h4 className="text-sm font-medium text-agency-800 dark:text-agency-100 mb-2">
                Metrics
              </h4>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                {component.status.metrics.cpu !== undefined && (
                  <div className="bg-agency-50 dark:bg-agency-800 p-2 rounded-lg">
                    <div className="text-xs text-agency-600 dark:text-agency-400">CPU</div>
                    <div className="text-sm font-medium">{component.status.metrics.cpu}%</div>
                  </div>
                )}
                {component.status.metrics.memory !== undefined && (
                  <div className="bg-agency-50 dark:bg-agency-800 p-2 rounded-lg">
                    <div className="text-xs text-agency-600 dark:text-agency-400">Memory</div>
                    <div className="text-sm font-medium">{component.status.metrics.memory} MB</div>
                  </div>
                )}
                {component.status.metrics.disk !== undefined && (
                  <div className="bg-agency-50 dark:bg-agency-800 p-2 rounded-lg">
                    <div className="text-xs text-agency-600 dark:text-agency-400">Disk</div>
                    <div className="text-sm font-medium">{component.status.metrics.disk}%</div>
                  </div>
                )}
                {component.status.metrics.network !== undefined && (
                  <div className="bg-agency-50 dark:bg-agency-800 p-2 rounded-lg">
                    <div className="text-xs text-agency-600 dark:text-agency-400">Network</div>
                    <div className="text-sm font-medium">{component.status.metrics.network} MB/s</div>
                  </div>
                )}
              </div>
            </div>
          )}
          
          {/* Component Links */}
          {(component.serviceUrl || component.documentationUrl) && (
            <div className="mb-4">
              <h4 className="text-sm font-medium text-agency-800 dark:text-agency-100 mb-2">
                Links
              </h4>
              <div className="flex gap-2">
                {component.serviceUrl && (
                  <a 
                    href={formatUrl(component.serviceUrl)} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="btn btn-secondary text-xs py-1"
                  >
                    Open Service
                  </a>
                )}
                {component.documentationUrl && (
                  <a 
                    href={component.documentationUrl} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="btn btn-secondary text-xs py-1"
                  >
                    Documentation
                  </a>
                )}
              </div>
            </div>
          )}
          
          {/* Status Message */}
          {component.status.message && (
            <div className="mb-4">
              <h4 className="text-sm font-medium text-agency-800 dark:text-agency-100 mb-2">
                Status Message
              </h4>
              <div className="bg-agency-50 dark:bg-agency-800 p-2 rounded-lg text-sm">
                {component.status.message}
              </div>
            </div>
          )}
          
          {/* Action Feedback */}
          {actionMessage && (
            <div className="mb-4">
              <div className="bg-blue-50 dark:bg-blue-900 p-2 rounded-lg text-sm text-blue-800 dark:text-blue-200">
                {actionMessage}
              </div>
            </div>
          )}
        </div>
      )}
      
      <div className="mt-4 pt-4 border-t border-gray-200 dark:border-agency-700 flex justify-between items-center">
        <div>
          <span className="text-xs text-agency-500 dark:text-agency-400">
            Last updated: {new Date(component.status.lastUpdated).toLocaleString()}
          </span>
        </div>
        
        <div className="flex gap-2">
          <button
            className="btn btn-secondary text-xs py-1"
            onClick={() => setIsExpanded(!isExpanded)}
          >
            {isExpanded ? 'Hide' : 'Details'}
          </button>
          
          {/* Actions dropdown */}
          {canAccess && !readOnlyMode && (
            <div className="relative inline-block text-left">
              <button
                className="btn btn-primary text-xs py-1"
                onClick={() => {
                  // Toggle dropdown
                }}
              >
                Actions
              </button>
              {/* Dropdown menu - would be implemented with state */}
              <div className="absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white dark:bg-agency-800 ring-1 ring-black ring-opacity-5 hidden">
                <div className="py-1" role="menu" aria-orientation="vertical">
                  {Object.keys(component.actions).map(action => (
                    <button
                      key={action}
                      className={`block px-4 py-2 text-sm text-agency-700 dark:text-agency-300 hover:bg-agency-100 dark:hover:bg-agency-700 w-full text-left`}
                      role="menuitem"
                      disabled={actionLoading === action}
                      onClick={() => handleAction(action)}
                    >
                      {actionLoading === action ? 'Loading...' : formatActionName(action)}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}
          
          {/* Read-only indicator for actions dropdown */}
          {canAccess && readOnlyMode && (
            <div className="relative inline-block text-left">
              <button
                className="btn btn-primary text-xs py-1 opacity-70 cursor-not-allowed"
                disabled={true}
                title="Actions disabled in read-only mode"
              >
                Actions
              </button>
            </div>
          )}
          
          {/* Individual action buttons as an alternative to dropdown */}
          {canAccess && !isExpanded && !readOnlyMode && (
            <div className="flex gap-1">
              {component.actions.start && component.status.status !== 'running' && (
                <button
                  className="btn btn-success text-xs py-1 px-2"
                  disabled={!!actionLoading}
                  onClick={() => handleAction('start')}
                >
                  {actionLoading === 'start' ? '...' : 'Start'}
                </button>
              )}
              
              {component.actions.stop && component.status.status === 'running' && (
                <button
                  className="btn btn-danger text-xs py-1 px-2"
                  disabled={!!actionLoading}
                  onClick={() => handleAction('stop')}
                >
                  {actionLoading === 'stop' ? '...' : 'Stop'}
                </button>
              )}
              
              {component.actions.restart && component.status.status === 'running' && (
                <button
                  className="btn btn-warning text-xs py-1 px-2"
                  disabled={!!actionLoading}
                  onClick={() => handleAction('restart')}
                >
                  {actionLoading === 'restart' ? '...' : 'Restart'}
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
