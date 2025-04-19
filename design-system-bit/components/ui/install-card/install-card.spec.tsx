import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { InstallCard } from './index';

describe('InstallCard Component', () => {
  // Test basic rendering
  test('renders component name and status correctly', () => {
    render(
      <InstallCard 
        name="Kill Bill" 
        status="running" 
      />
    );
    
    expect(screen.getByText('Kill Bill')).toBeInTheDocument();
    expect(screen.getByText('Running')).toBeInTheDocument();
  });
  
  // Test description rendering
  test('renders description when provided', () => {
    render(
      <InstallCard 
        name="Kill Bill" 
        status="running"
        description="Subscription billing and invoicing"
      />
    );
    
    expect(screen.getByText('Subscription billing and invoicing')).toBeInTheDocument();
  });
  
  // Test version rendering
  test('renders version when provided', () => {
    render(
      <InstallCard 
        name="Kill Bill" 
        status="running"
        version="0.24.0"
      />
    );
    
    expect(screen.getByText('Version: 0.24.0')).toBeInTheDocument();
  });
  
  // Test different statuses
  test.each([
    ['running', 'Running'],
    ['failed', 'Failed'],
    ['installing', 'Installing'],
    ['restarting', 'Restarting'],
    ['unknown', 'Unknown']
  ])('renders correct label for %s status', (status, expectedLabel) => {
    render(
      <InstallCard 
        name="Test Component" 
        status={status as any}
      />
    );
    
    expect(screen.getByText(expectedLabel)).toBeInTheDocument();
  });
  
  // Test button clicks
  test('calls onViewLogs when logs button is clicked', () => {
    const handleViewLogs = jest.fn();
    
    render(
      <InstallCard 
        name="Test Component" 
        status="running"
        onViewLogs={handleViewLogs}
      />
    );
    
    fireEvent.click(screen.getByText('Logs'));
    expect(handleViewLogs).toHaveBeenCalledTimes(1);
  });
  
  test('calls onViewMetrics when metrics button is clicked', () => {
    const handleViewMetrics = jest.fn();
    
    render(
      <InstallCard 
        name="Test Component" 
        status="running"
        onViewMetrics={handleViewMetrics}
      />
    );
    
    fireEvent.click(screen.getByText('Metrics'));
    expect(handleViewMetrics).toHaveBeenCalledTimes(1);
  });
  
  test('calls onRestart when restart button is clicked', () => {
    const handleRestart = jest.fn();
    
    render(
      <InstallCard 
        name="Test Component" 
        status="running"
        onRestart={handleRestart}
      />
    );
    
    fireEvent.click(screen.getByText('Restart'));
    expect(handleRestart).toHaveBeenCalledTimes(1);
  });
  
  // Test that restart button is not shown during installation or restart
  test('does not show restart button when status is installing', () => {
    const handleRestart = jest.fn();
    
    render(
      <InstallCard 
        name="Test Component" 
        status="installing"
        onRestart={handleRestart}
      />
    );
    
    expect(screen.queryByText('Restart')).not.toBeInTheDocument();
  });
  
  test('does not show restart button when status is restarting', () => {
    const handleRestart = jest.fn();
    
    render(
      <InstallCard 
        name="Test Component" 
        status="restarting"
        onRestart={handleRestart}
      />
    );
    
    expect(screen.queryByText('Restart')).not.toBeInTheDocument();
  });
  
  // Test compact mode
  test('renders in compact mode when compact prop is true', () => {
    render(
      <InstallCard 
        name="Test Component" 
        status="running"
        version="1.0.0"
        compact={true}
      />
    );
    
    // In compact mode, the label is not shown, just the icon
    expect(screen.queryByText('Running')).not.toBeInTheDocument();
    expect(screen.getByText('Test Component')).toBeInTheDocument();
    expect(screen.getByText('v1.0.0')).toBeInTheDocument();
  });
});
