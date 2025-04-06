import { redirect } from 'next/navigation';

// Redirect from root to dashboard
export default function Home() {
  redirect('/dashboard');
}
