import Layout from '@/components/Layout';
import AgentDashboard from '@/components/AgentDashboard';

interface HomeProps {
  clientId?: string | null;
}

export default function Home({ clientId }: HomeProps) {
  return (
    <Layout clientId={clientId}>
      <AgentDashboard clientId={clientId} />
    </Layout>
  );
}
