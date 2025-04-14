import Layout from '@/components/Layout';
import AgentMetrics from '@/components/AgentMetrics';

interface MetricsPageProps {
  clientId?: string | null;
}

export default function MetricsPage({ clientId }: MetricsPageProps) {
  return (
    <Layout clientId={clientId}>
      <AgentMetrics clientId={clientId} />
    </Layout>
  );
}
