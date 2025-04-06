import Layout from '@/components/Layout';
import AgentLogs from '@/components/AgentLogs';

interface LogsPageProps {
  clientId?: string | null;
}

export default function LogsPage({ clientId }: LogsPageProps) {
  return (
    <Layout clientId={clientId}>
      <AgentLogs clientId={clientId} />
    </Layout>
  );
}
