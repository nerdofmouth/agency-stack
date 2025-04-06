import Layout from '@/components/Layout';
import AgentActions from '@/components/AgentActions';

interface ActionsPageProps {
  clientId?: string | null;
}

export default function ActionsPage({ clientId }: ActionsPageProps) {
  return (
    <Layout clientId={clientId}>
      <AgentActions clientId={clientId} />
    </Layout>
  );
}
