import React, { useState } from 'react';
import { InstallCard } from './index';

export const BasicInstallCard = () => {
  return (
    <InstallCard 
      name="Kill Bill"
      status="running"
      description="Subscription billing and invoicing"
      version="0.24.0"
      lastUpdated={new Date()}
      onViewLogs={() => console.log('View logs clicked')}
      onViewMetrics={() => console.log('View metrics clicked')}
      onRestart={() => console.log('Restart clicked')}
    />
  );
};

export const FailedInstallCard = () => {
  return (
    <InstallCard 
      name="Mailu"
      status="failed"
      description="Email server and webmail client"
      version="1.9.0"
      lastUpdated={new Date(Date.now() - 3600000)} // 1 hour ago
      onViewLogs={() => console.log('View logs clicked')}
      onRestart={() => console.log('Restart clicked')}
    />
  );
};

export const InstallingInstallCard = () => {
  return (
    <InstallCard 
      name="Keycloak"
      status="installing"
      description="Identity and access management"
      lastUpdated={new Date()}
      onViewLogs={() => console.log('View logs clicked')}
    />
  );
};

export const RestartingInstallCard = () => {
  return (
    <InstallCard 
      name="PeerTube"
      status="restarting"
      description="Video streaming platform"
      version="5.1.0"
      lastUpdated={new Date()}
      onViewLogs={() => console.log('View logs clicked')}
    />
  );
};

export const CompactInstallCard = () => {
  return (
    <div className="grid grid-cols-3 gap-4">
      <InstallCard 
        name="Kill Bill"
        status="running"
        version="0.24.0"
        compact={true}
      />
      <InstallCard 
        name="Mailu"
        status="failed"
        version="1.9.0"
        compact={true}
      />
      <InstallCard 
        name="Keycloak"
        status="installing"
        compact={true}
      />
    </div>
  );
};

export const InteractiveInstallCard = () => {
  const [status, setStatus] = useState<'running' | 'failed' | 'installing' | 'restarting' | 'unknown'>('running');
  
  const handleRestart = () => {
    setStatus('restarting');
    
    // Simulate restart completion after 3 seconds
    setTimeout(() => {
      setStatus('running');
    }, 3000);
  };
  
  return (
    <InstallCard 
      name="Interactive Demo"
      status={status}
      description="Component with interactive status changes"
      version="1.0.0"
      lastUpdated={new Date()}
      onViewLogs={() => console.log('View logs clicked')}
      onViewMetrics={() => console.log('View metrics clicked')}
      onRestart={handleRestart}
    />
  );
};
