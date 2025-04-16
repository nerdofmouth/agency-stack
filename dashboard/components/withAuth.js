// Keycloak authentication wrapper component
import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';

// Initialize Keycloak
let keycloak = null;

export default function withAuth(WrappedComponent) {
  return function WithAuth(props) {
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [isLoading, setIsLoading] = useState(true);
    const router = useRouter();

    useEffect(() => {
      const initKeycloak = async () => {
        try {
          // Dynamically import Keycloak only on the client side
          const Keycloak = (await import('keycloak-js')).default;
          
          const keycloakConfig = {
            url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'https://keycloak.localhost',
            realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'agency_stack',
            clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'dashboard',
          };
          
          keycloak = new Keycloak(keycloakConfig);
          
          // Initialize Keycloak
          const authenticated = await keycloak.init({
            onLoad: 'login-required',
            checkLoginIframe: false,
            pkceMethod: 'S256' // Use PKCE for enhanced security
          });
          
          setIsAuthenticated(authenticated);
          
          // Set up refresh token
          if (authenticated) {
            // Set token refresh
            setInterval(() => {
              keycloak.updateToken(70).catch(() => {
                console.error('Failed to refresh token, logging out...');
                keycloak.logout();
              });
            }, 60000); // Refresh token every minute
          }
        } catch (error) {
          console.error('Failed to initialize Keycloak:', error);
          // Fall back to non-authenticated mode for development
          if (process.env.NODE_ENV === 'development') {
            setIsAuthenticated(true);
          }
        } finally {
          setIsLoading(false);
        }
      };
      
      initKeycloak();
      
      // Cleanup function
      return () => {
        // Any cleanup needed
      };
    }, []);
    
    // Helper to expose Keycloak instance and auth state to components
    const authProps = {
      keycloak,
      isAuthenticated,
      logout: () => keycloak && keycloak.logout(),
      token: keycloak && keycloak.token,
      userInfo: keycloak && keycloak.userInfo,
    };
    
    if (isLoading) {
      return (
        <div style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center', 
          height: '100vh',
          flexDirection: 'column' 
        }}>
          <h2>Loading AgencyStack Dashboard...</h2>
          <p>Authenticating with Keycloak Identity Provider</p>
        </div>
      );
    }
    
    if (!isAuthenticated) {
      return (
        <div style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center', 
          height: '100vh',
          flexDirection: 'column',
          color: '#ff0000'
        }}>
          <h2>Authentication Required</h2>
          <p>You must be logged in to view the AgencyStack Dashboard</p>
          <button onClick={() => keycloak.login()}>
            Login with Keycloak
          </button>
        </div>
      );
    }
    
    // Pass all props and auth props to the wrapped component
    return <WrappedComponent {...props} auth={authProps} />;
  };
}
