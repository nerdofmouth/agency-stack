import { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import Head from 'next/head';
import styles from '../../styles/Component.module.css';

export default function ComponentDetail({ auth }) {
  const router = useRouter();
  const { component } = router.query;
  
  const [componentData, setComponentData] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [actionInProgress, setActionInProgress] = useState(false);
  const [actionResult, setActionResult] = useState(null);

  // Fetch component details
  const fetchComponentDetails = async () => {
    if (!component) return;
    
    try {
      setLoading(true);
      const response = await fetch(`/api/status?component=${component}`);
      
      if (!response.ok) {
        throw new Error(`API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      if (!data.success) {
        throw new Error(data.error || 'Unknown API error');
      }
      
      // Find the component in the list
      const componentInfo = data.components.find(c => c.component === component);
      
      if (!componentInfo) {
        throw new Error(`Component '${component}' not found`);
      }
      
      setComponentData(componentInfo);
      
      // Also fetch logs
      await fetchComponentLogs();
      
      setError(null);
    } catch (err) {
      console.error('Failed to fetch component details:', err);
      setError(err.message || 'Failed to load component details');
    } finally {
      setLoading(false);
    }
  };

  // Fetch component logs
  const fetchComponentLogs = async () => {
    if (!component) return;
    
    try {
      const response = await fetch(`/api/action?component=${component}&action=logs`);
      
      if (!response.ok) {
        throw new Error(`API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      if (!data.success) {
        // Just set empty logs, don't throw error as logs might not exist
        setLogs([]);
        return;
      }
      
      // Split logs into lines
      const logLines = data.logs.split('\n');
      setLogs(logLines);
    } catch (err) {
      console.error('Failed to fetch component logs:', err);
      setLogs([]);
    }
  };

  // Perform component action (restart, etc.)
  const performAction = async (action) => {
    if (!component) return;
    
    try {
      setActionInProgress(true);
      const response = await fetch(`/api/action?component=${component}&action=${action}`);
      
      if (!response.ok) {
        throw new Error(`API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      setActionResult({
        success: data.success,
        message: data.output || `${action} action completed`,
        action
      });
      
      // Refresh component data after action
      setTimeout(() => {
        fetchComponentDetails();
      }, 2000); // Give time for action to take effect
      
    } catch (err) {
      console.error(`Failed to ${action} component:`, err);
      setActionResult({
        success: false,
        message: err.message || `Failed to ${action} component`,
        action
      });
    } finally {
      setActionInProgress(false);
    }
  };

  // Fetch data on component change
  useEffect(() => {
    if (component) {
      fetchComponentDetails();
    }
  }, [component]);

  // Format timestamp
  const formatTimestamp = (timestamp) => {
    if (!timestamp) return 'Unknown';
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  if (!component) {
    return <div>Loading...</div>;
  }

  return (
    <div className={styles.container}>
      <Head>
        <title>{component} - Component Details</title>
        <meta name="description" content={`Status details for ${component}`} />
      </Head>

      <main className={styles.main}>
        <div className={styles.header}>
          <Link href="/">
            <a className={styles.backLink}>← Back to Dashboard</a>
          </Link>
          <h1 className={styles.title}>{component}</h1>
          <div className={styles.status}>
            {componentData && (
              <span className={componentData.running ? styles.running : styles.stopped}>
                {componentData.statusIcon} {componentData.running ? 'Running' : 'Not Running'}
              </span>
            )}
          </div>
        </div>

        {loading ? (
          <div className={styles.loading}>Loading component details...</div>
        ) : error ? (
          <div className={styles.error}>{error}</div>
        ) : (
          <>
            <div className={styles.detailsCard}>
              <h2>Component Details</h2>
              <div className={styles.detailsGrid}>
                <div className={styles.detailItem}>
                  <span className={styles.label}>Status:</span>
                  <span className={styles.value}>{componentData.statusIcon} {componentData.running ? 'Running' : 'Not Running'}</span>
                </div>
                <div className={styles.detailItem}>
                  <span className={styles.label}>Installed:</span>
                  <span className={styles.value}>{componentData.installed ? 'Yes' : 'No'}</span>
                </div>
                <div className={styles.detailItem}>
                  <span className={styles.label}>Last Updated:</span>
                  <span className={styles.value}>{formatTimestamp(componentData.timestamp)}</span>
                </div>
              </div>

              <div className={styles.actions}>
                <button 
                  className={styles.actionButton}
                  onClick={() => performAction('restart')}
                  disabled={actionInProgress}
                >
                  {actionInProgress && actionResult?.action === 'restart' ? 'Restarting...' : 'Restart'}
                </button>
                <button 
                  className={styles.actionButton}
                  onClick={() => performAction('status')}
                  disabled={actionInProgress}
                >
                  {actionInProgress && actionResult?.action === 'status' ? 'Checking...' : 'Check Status'}
                </button>
                <button 
                  className={styles.actionButton}
                  onClick={() => fetchComponentLogs()}
                  disabled={actionInProgress}
                >
                  Refresh Logs
                </button>
              </div>

              {actionResult && (
                <div className={actionResult.success ? styles.actionSuccess : styles.actionError}>
                  <h3>{actionResult.action.charAt(0).toUpperCase() + actionResult.action.slice(1)} Result:</h3>
                  <pre>{actionResult.message}</pre>
                </div>
              )}
            </div>

            <div className={styles.logsCard}>
              <h2>Component Logs</h2>
              {logs.length > 0 ? (
                <div className={styles.logs}>
                  {logs.map((line, index) => (
                    <div key={index} className={styles.logLine}>
                      {line}
                    </div>
                  ))}
                </div>
              ) : (
                <div className={styles.noLogs}>No logs available for this component.</div>
              )}
            </div>
          </>
        )}
      </main>

      <footer className={styles.footer}>
        <p>AgencyStack Admin Dashboard - {component} Component</p>
      </footer>
    </div>
  );
}
