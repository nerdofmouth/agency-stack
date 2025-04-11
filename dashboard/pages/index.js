import { useState, useEffect } from 'react';
import Head from 'next/head';
import styles from '../styles/Home.module.css';

export default function Home() {
  const [components, setComponents] = useState([]);
  const [systemStatus, setSystemStatus] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refreshInterval, setRefreshInterval] = useState(30); // seconds

  // Function to fetch component status
  const fetchComponentStatus = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/status');
      
      if (!response.ok) {
        throw new Error(`API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      if (!data.success) {
        throw new Error(data.error || 'Unknown API error');
      }
      
      setComponents(data.components);
      setSystemStatus(data.systemStatus);
      setError(null);
    } catch (err) {
      console.error('Failed to fetch component status:', err);
      setError(err.message || 'Failed to load component status');
    } finally {
      setLoading(false);
    }
  };

  // Initial fetch and setup refresh interval
  useEffect(() => {
    fetchComponentStatus();
    
    // Set up interval for refreshing data
    const intervalId = setInterval(fetchComponentStatus, refreshInterval * 1000);
    
    // Clean up on unmount
    return () => clearInterval(intervalId);
  }, [refreshInterval]);

  // Format timestamp for display
  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  // Get appropriate class based on component status
  const getStatusClass = (component) => {
    if (component.statusIcon === '✅') return styles.statusSuccess;
    if (component.statusIcon === '❌') return styles.statusError;
    if (component.statusIcon === '⚠️') return styles.statusWarning;
    return styles.statusUnknown;
  };

  return (
    <div className={styles.container}>
      <Head>
        <title>AgencyStack Dashboard</title>
        <meta name="description" content="Real-time status dashboard for AgencyStack components" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main className={styles.main}>
        <h1 className={styles.title}>
          AgencyStack Dashboard
        </h1>
        
        {/* System Status Summary */}
        <div className={styles.systemStatus}>
          <h2>System Status</h2>
          {loading ? (
            <p>Loading system status...</p>
          ) : error ? (
            <p className={styles.error}>{error}</p>
          ) : (
            <div>
              <p>
                <strong>Components Running:</strong> {systemStatus.running}/{systemStatus.total}
              </p>
              <p>
                <strong>Components Installed:</strong> {systemStatus.installed}/{systemStatus.total}
              </p>
              <p>
                <strong>Last Updated:</strong> {formatTimestamp(systemStatus.timestamp)}
              </p>
              <button onClick={fetchComponentStatus} className={styles.refreshButton}>
                Refresh Now
              </button>
              <div className={styles.refreshInterval}>
                <label htmlFor="refresh-interval">Auto-refresh every:</label>
                <select 
                  id="refresh-interval"
                  value={refreshInterval}
                  onChange={(e) => setRefreshInterval(Number(e.target.value))}
                >
                  <option value={10}>10 seconds</option>
                  <option value={30}>30 seconds</option>
                  <option value={60}>1 minute</option>
                  <option value={300}>5 minutes</option>
                </select>
              </div>
            </div>
          )}
        </div>
        
        {/* Component Status Table */}
        <div className={styles.componentGrid}>
          <h2>Component Status</h2>
          {loading && !components.length ? (
            <p>Loading components...</p>
          ) : error && !components.length ? (
            <p className={styles.error}>{error}</p>
          ) : (
            <table className={styles.statusTable}>
              <thead>
                <tr>
                  <th>Component</th>
                  <th>Status</th>
                  <th>Installed</th>
                  <th>Running</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {components.map((component) => (
                  <tr key={component.component}>
                    <td>{component.component}</td>
                    <td className={getStatusClass(component)}>
                      {component.statusIcon}
                    </td>
                    <td>{component.installed ? 'Yes' : 'No'}</td>
                    <td>{component.running ? 'Yes' : 'No'}</td>
                    <td className={styles.actions}>
                      <button onClick={() => window.location.href = `/component/${component.component}`}>
                        Details
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        
        {/* Version Warnings Section */}
        <div className={styles.versionWarnings}>
          <h2>Version Notifications</h2>
          <p>Components with outdated or unsupported versions will be highlighted here.</p>
          {/* This will be populated from component registry version information */}
        </div>
      </main>

      <footer className={styles.footer}>
        <p>AgencyStack Admin Dashboard - &copy; {new Date().getFullYear()}</p>
      </footer>
    </div>
  );
}
