import { useState, useEffect, createContext, useContext } from 'react';

export interface ThemeColors {
  primary: string;
  secondary: string;
  accent: string;
  background: string;
  foreground: string;
  border: string;
  muted: string;
  success: string;
  warning: string;
  error: string;
  info: string;
}

export interface ThemeConfig {
  clientId: string;
  name: string;
  colors: ThemeColors;
  fonts: {
    sans: string;
    mono: string;
  };
  borderRadius: string;
  darkMode: boolean;
  logo?: {
    light: string;
    dark: string;
  };
}

interface ThemeContextType {
  theme: ThemeConfig;
  colors: ThemeColors;
  isDarkMode: boolean;
  setDarkMode: (isDark: boolean) => void;
  setClientTheme: (clientId: string) => Promise<void>;
}

// Default theme values
const defaultTheme: ThemeConfig = {
  clientId: 'default',
  name: 'AgencyStack Default',
  colors: {
    primary: '#0070f3',
    secondary: '#7928ca',
    accent: '#f97316',
    background: '#ffffff',
    foreground: '#1a1a1a',
    border: '#e2e8f0',
    muted: '#f1f5f9',
    success: '#10b981',
    warning: '#f59e0b',
    error: '#ef4444',
    info: '#3b82f6',
  },
  fonts: {
    sans: 'Inter, system-ui, sans-serif',
    mono: 'Menlo, Monaco, "Courier New", monospace',
  },
  borderRadius: '0.5rem',
  darkMode: false,
  logo: {
    light: '/images/logo-light.svg',
    dark: '/images/logo-dark.svg',
  },
};

// Create context
const ThemeContext = createContext<ThemeContextType>({
  theme: defaultTheme,
  colors: defaultTheme.colors,
  isDarkMode: false,
  setDarkMode: () => {},
  setClientTheme: async () => {},
});

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<ThemeConfig>(defaultTheme);
  const [isDarkMode, setIsDarkMode] = useState(false);
  
  // Apply dark mode CSS class to document
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
      document.documentElement.setAttribute('data-theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      document.documentElement.setAttribute('data-theme', 'light');
    }
  }, [isDarkMode]);
  
  // Calculate colors based on current theme and dark mode
  const colors = isDarkMode 
    ? {
        // Dark mode color overrides
        background: '#121212',
        foreground: '#e2e2e2',
        border: '#2a2a2a',
        muted: '#1e1e1e',
        // Preserve other colors from theme
        ...theme.colors,
      }
    : theme.colors;
  
  // Apply CSS variables based on theme colors
  useEffect(() => {
    const root = document.documentElement;
    
    // Set color variables
    Object.entries(colors).forEach(([key, value]) => {
      root.style.setProperty(`--${key}`, value);
      
      // For color objects like primary, secondary, etc.
      if (key === 'primary') {
        root.style.setProperty('--primary-foreground', '#ffffff');
      }
      if (key === 'secondary') {
        root.style.setProperty('--secondary-foreground', '#ffffff');
      }
      if (key === 'accent') {
        root.style.setProperty('--accent-foreground', '#ffffff');
      }
      if (key === 'destructive') {
        root.style.setProperty('--destructive-foreground', '#ffffff');
      }
      if (key === 'muted') {
        root.style.setProperty('--muted-foreground', isDarkMode ? '#a1a1aa' : '#71717a');
      }
      if (key === 'card') {
        root.style.setProperty('--card-foreground', colors.foreground);
      }
      if (key === 'popover') {
        root.style.setProperty('--popover-foreground', colors.foreground);
      }
    });
    
    // Set other theme variables
    root.style.setProperty('--font-sans', theme.fonts.sans);
    root.style.setProperty('--font-mono', theme.fonts.mono);
    root.style.setProperty('--radius', theme.borderRadius);
    
  }, [colors, theme, isDarkMode]);
  
  // Fetch client theme configuration
  const setClientTheme = async (clientId: string) => {
    try {
      // In a real implementation, this would fetch from the server API
      // For now, we'll use a hardcoded path that would be used in production
      const configPath = `/opt/agency_stack/clients/${clientId}/config/theme.json`;
      
      // For development, we'll use mock data
      // This would be replaced with a real fetch in production:
      // const response = await fetch(`/api/themes/${clientId}`);
      // const themeData = await response.json();
      
      console.log(`Loading theme for client: ${clientId} (would fetch from ${configPath})`);
      
      // Mock response for development
      const mockThemeData = {
        clientId,
        name: `${clientId.charAt(0).toUpperCase() + clientId.slice(1)} Theme`,
        colors: {
          ...defaultTheme.colors,
          // Randomize the primary color a bit for demo purposes
          primary: clientId === 'default' 
            ? defaultTheme.colors.primary 
            : `#${Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0')}`,
        },
        fonts: defaultTheme.fonts,
        borderRadius: defaultTheme.borderRadius,
        darkMode: isDarkMode,
      };
      
      setTheme(mockThemeData);
    } catch (error) {
      console.error('Failed to load client theme:', error);
      // Fall back to default theme
      setTheme(defaultTheme);
    }
  };
  
  return (
    <ThemeContext.Provider
      value={{
        theme,
        colors,
        isDarkMode,
        setDarkMode: setIsDarkMode,
        setClientTheme,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => useContext(ThemeContext);

export default useTheme;
