/**
 * Dashboard Page
 * 
 * Shows component status grid and system overview for AgencyStack
 */

'use client';

import { useState, useEffect } from 'react';
import { useClientId } from '@/hooks/useClientId';
import { loadComponentRegistry, getAllCategories, getAllTags, Component } from '@/components/registry';
import ComponentPanel from '@/components/ComponentPanel';

export default function Dashboard() {
  const { clientId, isLoading: clientIdLoading } = useClientId();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const [components, setComponents] = useState<Component[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [tags, setTags] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  // Load component registry on mount
  useEffect(() => {
    const fetchComponents = async () => {
      setIsLoading(true);
      try {
        const componentsData = await loadComponentRegistry();
        setComponents(componentsData);
        setCategories(getAllCategories(componentsData));
        setTags(getAllTags(componentsData));
      } catch (error) {
        console.error('Failed to load components:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchComponents();
  }, []);
  
  // Refresh components when an action is completed
  const handleActionComplete = async () => {
    try {
      const updatedComponents = await loadComponentRegistry();
      setComponents(updatedComponents);
    } catch (error) {
      console.error('Failed to refresh components:', error);
    }
  };
  
  // Filter components based on search term, category, and tag
  const filteredComponents = components.filter(component => {
    const matchesSearch = searchTerm === '' || 
      component.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      component.description.toLowerCase().includes(searchTerm.toLowerCase());
      
    const matchesCategory = selectedCategory === null || component.category === selectedCategory;
    const matchesTag = selectedTag === null || component.tags.includes(selectedTag);
    
    return matchesSearch && matchesCategory && matchesTag;
  });

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
        <div className="md:w-48">
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
        
        {/* Tag Filter */}
        <div className="md:w-48">
          <select
            className="bg-white dark:bg-agency-800 border border-gray-300 dark:border-agency-700 text-agency-800 dark:text-agency-200 text-sm rounded-lg block w-full p-2.5"
            value={selectedTag || ''}
            onChange={(e) => setSelectedTag(e.target.value === '' ? null : e.target.value)}
          >
            <option value="">All Tags</option>
            {tags.map((tag) => (
              <option key={tag} value={tag}>
                {tag.charAt(0).toUpperCase() + tag.slice(1)}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Loading state */}
      {isLoading && (
        <div className="flex justify-center items-center py-10">
          <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-agency-600"></div>
        </div>
      )}

      {/* Components Grid */}
      {!isLoading && (
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-5">
          {filteredComponents.map((component) => (
            <ComponentPanel 
              key={component.id} 
              component={component} 
              onActionComplete={handleActionComplete}
            />
          ))}
        </div>
      )}
      
      {!isLoading && filteredComponents.length === 0 && (
        <div className="text-center py-10">
          <p className="text-agency-600 dark:text-agency-400">
            No components match your filters.
          </p>
        </div>
      )}
    </div>
  );
}
