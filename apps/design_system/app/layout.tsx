import React from 'react';
import { ThemeProvider } from '../hooks/useTheme';
import '../styles/globals.css';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <title>AgencyStack Design System</title>
        <meta name="description" content="AgencyStack Design System - Component library and UI framework" />
      </head>
      <body>
        <ThemeProvider>
          <div className="min-h-screen bg-background text-foreground">
            <header className="border-b border-border bg-card py-4">
              <div className="container mx-auto px-4">
                <h1 className="text-2xl font-bold">AgencyStack Design System</h1>
              </div>
            </header>
            <main className="container mx-auto px-4 py-6">
              {children}
            </main>
            <footer className="border-t border-border bg-card py-4 text-sm text-muted-foreground">
              <div className="container mx-auto px-4">
                <p>AgencyStack Design System © {new Date().getFullYear()}</p>
              </div>
            </footer>
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
