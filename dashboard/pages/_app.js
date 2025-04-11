import '../styles/globals.css';
import withAuth from '../components/withAuth';

function MyApp({ Component, pageProps, auth }) {
  // Pass auth props to all pages
  return <Component {...pageProps} auth={auth} />;
}

// Wrap the app with authentication
export default withAuth(MyApp);
