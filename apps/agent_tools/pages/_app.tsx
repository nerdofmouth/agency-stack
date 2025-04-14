import '@/styles/globals.css';
import type { AppProps } from 'next/app';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { useState, useEffect } from 'react';

export default function App({ Component, pageProps }: AppProps) {
  const router = useRouter();
  const [clientId, setClientId] = useState<string | null>(null);
  
  useEffect(() => {
    // Get client ID from query param or localStorage
    const queryClientId = router.query.client_id as string;
    const storedClientId = localStorage.getItem('clientId');
    
    if (queryClientId) {
      localStorage.setItem('clientId', queryClientId);
      setClientId(queryClientId);
    } else if (storedClientId) {
      setClientId(storedClientId);
    }
  }, [router.query]);
  
  return (
    <>
      <Head>
        <title>AgencyStack AI Tools</title>
        <meta name="description" content="AI Agent Control Panel for AgencyStack" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      
      <Component {...pageProps} clientId={clientId} />
    </>
  );
}
