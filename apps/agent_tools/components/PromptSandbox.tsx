import { useState } from 'react';
import axios from 'axios';
import { FaPaperPlane, FaCog, FaRocket, FaTrash } from 'react-icons/fa';

interface PromptSandboxProps {
  clientId?: string | null;
}

export default function PromptSandbox({ clientId }: PromptSandboxProps) {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [promptHistory, setPromptHistory] = useState<Array<{prompt: string, response: string}>>([]);
  const [settings, setSettings] = useState({
    model: 'default',
    temperature: 0.7,
    maxTokens: 500
  });
  const [showSettings, setShowSettings] = useState(false);
  
  const modelOptions = [
    { value: 'default', label: 'Default (LangChain)' },
    { value: 'llama2', label: 'Llama 2' },
    { value: 'mistral', label: 'Mistral' },
    { value: 'ollama', label: 'Ollama Default' }
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;
    if (!clientId) {
      setError('Client ID is required to test prompts');
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      const response = await axios.post('/api/agent/prompt', {
        client_id: clientId,
        prompt: prompt,
        model: settings.model,
        parameters: {
          temperature: settings.temperature,
          max_tokens: settings.maxTokens
        }
      });
      
      const responseText = response.data.response || '';
      setResponse(responseText);
      
      // Add to history
      setPromptHistory([
        { prompt, response: responseText },
        ...promptHistory
      ]);
      
      // Clear the prompt input
      setPrompt('');
    } catch (err: any) {
      console.error('Error sending prompt:', err);
      setError(err.response?.data?.message || 'Failed to process prompt');
      setResponse('');
    } finally {
      setLoading(false);
    }
  };

  const clearHistory = () => {
    setPromptHistory([]);
    setResponse('');
  };

  const usePromptFromHistory = (index: number) => {
    setPrompt(promptHistory[index].prompt);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1>Prompt Sandbox</h1>
        <div className="flex space-x-2">
          <button 
            className="btn-outline flex items-center"
            onClick={() => setShowSettings(!showSettings)}
          >
            <FaCog className="mr-2" /> Settings
          </button>
          {promptHistory.length > 0 && (
            <button 
              className="btn-outline flex items-center text-red-600 border-red-300 hover:bg-red-50"
              onClick={clearHistory}
            >
              <FaTrash className="mr-2" /> Clear History
            </button>
          )}
        </div>
      </div>
      
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}
      
      {showSettings && (
        <div className="card">
          <h3 className="text-lg font-semibold mb-4">Model Settings</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Model
              </label>
              <select
                value={settings.model}
                onChange={(e) => setSettings({...settings, model: e.target.value})}
                className="input"
              >
                {modelOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Temperature: {settings.temperature}
              </label>
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                value={settings.temperature}
                onChange={(e) => setSettings({...settings, temperature: parseFloat(e.target.value)})}
                className="w-full"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Max Tokens: {settings.maxTokens}
              </label>
              <input
                type="range"
                min="50"
                max="2000"
                step="50"
                value={settings.maxTokens}
                onChange={(e) => setSettings({...settings, maxTokens: parseInt(e.target.value)})}
                className="w-full"
              />
            </div>
          </div>
        </div>
      )}
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-4">
          <form onSubmit={handleSubmit}>
            <div className="card">
              <label htmlFor="prompt" className="block text-sm font-medium text-gray-700 mb-2">
                Enter your prompt:
              </label>
              <textarea
                id="prompt"
                rows={8}
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                className="input font-mono"
                placeholder="Write your prompt here..."
              />
              <div className="mt-4 flex justify-end">
                <button
                  type="submit"
                  className="btn-primary flex items-center"
                  disabled={loading || !prompt.trim()}
                >
                  {loading ? (
                    <>
                      <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Processing...
                    </>
                  ) : (
                    <>
                      <FaPaperPlane className="mr-2" /> Send
                    </>
                  )}
                </button>
              </div>
            </div>
          </form>
          
          {response && (
            <div className="card">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Response:
              </label>
              <div className="bg-gray-50 p-4 rounded-md border border-gray-200">
                <pre className="whitespace-pre-wrap font-mono text-sm text-gray-800">
                  {response}
                </pre>
              </div>
            </div>
          )}
        </div>
        
        <div>
          <div className="card">
            <h3 className="text-lg font-semibold mb-4">Prompt History</h3>
            
            {promptHistory.length === 0 ? (
              <div className="text-center py-10 text-gray-500">
                <FaRocket className="mx-auto text-3xl mb-2 opacity-20" />
                <p>Your prompt history will appear here</p>
              </div>
            ) : (
              <div className="space-y-4 max-h-[600px] overflow-y-auto pr-2">
                {promptHistory.map((item, index) => (
                  <div 
                    key={index} 
                    className="border border-gray-200 rounded-md p-3 hover:bg-gray-50 transition-colors"
                  >
                    <div className="font-medium mb-1 flex justify-between">
                      <div className="truncate flex-1">
                        Prompt #{promptHistory.length - index}
                      </div>
                      <button
                        onClick={() => usePromptFromHistory(index)}
                        className="text-primary hover:text-primary-dark text-sm"
                        title="Use this prompt"
                      >
                        Reuse
                      </button>
                    </div>
                    <div className="text-sm text-gray-600 truncate">
                      {item.prompt.length > 60 ? `${item.prompt.substring(0, 60)}...` : item.prompt}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
