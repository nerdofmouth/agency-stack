import React, { useRef, useState, useEffect } from 'react';
import { useTheme } from '../../hooks/useTheme';

export interface EmbeddedAppFrameProps {
  /** URL to the embedded application */
  src: string;
  /** Title of the embedded application */
  title: string;
  /** Height of the iframe (can be a percentage or pixel value) */
  height?: string;
  /** Whether to show the frame header with title and controls */
  showHeader?: boolean;
  /** Whether to show a loading indicator while the iframe loads */
  showLoading?: boolean;
  /** Whether to allow the user to open the app in a new tab */
  allowNewTab?: boolean;
  /** Whether to allow the user to refresh the iframe */
  allowRefresh?: boolean;
  /** CSS class name for additional styling */
  className?: string;
  /** Optional callback when iframe has loaded */
  onLoad?: () => void;
  /** Optional callback when iframe fails to load */
  onError?: (error: Error) => void;
}

/**
 * EmbeddedAppFrame provides a secure way to embed third-party applications
 * within the AgencyStack UI while maintaining consistent styling and controls.
 */
export const EmbeddedAppFrame: React.FC<EmbeddedAppFrameProps> = ({
  src,
  title,
  height = '600px',
  showHeader = true,
  showLoading = true,
  allowNewTab = true,
  allowRefresh = true,
  className = '',
  onLoad,
  onError,
}) => {
  const { colors } = useTheme();
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  
  // Handle iframe load event
  const handleLoad = () => {
    setIsLoading(false);
    setHasError(false);
    if (onLoad) onLoad();
  };
  
  // Handle iframe error event
  const handleError = () => {
    setIsLoading(false);
    setHasError(true);
    setErrorMessage('Failed to load embedded application');
    if (onError) onError(new Error('Failed to load embedded application'));
  };
  
  // Refresh the iframe
  const refreshFrame = () => {
    setIsLoading(true);
    setHasError(false);
    
    // This reloads the iframe by changing the key
    if (iframeRef.current) {
      iframeRef.current.src = iframeRef.current.src;
    }
  };
  
  // Open in new tab
  const openInNewTab = () => {
    window.open(src, '_blank');
  };
  
  // Set loading state to false after a timeout (fallback)
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (isLoading) {
        setIsLoading(false);
      }
    }, 30000); // 30 seconds timeout
    
    return () => clearTimeout(timeoutId);
  }, [isLoading]);
  
  return (
    <div className={`flex flex-col rounded-lg border border-border bg-card shadow-sm ${className}`} style={{ height }}>
      {/* Header with title and controls */}
      {showHeader && (
        <div className="flex items-center justify-between border-b border-border bg-muted p-2">
          <h3 className="truncate text-sm font-medium text-foreground">{title}</h3>
          <div className="flex items-center gap-2">
            {allowRefresh && (
              <button
                onClick={refreshFrame}
                className="inline-flex h-8 w-8 items-center justify-center rounded-md bg-muted p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                aria-label="Refresh"
                title="Refresh"
              >
                ↻
              </button>
            )}
            {allowNewTab && (
              <button
                onClick={openInNewTab}
                className="inline-flex h-8 w-8 items-center justify-center rounded-md bg-muted p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                aria-label="Open in new tab"
                title="Open in new tab"
              >
                ↗
              </button>
            )}
          </div>
        </div>
      )}
      
      {/* Content area with iframe */}
      <div className="relative flex-1 overflow-hidden">
        {/* Loading indicator */}
        {isLoading && showLoading && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-card bg-opacity-75">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
            <p className="mt-2 text-sm text-muted-foreground">Loading {title}...</p>
          </div>
        )}
        
        {/* Error message */}
        {hasError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-card">
            <div className="rounded-full bg-destructive/10 p-3 text-2xl text-destructive">✗</div>
            <p className="mt-2 text-base font-medium text-foreground">{errorMessage}</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Unable to load {title}. Please check if the service is running.
            </p>
            <button
              onClick={refreshFrame}
              className="mt-4 rounded-md bg-primary px-4 py-2 text-sm text-primary-foreground"
            >
              Try Again
            </button>
          </div>
        )}
        
        {/* Iframe */}
        <iframe
          ref={iframeRef}
          src={src}
          title={title}
          className="h-full w-full border-0"
          sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox"
          onLoad={handleLoad}
          onError={handleError}
        ></iframe>
      </div>
    </div>
  );
};

export default EmbeddedAppFrame;
