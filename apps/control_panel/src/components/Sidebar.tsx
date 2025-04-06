/**
 * Sidebar Component
 * 
 * Main navigation sidebar for the AgencyStack Control Panel
 */

'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { useState } from 'react';
import { useClientId } from '@/hooks/useClientId';

// These would normally be imported from react-icons, but we're mocking them here
const IconComponents = {
  // Core navigation icons
  Dashboard: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zm0 6a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1v-2zm0 6a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1v-2z"></path></svg>,
  Commands: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M2 5a2 2 0 012-2h12a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm3 1h10v1H5V6zm10 3H5v1h10V9zm0 3H5v1h10v-1z" clipRule="evenodd"></path></svg>,
  Logs: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M2 4a1 1 0 011-1h14a1 1 0 011 1v1a1 1 0 01-1 1H3a1 1 0 01-1-1V4zm0 4a1 1 0 011-1h6a1 1 0 011 1v1a1 1 0 01-1 1H3a1 1 0 01-1-1V8zm0 4a1 1 0 011-1h9a1 1 0 011 1v1a1 1 0 01-1 1H3a1 1 0 01-1-1v-1zm0 4a1 1 0 011-1h5a1 1 0 011 1v1a1 1 0 01-1 1H3a1 1 0 01-1-1v-1z"></path></svg>,
  
  // Component icons (simplified, would use react-icons in practice)
  SiDocker: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M5 3a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2V5a2 2 0 00-2-2H5zm0 8a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2v-2a2 2 0 00-2-2H5zm6-6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V5zm0 8a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"></path></svg>,
  SiUsers: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zm8 0a3 3 0 11-6 0 3 3 0 016 0zm-4.07 11c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z"></path></svg>,
  SiSettings: () => <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clipRule="evenodd"></path></svg>,
};

// Navigation items
const mainNavItems = [
  { name: 'Dashboard', path: '/dashboard', icon: 'Dashboard' },
  { name: 'Commands', path: '/commands', icon: 'Commands' },
  { name: 'Logs', path: '/logs', icon: 'Logs' },
];

const Sidebar = () => {
  const pathname = usePathname();
  const { clientId, isAdmin, getAvailableClients, switchClient } = useClientId();
  const [dropdownOpen, setDropdownOpen] = useState(false);

  // Get available clients for the client selector
  const availableClients = getAvailableClients();

  return (
    <aside className="flex flex-col w-64 bg-white dark:bg-agency-900 border-r border-gray-200 dark:border-agency-800">
      {/* Logo */}
      <div className="flex items-center justify-center h-16 border-b border-gray-200 dark:border-agency-800">
        <div className="text-xl font-bold text-agency-800 dark:text-agency-100">
          AgencyStack
        </div>
      </div>

      {/* Client Selector (only for admins) */}
      {isAdmin() && (
        <div className="p-4 border-b border-gray-200 dark:border-agency-800">
          <div className="relative">
            <button
              onClick={() => setDropdownOpen(!dropdownOpen)}
              className="w-full flex items-center justify-between px-4 py-2 text-sm font-medium text-agency-700 bg-agency-100 rounded-lg dark:bg-agency-800 dark:text-agency-200"
            >
              <div className="flex items-center">
                <IconComponents.SiUsers />
                <span className="ml-2 truncate">
                  {clientId ? availableClients.find(c => c.id === clientId)?.name : 'Loading...'}
                </span>
              </div>
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fillRule="evenodd"
                  d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                  clipRule="evenodd"
                />
              </svg>
            </button>

            {/* Dropdown */}
            {dropdownOpen && (
              <div className="absolute z-10 w-full mt-1 bg-white rounded-md shadow-lg dark:bg-agency-800">
                <ul className="py-1">
                  {availableClients.map((client) => (
                    <li key={client.id}>
                      <button
                        onClick={() => {
                          switchClient(client.id);
                          setDropdownOpen(false);
                        }}
                        className="block w-full text-left px-4 py-2 text-sm text-agency-700 hover:bg-agency-100 dark:text-agency-200 dark:hover:bg-agency-700"
                      >
                        {client.name}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Main Navigation */}
      <nav className="flex-1 px-2 py-4 overflow-y-auto">
        <ul className="space-y-2">
          {mainNavItems.map((item) => {
            const isActive = pathname === item.path;
            const Icon = IconComponents[item.icon as keyof typeof IconComponents];
            
            return (
              <li key={item.path}>
                <Link 
                  href={item.path}
                  className={`sidebar-item ${isActive ? 'sidebar-item-active' : 'sidebar-item-inactive'}`}
                >
                  <Icon />
                  <span>{item.name}</span>
                </Link>
              </li>
            );
          })}
        </ul>

        <div className="pt-8">
          <div className="px-4 py-2 text-xs font-semibold text-agency-600 uppercase dark:text-agency-400">
            Settings
          </div>
          <Link 
            href="/settings"
            className="sidebar-item sidebar-item-inactive"
          >
            <IconComponents.SiSettings />
            <span>System Settings</span>
          </Link>
        </div>
      </nav>

      {/* Footer with version info */}
      <div className="flex flex-col items-center p-4 border-t border-gray-200 dark:border-agency-800">
        <div className="text-xs text-agency-500 dark:text-agency-400">
          AgencyStack v1.0.0
        </div>
        <div className="text-xs text-agency-400 dark:text-agency-500">
          Digital Sovereignty
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
