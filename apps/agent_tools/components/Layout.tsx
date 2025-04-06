import { ReactNode } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { FaRobot, FaTools, FaChartBar, FaTerminal, FaCodeBranch } from 'react-icons/fa';

interface LayoutProps {
  children: ReactNode;
  clientId?: string | null;
}

export default function Layout({ children, clientId }: LayoutProps) {
  const router = useRouter();
  
  const navLinks = [
    { href: '/', icon: <FaRobot />, label: 'Dashboard' },
    { href: '/actions', icon: <FaTools />, label: 'Actions' },
    { href: '/metrics', icon: <FaChartBar />, label: 'Metrics' },
    { href: '/logs', icon: <FaTerminal />, label: 'Logs' },
    { href: '/sandbox', icon: <FaCodeBranch />, label: 'Prompt Sandbox' }
  ];
  
  return (
    <div className="min-h-screen flex flex-col">
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
              Connected
            </div>
          </div>
        </nav>
        
        <main className="flex-1 p-6 bg-background">
          {children}
        </main>
      </div>
      
      <footer className="bg-gray-800 text-white py-4 text-center text-sm">
        <div className="max-w-7xl mx-auto px-4">
          AgencyStack AI Tools &copy; {new Date().getFullYear()} | Agent Tools Bridge (Alpha)
        </div>
      </footer>
    </div>
  );
}
