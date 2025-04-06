import { ReactNode, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { FaRobot, FaTools, FaChartBar, FaTerminal, FaCodeBranch, FaFlask, FaBolt } from 'react-icons/fa';
import SimulationPanel from './SimulationPanel';

interface LayoutProps {
  children: ReactNode;
  clientId?: string | null;
}

export default function Layout({ children, clientId }: LayoutProps) {
  const router = useRouter();
  const [isMockMode, setIsMockMode] = useState(false);
  const [showSimulateMenu, setShowSimulateMenu] = useState(false);
  
  useEffect(() => {
    // Check if mock mode is enabled via env var or query param
    const mockFromEnv = process.env.NEXT_PUBLIC_MOCK_MODE === 'true';
    const mockFromQuery = router.query.mock === 'true';
    setIsMockMode(mockFromEnv || mockFromQuery);
  }, [router.query]);
  
  const navLinks = [
    { href: '/', icon: <FaRobot />, label: 'Dashboard' },
    { href: '/actions', icon: <FaTools />, label: 'Actions' },
    { href: '/metrics', icon: <FaChartBar />, label: 'Metrics' },
    { href: '/logs', icon: <FaTerminal />, label: 'Logs' },
    { href: '/sandbox', icon: <FaCodeBranch />, label: 'Prompt Sandbox' }
  ];
  
  const simulateEvent = async (type: string) => {
    try {
      await fetch('/api/agent/simulate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          event_type: type,
          client_id: clientId || 'test'
        })
      });
      alert(`Simulated ${type} event triggered successfully!`);
    } catch (error) {
      console.error('Error triggering simulation:', error);
      alert('Failed to trigger simulation. See console for details.');
    }
  };
  
  return (
    <div className="min-h-screen flex flex-col">
      {isMockMode && (
        <div className="bg-amber-500 text-white text-center py-2 px-4 flex justify-between items-center">
          <div>
            <FaFlask className="inline-block mr-2" />
            <span className="font-bold">MOCK MODE</span>: All operations are simulated and no real actions will be performed.
          </div>
          <div>
            <button 
              onClick={() => setShowSimulateMenu(!showSimulateMenu)}
              className="bg-amber-600 hover:bg-amber-700 text-white font-bold py-1 px-3 rounded flex items-center text-sm"
            >
              <FaBolt className="mr-1" /> Simulate
            </button>
            
            {showSimulateMenu && (
              <div className="absolute right-4 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-10">
                <div className="py-1">
                  <button
                    className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    onClick={() => simulateEvent('high_memory')}
                  >
                    Simulate High Memory Usage
                  </button>
                  <button
                    className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    onClick={() => simulateEvent('slow_response')}
                  >
                    Simulate Slow API Response
                  </button>
                  <button
                    className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    onClick={() => simulateEvent('new_model')}
                  >
                    Simulate New Model Available
                  </button>
                  <button
                    className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    onClick={() => simulateEvent('error')}
                  >
                    Simulate Error Condition
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
      
      <header className="bg-primary text-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-3">
            <FaRobot className="h-8 w-8" />
            <h1 className="text-2xl font-bold m-0">AgencyStack AI Tools</h1>
          </div>
          {clientId && (
            <div className="bg-primary-dark px-3 py-1 rounded-full text-sm">
              Client ID: {clientId}
            </div>
          )}
        </div>
      </header>
      
      <div className="flex flex-1">
        <nav className="w-64 bg-gray-800 text-white p-6">
          <ul className="space-y-4">
            {navLinks.map((link) => {
              const isActive = router.pathname === link.href;
              return (
                <li key={link.href}>
                  <Link 
                    href={link.href}
                    className={`flex items-center space-x-3 px-4 py-2 rounded-md hover:bg-gray-700 transition-colors ${
                      isActive ? 'bg-primary text-white' : 'text-gray-300'
                    }`}
                  >
                    <span className="text-lg">{link.icon}</span>
                    <span>{link.label}</span>
                  </Link>
                </li>
              );
            })}
          </ul>
          
          <div className="mt-8 pt-4 border-t border-gray-700">
            <div className="text-sm text-gray-400 mb-2">Agent Orchestrator</div>
            <div className="flex items-center text-green-400 text-sm">
              <span className="h-2 w-2 rounded-full bg-green-400 mr-2"></span>
              {isMockMode ? 'Mock Connected' : 'Connected'}
            </div>
          </div>
        </nav>
        
        <main className="flex-1 p-6 bg-background">
          {isMockMode && (
            <div className="mb-4">
              <div className="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 rounded shadow-sm mb-4">
                <div className="flex items-center">
                  <FaFlask className="mr-2" />
                  <p className="font-bold">Mock Mode Active</p>
                </div>
                <p className="text-sm mt-1">
                  You are viewing simulated data. No real services are being affected.
                </p>
              </div>
              <SimulationPanel clientId={clientId} />
            </div>
          )}
          {children}
        </main>
      </div>
      
      <footer className="bg-gray-800 text-white py-4 text-center text-sm">
        <div className="max-w-7xl mx-auto px-4">
          AgencyStack AI Tools &copy; {new Date().getFullYear()} | Agent Tools Bridge {isMockMode ? '(Mock Mode)' : '(Alpha)'}
        </div>
      </footer>
    </div>
  );
}
