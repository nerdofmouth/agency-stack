/**
 * Dashboard Page
 * 
 * Shows component status grid and system overview for AgencyStack
 */

'use client';

import { useState, useEffect } from 'react';
import { useClientId } from '@/hooks/useClientId';
import { componentRegistry, getAllCategories } from '@/lib/component-registry';

export default function Dashboard() {
  const { clientId, isLoading: clientIdLoading } = useClientId();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  
  // Get all categories for filter
  const categories = getAllCategories();
  
  // Filter components based on search term and category
  const filteredComponents = componentRegistry.filter(component => {
    const matchesSearch = searchTerm === '' || 
      component.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      component.description.toLowerCase().includes(searchTerm.toLowerCase());
      
    const matchesCategory = selectedCategory === null || component.category === selectedCategory;
    
    return matchesSearch && matchesCategory;
  });
  
  // Status badge component
  const StatusBadge = ({ status }: { status: string }) => {
    const baseClasses = "text-xs font-medium px-2.5 py-0.5 rounded-full";
    
    const statusClasses = {
      healthy: `${baseClasses} bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200`,
      warning: `${baseClasses} bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200`,
      error: `${baseClasses} bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200`,
      inactive: `${baseClasses} bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200`
    };
    
    return (
      <span className={statusClasses[status as keyof typeof statusClasses] || statusClasses.inactive}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-agency-800 dark:text-agency-100">
          Dashboard
        </h1>
        <p className="mt-1 text-agency-600 dark:text-agency-300">
          Component Status and System Overview
        </p>
      </div>

      {/* Client ID indicator */}
      {clientId && !clientIdLoading && (
        <div className="inline-flex items-center px-3 py-1 bg-agency-100 dark:bg-agency-800 rounded-lg">
          <span className="text-sm font-medium text-agency-700 dark:text-agency-300">
            Client: {clientId}
          </span>
        </div>
      )}

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
              placeholder="Search components..."
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

      {/* Components Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredComponents.map((component) => (
          <div 
            key={component.id}
            className="card hover:shadow-lg transition-shadow cursor-pointer"
          >
            <div className="flex justify-between items-start">
              <div className="flex items-center">
                <div className="p-2 rounded-lg bg-agency-100 dark:bg-agency-800">
                  {/* This would use dynamic icon imports in a real implementation */}
                  <svg className="w-6 h-6 text-agency-600 dark:text-agency-300" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-4">
                  <h3 className="text-lg font-medium text-agency-800 dark:text-agency-100">
                    {component.name}
                  </h3>
                  <p className="text-sm text-agency-600 dark:text-agency-400">
                    {component.description}
                  </p>
                </div>
              </div>
              <StatusBadge status={component.status.status} />
            </div>
            
            <div className="mt-4 pt-4 border-t border-gray-200 dark:border-agency-700">
              <div className="flex justify-between items-center">
                <span className="text-xs text-agency-500 dark:text-agency-400">
                  Last updated: {new Date(component.status.lastUpdated).toLocaleString()}
                </span>
                
                <button className="btn btn-primary text-xs py-1">
                  Manage
                </button>
              </div>
              
              {component.status.message && (
                <p className="mt-2 text-sm text-agency-600 dark:text-agency-400">
                  {component.status.message}
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
      
      {filteredComponents.length === 0 && (
        <div className="text-center py-10">
          <p className="text-agency-600 dark:text-agency-400">
            No components match your filters.
          </p>
        </div>
      )}
    </div>
  );
}
