/**
 * useClientId Hook
 * 
 * Provides client ID awareness for multi-tenant architecture
 */

import { useState, useEffect, useCallback } from 'react';

// In a real implementation, this would come from an authenticated session
// or be fetched from an API based on the current user
export function useClientId() {
  const [clientId, setClientId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [role, setRole] = useState<'admin' | 'client'>('client');
  const [readOnlyMode, setReadOnlyMode] = useState(false);
  
  // Check if URL has a read-only flag for demo/testing
  useEffect(() => {
    // Check if ?readonly=true is in the URL
    const urlParams = new URLSearchParams(window.location.search);
    const readonly = urlParams.get('readonly');
    setReadOnlyMode(readonly === 'true');
    
    // Could also check for localStorage or environment variable
    const localReadOnly = localStorage.getItem('agency_readonly_mode');
    if (localReadOnly === 'true') {
      setReadOnlyMode(true);
    }
  }, []);
  
  // Simulate loading clientId from server/session
  useEffect(() => {
    const fetchClientId = async () => {
      setIsLoading(true);
      try {
        // In a real implementation, fetch from API or auth session
        // Simulate network delay for development
        await new Promise(resolve => setTimeout(resolve, 500));
        
        // Check URL for clientId parameter (for testing)
        const urlParams = new URLSearchParams(window.location.search);
        const urlClientId = urlParams.get('clientId');
        
        if (urlClientId) {
          setClientId(urlClientId);
        } else {
          // Default to 'client_alpha' for development
          setClientId('client_alpha');
        }
        
        // Check if admin role
        const urlRole = urlParams.get('role');
        if (urlRole === 'admin') {
          setRole('admin');
        } else {
          setRole('client');
        }
      } catch (error) {
        console.error('Failed to fetch client ID:', error);
        setClientId(null);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchClientId();
  }, []);
  
  // Helper function to check if current user is admin
  const isAdmin = useCallback(() => {
    return role === 'admin';
  }, [role]);
  
  // Function to switch client (only available to admins)
  const switchClient = useCallback((newClientId: string) => {
    if (role === 'admin' && !readOnlyMode) {
      setClientId(newClientId);
      return true;
    }
    return false;
  }, [role, readOnlyMode]);
  
  // Function to check if actions are allowed
  const canPerformActions = useCallback(() => {
    return !readOnlyMode;
  }, [readOnlyMode]);
  
  return { 
    clientId, 
    isLoading, 
    isAdmin, 
    switchClient,
    readOnlyMode,
    canPerformActions
  };
}

export default useClientId;
