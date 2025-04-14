import Layout from '@/components/Layout';
import PromptSandbox from '@/components/PromptSandbox';

interface SandboxPageProps {
  clientId?: string | null;
}

export default function SandboxPage({ clientId }: SandboxPageProps) {
  return (
    <Layout clientId={clientId}>
      <PromptSandbox clientId={clientId} />
    </Layout>
  );
}
