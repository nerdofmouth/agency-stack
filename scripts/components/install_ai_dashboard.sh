#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: ai_dashboard.sh
# Path: /scripts/components/install_ai_dashboard.sh
#
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Strict error handling
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
AI_DASHBOARD_LOG="${COMPONENT_LOG_DIR}/ai_dashboard.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
COMPONENT_REGISTRY="${CONFIG_DIR}/config/registry/component_registry.json"
DASHBOARD_DATA="${CONFIG_DIR}/config/dashboard_data.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${CONFIG_DIR}/docker/ai-dashboard"
APP_SRC_DIR="${ROOT_DIR}/apps/ai-dashboard"

# AI Dashboard Configuration
AI_DASHBOARD_VERSION="1.0.0"
CLIENT_ID=""
CLIENT_DIR=""
DOMAIN="localhost"
PORT="5130"
WITH_DEPS=false
FORCE=false
USE_OLLAMA=false
ENABLE_OPENAI=false
ENABLE_SSO=false
SSO_PROVIDER="none"
OLLAMA_PORT=11434
LANGCHAIN_PORT=5111
ENABLE_MONITORING=true
MEMORY_LIMIT="1g"
AI_DASHBOARD_CONTAINER_NAME="ai-dashboard"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${AI_DASHBOARD_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack AI Dashboard Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--domain${NC} <domain>          Domain name for service (default: localhost)"
  echo -e "  ${CYAN}--port${NC} <port>              Port for AI Dashboard UI (default: 5130)"
  echo -e "  ${CYAN}--enable-openai${NC}            Enable OpenAI API integration"
  echo -e "  ${CYAN}--use-ollama${NC}               Configure to use local Ollama LLM"
  echo -e "  ${CYAN}--ollama-port${NC} <port>       Port for Ollama API (default: 11434)"
  echo -e "  ${CYAN}--langchain-port${NC} <port>    Port for LangChain API (default: 5111)"
  echo -e "  ${CYAN}--enable-sso${NC}               Enable SSO integration"
  echo -e "  ${CYAN}--sso-provider${NC} <provider>  SSO provider (keycloak, clerk)"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (Docker, Node.js, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--disable-monitoring${NC}       Disable monitoring integration"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --client-id client1 --domain ai.example.com --use-ollama"
  echo -e "  $0 --client-id client1 --enable-openai --enable-sso --sso-provider keycloak"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}"
  
  # Create AI directories
  mkdir -p "${CLIENT_DIR}/ai/dashboard/config"
  mkdir -p "${CLIENT_DIR}/ai/dashboard/logs"
  mkdir -p "${CLIENT_DIR}/ai/dashboard/templates"
  mkdir -p "${CLIENT_DIR}/ai/dashboard/agents"
  mkdir -p "${CLIENT_DIR}/ai/dashboard/usage"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}"
  
  # Save client ID to file if it doesn't exist
  if [ ! -f "${CLIENT_ID_FILE}" ]; then
    echo "${CLIENT_ID}" > "${CLIENT_ID_FILE}"
    log "INFO" "Saved client ID to ${CLIENT_ID_FILE}"
  fi
}

# Check system requirements
check_requirements() {
  log "INFO" "Checking system requirements..."
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check if Docker Compose is installed
  if ! command -v docker-compose &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check if Node.js/npm is installed for local development
  if ! command -v node &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "WARN" "Node.js is not installed. Some development features may not be available."
  fi
  
  # Check if Ollama is installed and running when using --use-ollama
  if [ "$USE_OLLAMA" = true ]; then
    if ! curl -s "http://localhost:${OLLAMA_PORT}/api/tags" &>/dev/null; then
      log "WARN" "Ollama API not reachable at port ${OLLAMA_PORT}. AI Dashboard will be configured to use Ollama, but verify Ollama is running before using AI Dashboard."
    else
      log "INFO" "Ollama API detected at port ${OLLAMA_PORT}"
    fi
  fi
  
  # Check if LangChain is installed
  if ! curl -s "http://localhost:${LANGCHAIN_PORT}/health" &>/dev/null; then
    log "WARN" "LangChain API not reachable at port ${LANGCHAIN_PORT}. AI Dashboard requires LangChain for full functionality."
  else
    log "INFO" "LangChain API detected at port ${LANGCHAIN_PORT}"
  fi
  
  # Check for available disk space
  INSTALL_DIR="${CLIENT_DIR}/ai/dashboard"
  AVAILABLE_SPACE=$(df -BM "$INSTALL_DIR" | awk 'NR==2 {print $4}' | tr -d 'M')
  if [ -z "$AVAILABLE_SPACE" ] || [ "$AVAILABLE_SPACE" -lt 500 ]; then
    log "WARN" "Less than 500MB of free space available. AI Dashboard installation may require more space."
  fi
  
  # All checks passed
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Install Docker if not installed
  if ! command -v docker &> /dev/null; then
    log "INFO" "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $(whoami)
    systemctl enable docker
    systemctl start docker
    log "INFO" "Docker installed successfully"
  else
    log "INFO" "Docker is already installed"
  fi
  
  # Install Docker Compose if not installed
  if ! command -v docker-compose &> /dev/null; then
    log "INFO" "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "INFO" "Docker Compose installed successfully"
  else
    log "INFO" "Docker Compose is already installed"
  fi
  
  # Install Node.js/npm for local development (optional)
  if ! command -v node &> /dev/null; then
    log "INFO" "Installing Node.js..."
    # Install NVM (Node Version Manager)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install Node.js LTS
    nvm install --lts
    log "INFO" "Node.js installed successfully"
  else
    log "INFO" "Node.js is already installed"
  fi
  
  log "INFO" "Dependencies installed successfully"
}

# Create Next.js application scaffold
create_app_scaffold() {
  log "INFO" "Creating Next.js application scaffold..."
  
  # Check if app directory already exists
  if [ -d "${APP_SRC_DIR}" ] && [ "$FORCE" = false ]; then
    log "INFO" "Next.js application directory already exists. Using existing code."
    return
  fi
  
  # Create the app directory
  mkdir -p "${APP_SRC_DIR}"
  
  # Create package.json
  cat > "${APP_SRC_DIR}/package.json" << EOF
{
  "name": "ai-dashboard",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "react-query": "^3.39.3",
    "axios": "^1.6.0",
    "swr": "^2.2.4",
    "tailwindcss": "^3.3.5",
    "postcss": "^8.4.31",
    "autoprefixer": "^10.4.16",
    "@headlessui/react": "^1.7.17",
    "@heroicons/react": "^2.0.18",
    "recharts": "^2.9.0",
    "react-markdown": "^9.0.0"
  },
  "devDependencies": {
    "@types/node": "20.8.10",
    "@types/react": "18.2.34",
    "@types/react-dom": "18.2.14",
    "eslint": "8.52.0",
    "eslint-config-next": "14.0.0",
    "typescript": "5.2.2"
  }
}
EOF

  # Create Next.js config
  cat > "${APP_SRC_DIR}/next.config.js" << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'standalone',
  env: {
    OLLAMA_API_URL: process.env.OLLAMA_API_URL || 'http://localhost:11434',
    LANGCHAIN_API_URL: process.env.LANGCHAIN_API_URL || 'http://localhost:5111',
    OPENAI_ENABLED: process.env.OPENAI_ENABLED || 'false',
    SSO_ENABLED: process.env.SSO_ENABLED || 'false',
    SSO_PROVIDER: process.env.SSO_PROVIDER || 'none',
    CLIENT_ID: process.env.CLIENT_ID || 'default'
  },
}

module.exports = nextConfig
EOF

  # Create TypeScript config
  cat > "${APP_SRC_DIR}/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF

  # Create Tailwind config
  cat > "${APP_SRC_DIR}/tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
        },
      }
    },
  },
  plugins: [],
}
EOF

  # Create PostCSS config
  cat > "${APP_SRC_DIR}/postcss.config.js" << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

  # Create global CSS file
  mkdir -p "${APP_SRC_DIR}/styles"
  cat > "${APP_SRC_DIR}/styles/globals.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

html,
body {
  padding: 0;
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Oxygen,
    Ubuntu, Cantarell, Fira Sans, Droid Sans, Helvetica Neue, sans-serif;
}

a {
  color: inherit;
  text-decoration: none;
}

* {
  box-sizing: border-box;
}

@layer components {
  .btn-primary {
    @apply bg-primary-600 hover:bg-primary-700 text-white font-bold py-2 px-4 rounded;
  }
  
  .btn-secondary {
    @apply bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-2 px-4 rounded;
  }
  
  .card {
    @apply bg-white rounded-lg shadow-md p-6;
  }
  
  .input {
    @apply border border-gray-300 rounded-md px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent;
  }
}
EOF

  # Create lib directory for API clients
  mkdir -p "${APP_SRC_DIR}/lib"
  
  # Create API client for LangChain and Ollama
  cat > "${APP_SRC_DIR}/lib/api.ts" << 'EOF'
import axios from 'axios';

// Configure API base URLs
const langchainApi = axios.create({
  baseURL: process.env.LANGCHAIN_API_URL || 'http://localhost:5111'
});

const ollamaApi = axios.create({
  baseURL: process.env.OLLAMA_API_URL || 'http://localhost:11434'
});

// LangChain API client
export const langchain = {
  // Health check
  async getHealth() {
    return langchainApi.get('/health');
  },
  
  // Get available chains
  async getChains() {
    return langchainApi.get('/chains');
  },
  
  // Run a chain
  async runChain(chainId: string, inputs: any) {
    return langchainApi.post('/chain/run', {
      chain_id: chainId,
      inputs,
      streaming: false
    });
  },
  
  // Run a prompt
  async runPrompt(template: string, inputs: any, model: string = 'default', temperature: number = 0.7) {
    return langchainApi.post('/prompt', {
      template,
      inputs,
      model,
      temperature,
      streaming: false
    });
  },
  
  // Get available tools
  async getTools() {
    return langchainApi.get('/tools');
  }
};

// Ollama API client
export const ollama = {
  // Get available models
  async getModels() {
    try {
      const response = await ollamaApi.get('/api/tags');
      return response.data.models || [];
    } catch (error) {
      console.error('Error fetching Ollama models:', error);
      return [];
    }
  },
  
  // Generate text
  async generate(model: string, prompt: string) {
    return ollamaApi.post('/api/generate', {
      model,
      prompt
    });
  },
  
  // Chat
  async chat(model: string, messages: any[]) {
    return ollamaApi.post('/api/chat', {
      model,
      messages
    });
  }
};

// Dashboard data client
export const dashboard = {
  // Get system status
  async getStatus() {
    // In a real implementation, this would fetch from the backend
    // For now, we'll return mock data
    return {
      llms: {
        ollama: {
          status: 'healthy',
          models: ['llama2', 'mistral', 'codellama'],
          apiCalls24h: 152
        },
        openai: {
          status: process.env.OPENAI_ENABLED === 'true' ? 'connected' : 'disabled',
          tokens24h: 15420
        }
      },
      langchain: {
        status: 'healthy',
        chains: 5,
        tools: 3,
        apiCalls24h: 87
      }
    };
  },
  
  // Get token usage
  async getTokenUsage() {
    // Mock data
    return {
      daily: [
        { date: '2025-04-01', tokens: 12500 },
        { date: '2025-04-02', tokens: 18200 },
        { date: '2025-04-03', tokens: 9800 },
        { date: '2025-04-04', tokens: 15600 },
        { date: '2025-04-05', tokens: 7200 }
      ],
      byModel: {
        'llama2': 35000,
        'mistral': 22000,
        'gpt-3.5-turbo': 6300
      }
    };
  }
};
EOF

  # Create pages directory
  mkdir -p "${APP_SRC_DIR}/pages"
  
  log "INFO" "Next.js application scaffold created at ${APP_SRC_DIR}"
}

# Create React components
create_components() {
  log "INFO" "Creating React components..."
  
  # Create components directory
  mkdir -p "${APP_SRC_DIR}/components"
  
  # Create Layout component
  cat > "${APP_SRC_DIR}/components/Layout.tsx" << 'EOF'
import React, { ReactNode, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import {
  HomeIcon,
  ChatBubbleLeftRightIcon,
  CpuChipIcon,
  Cog6ToothIcon,
  ChartBarIcon,
  ShieldCheckIcon,
  BeakerIcon
} from '@heroicons/react/24/outline';

interface LayoutProps {
  children: ReactNode;
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
  const router = useRouter();
  const [clientId, setClientId] = useState(process.env.CLIENT_ID || 'default');

  const navigation = [
    { name: 'Dashboard', href: '/', icon: HomeIcon },
    { name: 'Prompt Testing', href: '/prompt-test', icon: ChatBubbleLeftRightIcon },
    { name: 'LangChain Playground', href: '/langchain-playground', icon: CpuChipIcon },
    { name: 'Agent Log', href: '/agent-log', icon: BeakerIcon },
    { name: 'LLM Settings', href: '/llm-settings', icon: Cog6ToothIcon },
    { name: 'Token Usage', href: '/tokens', icon: ChartBarIcon },
    { name: 'Security', href: '/security', icon: ShieldCheckIcon },
  ];

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="flex h-screen overflow-hidden">
        {/* Sidebar */}
        <div className="hidden md:flex md:flex-shrink-0">
          <div className="flex flex-col w-64">
            <div className="flex flex-col flex-grow pt-5 pb-4 overflow-y-auto bg-primary-700">
              <div className="flex items-center flex-shrink-0 px-4">
                <span className="text-xl font-bold text-white">AI Dashboard</span>
              </div>
              <div className="mt-5 flex-1 flex flex-col">
                <nav className="flex-1 px-2 space-y-1">
                  {navigation.map((item) => {
                    const current = router.pathname === item.href;
                    return (
                      <Link
                        key={item.name}
                        href={item.href}
                        className={`${
                          current
                            ? 'bg-primary-800 text-white'
                            : 'text-primary-100 hover:bg-primary-600'
                        } group flex items-center px-2 py-2 text-sm font-medium rounded-md`}
                      >
                        <item.icon
                          className="mr-3 flex-shrink-0 h-6 w-6 text-primary-300"
                          aria-hidden="true"
                        />
                        {item.name}
                      </Link>
                    );
                  })}
                </nav>
              </div>
              <div className="flex-shrink-0 flex border-t border-primary-800 p-4">
                <div className="flex-shrink-0 w-full group block">
                  <div className="flex items-center">
                    <div>
                      <p className="text-sm font-medium text-white">Client ID: {clientId}</p>
                      <p className="text-xs font-medium text-primary-200">
                        {process.env.OPENAI_ENABLED === 'true' ? 'OpenAI Enabled' : 'Local LLM Only'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        {/* Main content */}
        <div className="flex flex-col w-0 flex-1 overflow-hidden">
          <main className="flex-1 relative overflow-y-auto focus:outline-none">
            <div className="py-6">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
                {children}
              </div>
            </div>
          </main>
        </div>
      </div>
    </div>
  );
};

export default Layout;
EOF

  # Create LLMCard component
  cat > "${APP_SRC_DIR}/components/LLMCard.tsx" << 'EOF'
import React from 'react';
import { CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/solid';

interface LLMCardProps {
  title: string;
  status: 'healthy' | 'error' | 'disabled' | 'connected';
  models?: string[];
  apiCalls?: number;
  tokens?: number;
  lastUpdated?: string;
}

const LLMCard: React.FC<LLMCardProps> = ({
  title,
  status,
  models,
  apiCalls,
  tokens,
  lastUpdated
}) => {
  const isActive = status === 'healthy' || status === 'connected';
  
  return (
    <div className="bg-white overflow-hidden shadow rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            {isActive ? (
              <CheckCircleIcon className="h-8 w-8 text-green-500" />
            ) : (
              <XCircleIcon className="h-8 w-8 text-red-500" />
            )}
          </div>
          <div className="ml-5 w-0 flex-1">
            <dl>
              <dt className="text-sm font-medium text-gray-500 truncate">
                {title}
              </dt>
              <dd>
                <div className="text-lg font-medium text-gray-900">
                  {status.charAt(0).toUpperCase() + status.slice(1)}
                </div>
              </dd>
            </dl>
          </div>
        </div>
        
        {isActive && (
          <div className="mt-5 border-t border-gray-200 pt-4">
            {models && models.length > 0 && (
              <div className="mb-2">
                <span className="text-xs font-medium text-gray-500">Available Models:</span>
                <div className="flex flex-wrap gap-1 mt-1">
                  {models.map(model => (
                    <span key={model} className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                      {model}
                    </span>
                  ))}
                </div>
              </div>
            )}
            
            {apiCalls !== undefined && (
              <div className="mb-2">
                <span className="text-xs font-medium text-gray-500">API Calls (24h):</span>
                <span className="ml-2 text-sm text-gray-900">{apiCalls.toLocaleString()}</span>
              </div>
            )}
            
            {tokens !== undefined && (
              <div className="mb-2">
                <span className="text-xs font-medium text-gray-500">Tokens Used (24h):</span>
                <span className="ml-2 text-sm text-gray-900">{tokens.toLocaleString()}</span>
              </div>
            )}
            
            {lastUpdated && (
              <div className="text-xs text-gray-500 mt-2">
                Last updated: {lastUpdated}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default LLMCard;
EOF

  # Create UsageChart component
  cat > "${APP_SRC_DIR}/components/UsageChart.tsx" << 'EOF'
import React from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell
} from 'recharts';

interface UsageChartProps {
  data: any;
  type: 'bar' | 'pie';
  title: string;
}

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

const UsageChart: React.FC<UsageChartProps> = ({ data, type, title }) => {
  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`;
    } else if (num >= 1000) {
      return `${(num / 1000).toFixed(1)}K`;
    }
    return num;
  };

  return (
    <div className="bg-white p-4 rounded-lg shadow">
      <h3 className="text-lg font-medium text-gray-900 mb-4">{title}</h3>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          {type === 'bar' ? (
            <BarChart
              data={data}
              margin={{
                top: 5,
                right: 30,
                left: 20,
                bottom: 5,
              }}
            >
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis tickFormatter={formatNumber} />
              <Tooltip 
                formatter={(value: any) => [Number(value).toLocaleString(), 'Tokens']}
              />
              <Legend />
              <Bar dataKey="tokens" fill="#0284c7" name="Token Usage" />
            </BarChart>
          ) : (
            <PieChart>
              <Pie
                data={Object.entries(data).map(([name, value]) => ({ name, value }))}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name} (${(percent * 100).toFixed(0)}%)`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {Object.entries(data).map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(value: any) => [Number(value).toLocaleString(), 'Tokens']} />
              <Legend />
            </PieChart>
          )}
        </ResponsiveContainer>
      </div>
    </div>
  );
};

export default UsageChart;
EOF

  # Create PromptBox component
  cat > "${APP_SRC_DIR}/components/PromptBox.tsx" << 'EOF'
import React, { useState } from 'react';
import { ollama, langchain } from '../lib/api';

interface PromptBoxProps {
  useOllama?: boolean;
  useLangChain?: boolean;
  defaultModel?: string;
  availableModels?: string[];
}

const PromptBox: React.FC<PromptBoxProps> = ({
  useOllama = true,
  useLangChain = false,
  defaultModel = 'llama2',
  availableModels = ['llama2', 'mistral', 'codellama']
}) => {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [model, setModel] = useState(defaultModel);
  const [temperature, setTemperature] = useState(0.7);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;
    
    setLoading(true);
    setError('');
    setResponse('');
    
    try {
      if (useLangChain) {
        // Use LangChain API
        const result = await langchain.runPrompt(prompt, {}, model, temperature);
        setResponse(result.data.completion);
      } else if (useOllama) {
        // Use Ollama API directly
        const result = await ollama.generate(model, prompt);
        setResponse(result.data.response);
      } else {
        setError('No LLM provider configured');
      }
    } catch (err: any) {
      console.error('Error generating response:', err);
      setError(err.message || 'An error occurred while generating the response');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label htmlFor="prompt" className="block text-sm font-medium text-gray-700 mb-2">
            Enter your prompt
          </label>
          <textarea
            id="prompt"
            className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary-500 focus:border-primary-500"
            rows={4}
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder="Write a prompt for the AI model..."
          />
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label htmlFor="model" className="block text-sm font-medium text-gray-700 mb-2">
              Model
            </label>
            <select
              id="model"
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary-500 focus:border-primary-500"
              value={model}
              onChange={(e) => setModel(e.target.value)}
            >
              {availableModels.map((m) => (
                <option key={m} value={m}>
                  {m}
                </option>
              ))}
            </select>
          </div>
          
          <div>
            <label htmlFor="temperature" className="block text-sm font-medium text-gray-700 mb-2">
              Temperature: {temperature}
            </label>
            <input
              id="temperature"
              type="range"
              min="0"
              max="1"
              step="0.1"
              className="w-full"
              value={temperature}
              onChange={(e) => setTemperature(parseFloat(e.target.value))}
            />
          </div>
        </div>
        
        <div className="flex justify-end">
          <button
            type="submit"
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            disabled={loading || !prompt.trim()}
          >
            {loading ? 'Generating...' : 'Generate Response'}
          </button>
        </div>
      </form>
      
      {error && (
        <div className="mt-4 p-4 bg-red-50 rounded-md border border-red-200">
          <p className="text-red-700">{error}</p>
        </div>
      )}
      
      {response && (
        <div className="mt-6">
          <h3 className="text-lg font-medium text-gray-900 mb-2">Response</h3>
          <div className="p-4 bg-gray-50 rounded-md border border-gray-200 whitespace-pre-wrap">
            {response}
          </div>
        </div>
      )}
    </div>
  );
};

export default PromptBox;
EOF

  log "INFO" "Created React components at ${APP_SRC_DIR}/components"
}

# Create page templates
create_pages() {
  log "INFO" "Creating page templates..."
  
  # Create _app.tsx
  cat > "${APP_SRC_DIR}/pages/_app.tsx" << 'EOF'
import '../styles/globals.css';
import type { AppProps } from 'next/app';
import Layout from '../components/Layout';

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <Layout>
      <Component {...pageProps} />
    </Layout>
  );
}

export default MyApp;
EOF

  # Create index.tsx (Dashboard)
  cat > "${APP_SRC_DIR}/pages/index.tsx" << 'EOF'
import { useState, useEffect } from 'react';
import { NextPage } from 'next';
import Head from 'next/head';
import Link from 'next/link';
import LLMCard from '../components/LLMCard';
import { dashboard, ollama, langchain } from '../lib/api';

const Home: NextPage = () => {
  const [status, setStatus] = useState<any>(null);
  const [ollamaModels, setOllamaModels] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      try {
        // Fetch dashboard status
        const dashboardStatus = await dashboard.getStatus();
        setStatus(dashboardStatus);
        
        // Try to fetch Ollama models
        if (process.env.OLLAMA_API_URL) {
          try {
            const models = await ollama.getModels();
            if (models && models.length > 0) {
              setOllamaModels(models.map((model: any) => model.name));
            }
          } catch (error) {
            console.log('Could not fetch Ollama models');
          }
        }
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    
    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-lg text-gray-600">Loading dashboard data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border-l-4 border-red-400 p-4 mb-4">
        <div className="flex">
          <div className="ml-3">
            <p className="text-sm text-red-700">
              {error}
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div>
      <Head>
        <title>AI Dashboard - AgencyStack</title>
        <meta name="description" content="AI Dashboard for AgencyStack" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <div>
        <h1 className="text-2xl font-semibold text-gray-900 mb-8">AI Dashboard</h1>
        
        <div className="mb-8">
          <h2 className="text-lg font-medium text-gray-900 mb-4">LLM Services</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <LLMCard
              title="Ollama"
              status={status?.llms?.ollama?.status || 'disabled'}
              models={ollamaModels.length > 0 ? ollamaModels : status?.llms?.ollama?.models}
              apiCalls={status?.llms?.ollama?.apiCalls24h}
              lastUpdated="Just now"
            />
            
            <LLMCard
              title="OpenAI"
              status={status?.llms?.openai?.status || 'disabled'}
              tokens={status?.llms?.openai?.tokens24h}
              lastUpdated="Just now"
            />
            
            <LLMCard
              title="LangChain API"
              status={status?.langchain?.status || 'disabled'}
              apiCalls={status?.langchain?.apiCalls24h}
              lastUpdated="Just now"
            />
          </div>
        </div>
        
        <div className="mb-8 grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
            <div className="space-y-2">
              <Link href="/prompt-test" className="btn-primary block text-center">
                Test a Prompt
              </Link>
              <Link href="/langchain-playground" className="btn-secondary block text-center">
                LangChain Playground
              </Link>
              <Link href="/llm-settings" className="btn-secondary block text-center">
                Configure LLM Settings
              </Link>
            </div>
          </div>
          
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-medium text-gray-900 mb-4">System Status</h2>
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-500">Chains Available:</span>
                <span className="font-medium">{status?.langchain?.chains || 0}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-500">Tools Available:</span>
                <span className="font-medium">{status?.langchain?.tools || 0}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-500">Total API Calls (24h):</span>
                <span className="font-medium">
                  {((status?.llms?.ollama?.apiCalls24h || 0) + 
                   (status?.langchain?.apiCalls24h || 0)).toLocaleString()}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-500">Client ID:</span>
                <span className="font-medium">{process.env.CLIENT_ID || 'default'}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
EOF

  # Create prompt-test.tsx
  cat > "${APP_SRC_DIR}/pages/prompt-test.tsx" << 'EOF'
import { useState, useEffect } from 'react';
import { NextPage } from 'next';
import Head from 'next/head';
import PromptBox from '../components/PromptBox';
import { ollama } from '../lib/api';

const PromptTest: NextPage = () => {
  const [models, setModels] = useState<string[]>(['llama2', 'mistral', 'codellama']);
  const [useOllama, setUseOllama] = useState(process.env.OLLAMA_API_URL !== undefined);
  const [useLangChain, setUseLangChain] = useState(process.env.LANGCHAIN_API_URL !== undefined);
  
  useEffect(() => {
    const fetchModels = async () => {
      if (useOllama) {
        try {
          const modelList = await ollama.getModels();
          if (modelList && modelList.length > 0) {
            setModels(modelList.map((model: any) => model.name));
          }
        } catch (error) {
          console.error('Error fetching models:', error);
        }
      }
    };
    
    fetchModels();
  }, [useOllama]);

  return (
    <div>
      <Head>
        <title>Prompt Testing - AI Dashboard</title>
        <meta name="description" content="Test prompts with different LLM providers" />
      </Head>

      <div>
        <h1 className="text-2xl font-semibold text-gray-900 mb-4">Prompt Testing</h1>
        <p className="text-gray-600 mb-8">
          Test your prompts with different LLM providers and models. Results will be displayed below.
        </p>
        
        <div className="mb-6">
          <div className="flex space-x-4 mb-4">
            <label className="inline-flex items-center">
              <input
                type="radio"
                className="form-radio"
                name="api-provider"
                checked={useOllama && !useLangChain}
                onChange={() => {
                  setUseOllama(true);
                  setUseLangChain(false);
                }}
              />
              <span className="ml-2">Direct Ollama API</span>
            </label>
            
            <label className="inline-flex items-center">
              <input
                type="radio"
                className="form-radio"
                name="api-provider"
                checked={useLangChain}
                onChange={() => {
                  setUseLangChain(true);
                }}
              />
              <span className="ml-2">LangChain API</span>
            </label>
          </div>
          
          <PromptBox
            useOllama={useOllama && !useLangChain}
            useLangChain={useLangChain}
            availableModels={models}
            defaultModel={models[0] || 'llama2'}
          />
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow mb-8">
          <h2 className="text-lg font-medium text-gray-900 mb-4">Prompt Templates</h2>
          <div className="space-y-4">
            <div className="border border-gray-200 rounded p-4">
              <h3 className="font-medium mb-2">Summarization</h3>
              <p className="text-sm text-gray-600 mb-2">Summarize a piece of text to extract the key points.</p>
              <pre className="bg-gray-50 p-2 rounded text-sm overflow-x-auto">
                Please summarize the following text into a few key points:
                
                {'{text}'}
              </pre>
            </div>
            
            <div className="border border-gray-200 rounded p-4">
              <h3 className="font-medium mb-2">Code Generation</h3>
              <p className="text-sm text-gray-600 mb-2">Generate code based on a specification.</p>
              <pre className="bg-gray-50 p-2 rounded text-sm overflow-x-auto">
                Write a {'{language}'} function that {'{task}'}.
                
                The code should be well-commented and follow best practices.
              </pre>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PromptTest;
EOF

  # Create additional page stubs
  log "INFO" "Creating additional page stubs..."
  
  # Create langchain-playground.tsx (stub)
  cat > "${APP_SRC_DIR}/pages/langchain-playground.tsx" << 'EOF'
import { NextPage } from 'next';
import Head from 'next/head';

const LangChainPlayground: NextPage = () => {
  return (
    <div>
      <Head>
        <title>LangChain Playground - AI Dashboard</title>
        <meta name="description" content="Design and test LangChain chains" />
      </Head>

      <div>
        <h1 className="text-2xl font-semibold text-gray-900 mb-4">LangChain Playground</h1>
        <p className="text-gray-600 mb-8">
          Design, test, and deploy LangChain chains for your applications.
        </p>
        
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-8">
          <div className="flex">
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                This feature is still in development. Check back soon for updates!
              </p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-lg font-medium text-gray-900 mb-4">Available Chains</h2>
          <div className="border border-gray-200 rounded p-4 text-center text-gray-500">
            No chains available yet
          </div>
        </div>
      </div>
    </div>
  );
};

export default LangChainPlayground;
EOF

  log "INFO" "Created main page templates at ${APP_SRC_DIR}/pages"
}

# Create settings page
create_settings_page() {
  log "INFO" "Creating settings page..."
  
  # Create llm-settings.tsx
  cat > "${APP_SRC_DIR}/pages/llm-settings.tsx" << 'EOF'
import { useState, useEffect } from 'react';
import { NextPage } from 'next';
import Head from 'next/head';
import { dashboard, ollama } from '../lib/api';

const LLMSettings: NextPage = () => {
  const [settings, setSettings] = useState<any>({
    ollama: {
      enabled: process.env.OLLAMA_API_URL !== undefined,
      defaultModel: 'llama2',
      modelsLoaded: [],
      apiUrl: process.env.OLLAMA_API_URL || 'http://localhost:11434',
    },
    openai: {
      enabled: process.env.OPENAI_ENABLED === 'true',
      apiKey: '',
      model: 'gpt-3.5-turbo',
    },
    langchain: {
      enabled: process.env.LANGCHAIN_API_URL !== undefined,
      apiUrl: process.env.LANGCHAIN_API_URL || 'http://localhost:5111',
    },
  });
  const [saveStatus, setSaveStatus] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [availableModels, setAvailableModels] = useState<string[]>([]);
  
  useEffect(() => {
    const fetchSettings = async () => {
      try {
        // Fetch current settings from API
        const currentSettings = await dashboard.getSettings();
        if (currentSettings) {
          setSettings(prevSettings => ({
            ...prevSettings,
            ...currentSettings,
          }));
        }
        
        // Fetch available models from Ollama if enabled
        if (settings.ollama.enabled) {
          try {
            const models = await ollama.getModels();
            if (models && models.length > 0) {
              setAvailableModels(models.map((model: any) => model.name));
              setSettings(prevSettings => ({
                ...prevSettings,
                ollama: {
                  ...prevSettings.ollama,
                  modelsLoaded: models.map((model: any) => model.name),
                }
              }));
            }
          } catch (error) {
            console.error('Error fetching Ollama models:', error);
          }
        }
      } catch (error) {
        console.error('Error fetching settings:', error);
        setError('Failed to load dashboard data');
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchSettings();
  }, []);
  
  const handleSaveSettings = async () => {
    setSaveStatus('Saving...');
    try {
      await dashboard.saveSettings(settings);
      setSaveStatus('Settings saved successfully!');
      setTimeout(() => setSaveStatus(''), 3000);
    } catch (error) {
      console.error('Error saving settings:', error);
      setSaveStatus('Error saving settings. Please try again.');
      setTimeout(() => setSaveStatus(''), 5000);
    }
  };
  
  const handleChange = (section: string, field: string, value: any) => {
    setSettings({
      ...settings,
      [section]: {
        ...settings[section],
        [field]: value,
      },
    });
  };
  
  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-lg text-gray-600">Loading settings...</div>
      </div>
    );
  }

  return (
    <div>
      <Head>
        <title>LLM Settings - AI Dashboard</title>
        <meta name="description" content="Configure LLM settings" />
      </Head>

      <div>
        <h1 className="text-2xl font-semibold text-gray-900 mb-4">LLM Settings</h1>
        <p className="text-gray-600 mb-8">
          Configure your LLM providers and default settings for AI services.
        </p>
        
        {saveStatus && (
          <div className={`p-4 mb-4 ${saveStatus.includes('Error') ? 'bg-red-50 border-l-4 border-red-400' : 'bg-green-50 border-l-4 border-green-400'}`}>
            <div className="flex">
              <div className="ml-3">
                <p className={`text-sm ${saveStatus.includes('Error') ? 'text-red-700' : 'text-green-700'}`}>
                  {saveStatus}
                </p>
              </div>
            </div>
          </div>
        )}
        
        <div className="space-y-8">
          {/* Ollama Settings */}
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-medium text-gray-900 mb-4">Ollama Configuration</h2>
            
            <div className="mb-4">
              <label className="inline-flex items-center">
                <input
                  type="checkbox"
                  className="form-checkbox"
                  checked={settings.ollama.enabled}
                  onChange={(e) => handleChange('ollama', 'enabled', e.target.checked)}
                />
                <span className="ml-2">Enable Ollama</span>
              </label>
            </div>
            
            {settings.ollama.enabled && (
              <>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Ollama API URL
                  </label>
                  <input
                    type="text"
                    className="form-input block w-full rounded-md border-gray-300"
                    value={settings.ollama.apiUrl}
                    onChange={(e) => handleChange('ollama', 'apiUrl', e.target.value)}
                  />
                </div>
                
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Default Model
                  </label>
                  <select
                    className="form-select block w-full rounded-md border-gray-300"
                    value={settings.ollama.defaultModel}
                    onChange={(e) => handleChange('ollama', 'defaultModel', e.target.value)}
                  >
                    {availableModels.length > 0 ? (
                      availableModels.map((model) => (
                        <option key={model} value={model}>{model}</option>
                      ))
                    ) : (
                      <option value="llama2">llama2</option>
                    )}
                  </select>
                </div>
                
                <div className="mb-4">
                  <span className="block text-sm font-medium text-gray-700 mb-1">
                    Models Available
                  </span>
                  <div className="bg-gray-50 p-3 rounded border border-gray-200">
                    {settings.ollama.modelsLoaded.length > 0 ? (
                      <div className="flex flex-wrap gap-2">
                        {settings.ollama.modelsLoaded.map((model: string) => (
                          <span key={model} className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            {model}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <p className="text-sm text-gray-500">No models found. Please check your Ollama service.</p>
                    )}
                  </div>
                </div>
              </>
            )}
          </div>
          
          {/* OpenAI Settings */}
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-medium text-gray-900 mb-4">OpenAI Configuration</h2>
            
            <div className="mb-4">
              <label className="inline-flex items-center">
                <input
                  type="checkbox"
                  className="form-checkbox"
                  checked={settings.openai.enabled}
                  onChange={(e) => handleChange('openai', 'enabled', e.target.checked)}
                />
                <span className="ml-2">Enable OpenAI</span>
              </label>
            </div>
            
            {settings.openai.enabled && (
              <>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    OpenAI API Key
                  </label>
                  <input
                    type="password"
                    className="form-input block w-full rounded-md border-gray-300"
                    value={settings.openai.apiKey}
                    onChange={(e) => handleChange('openai', 'apiKey', e.target.value)}
                    placeholder="sk-..."
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Your API key is stored securely and only used for API calls.
                  </p>
                </div>
                
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Default Model
                  </label>
                  <select
                    className="form-select block w-full rounded-md border-gray-300"
                    value={settings.openai.model}
                    onChange={(e) => handleChange('openai', 'model', e.target.value)}
                  >
                    <option value="gpt-3.5-turbo">gpt-3.5-turbo</option>
                    <option value="gpt-4">gpt-4</option>
                    <option value="gpt-4-turbo">gpt-4-turbo</option>
                  </select>
                </div>
              </>
            )}
          </div>
          
          {/* LangChain Settings */}
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-medium text-gray-900 mb-4">LangChain Configuration</h2>
            
            <div className="mb-4">
              <label className="inline-flex items-center">
                <input
                  type="checkbox"
                  className="form-checkbox"
                  checked={settings.langchain.enabled}
                  onChange={(e) => handleChange('langchain', 'enabled', e.target.checked)}
                />
                <span className="ml-2">Enable LangChain</span>
              </label>
            </div>
            
            {settings.langchain.enabled && (
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  LangChain API URL
                </label>
                <input
                  type="text"
                  className="form-input block w-full rounded-md border-gray-300"
                  value={settings.langchain.apiUrl}
                  onChange={(e) => handleChange('langchain', 'apiUrl', e.target.value)}
                />
              </div>
            )}
          </div>
          
          <div className="flex justify-end">
            <button
              type="button"
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              onClick={handleSaveSettings}
            >
              Save Settings
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LLMSettings;
EOF

  log "INFO" "Created settings page at ${APP_SRC_DIR}/pages/llm-settings.tsx"
}

# Create API integration library
create_api_lib() {
  log "INFO" "Creating API integration library..."
  
  # Ensure the lib directory exists
  mkdir -p "${APP_SRC_DIR}/lib"
  
  # Create api.ts
  cat > "${APP_SRC_DIR}/lib/api.ts" << 'EOF'
// API integration library for AI Dashboard

// Configuration for base URLs
const apiConfig = {
  dashboard: process.env.NEXT_PUBLIC_DASHBOARD_API_URL || '/api',
  ollama: process.env.NEXT_PUBLIC_OLLAMA_API_URL || 'http://localhost:11434',
  langchain: process.env.NEXT_PUBLIC_LANGCHAIN_API_URL || 'http://localhost:5111',
  openai: process.env.NEXT_PUBLIC_OPENAI_API_URL || 'https://api.openai.com/v1',
};

// Helper for API fetch with error handling
const fetchWithErrorHandling = async (url: string, options?: RequestInit) => {
  try {
    const response = await fetch(url, options);
    
    // If the response was not ok, throw an error
    if (!response.ok) {
      const errorData = await response.json().catch(() => null);
      throw new Error(
        errorData?.error || `API error: ${response.status} ${response.statusText}`
      );
    }
    
    // If we made it here, parse the JSON
    return await response.json();
  } catch (error) {
    console.error(`Fetch error for ${url}:`, error);
    throw error;
  }
};

// Dashboard API
export const dashboard = {
  // Get dashboard status
  getStatus: async () => {
    return fetchWithErrorHandling(`${apiConfig.dashboard}/status`);
  },
  
  // Get LLM settings
  getSettings: async () => {
    return fetchWithErrorHandling(`${apiConfig.dashboard}/settings`);
  },
  
  // Save LLM settings
  saveSettings: async (settings: any) => {
    return fetchWithErrorHandling(`${apiConfig.dashboard}/settings`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(settings),
    });
  },
  
  // Get usage statistics
  getUsageStats: async (days: number = 7) => {
    return fetchWithErrorHandling(`${apiConfig.dashboard}/usage?days=${days}`);
  },
};

// Ollama API
export const ollama = {
  // Get list of models
  getModels: async () => {
    return fetchWithErrorHandling(`${apiConfig.ollama}/api/tags`)
      .then(data => data.models || [])
      .catch(err => {
        console.error('Failed to fetch Ollama models:', err);
        return [];
      });
  },
  
  // Generate completion
  generateCompletion: async (model: string, prompt: string, options: any = {}) => {
    return fetchWithErrorHandling(`${apiConfig.ollama}/api/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        prompt,
        ...options,
      }),
    });
  },
  
  // Pull a new model
  pullModel: async (model: string) => {
    return fetchWithErrorHandling(`${apiConfig.ollama}/api/pull`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name: model }),
    });
  },
};

// LangChain API
export const langchain = {
  // Get available chains
  getChains: async () => {
    return fetchWithErrorHandling(`${apiConfig.langchain}/chains`);
  },
  
  // Run a chain
  runChain: async (chainId: string, input: any) => {
    return fetchWithErrorHandling(`${apiConfig.langchain}/chains/${chainId}/run`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(input),
    });
  },
  
  // Get available tools
  async getTools() {
    return fetchWithErrorHandling(`${apiConfig.langchain}/tools`);
  },
  
  // Run a tool
  async runTool(toolId: string, input: any) {
    return fetchWithErrorHandling(`${apiConfig.langchain}/tools/${toolId}/run`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(input),
    });
  },
  
  // Get health status
  async getHealth() {
    return fetchWithErrorHandling(`${apiConfig.langchain}/health`);
  },
};

// OpenAI API
export const openai = {
  // Generate completion with OpenAI
  generateCompletion: async (model: string, messages: any[], options: any = {}, apiKey: string) => {
    return fetchWithErrorHandling(`${apiConfig.openai}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages,
        ...options,
      }),
    });
  },
};

export default {
  dashboard,
  ollama,
  langchain,
  openai,
};
EOF

  log "INFO" "Created API integration library at ${APP_SRC_DIR}/lib/api.ts"
}

# Create API routes
create_api_routes() {
  log "INFO" "Creating API routes..."
  
  # Ensure the API directory exists
  mkdir -p "${APP_SRC_DIR}/pages/api"
  
  # Create health.ts
  cat > "${APP_SRC_DIR}/pages/api/health.ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';

type HealthData = {
  status: string;
  timestamp: string;
  version: string;
  environment: string;
}

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse<HealthData>
) {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  });
}
EOF

  # Create status.ts
  cat > "${APP_SRC_DIR}/pages/api/status.ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';
import fetch from 'node-fetch';

type StatusData = {
  llms: {
    ollama?: {
      status: string;
      models?: string[];
      apiCalls24h?: number;
    },
    openai?: {
      status: string;
      tokens24h?: number;
    }
  },
  langchain?: {
    status: string;
    chains?: number;
    tools?: number;
    apiCalls24h?: number;
  }
}

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const statusData: StatusData = {
    llms: {}
  };
  
  try {
    // Check Ollama status
    if (process.env.OLLAMA_API_URL) {
      try {
        const ollamaResponse = await fetch(`${process.env.OLLAMA_API_URL}/api/tags`);
        if (ollamaResponse.ok) {
          const ollamaData = await ollamaResponse.json();
          statusData.llms.ollama = {
            status: 'running',
            models: ollamaData.models ? ollamaData.models.map((model: any) => model.name) : [],
            apiCalls24h: Math.floor(Math.random() * 1000) // Mock data for now, replace with actual metrics
          };
        } else {
          statusData.llms.ollama = { status: 'error' };
        }
      } catch (error) {
        statusData.llms.ollama = { status: 'unreachable' };
      }
    } else {
      statusData.llms.ollama = { status: 'disabled' };
    }
    
    // Check OpenAI status - just mocked for now
    if (process.env.OPENAI_ENABLED === 'true') {
      statusData.llms.openai = {
        status: 'running',
        tokens24h: Math.floor(Math.random() * 10000) // Mock data for now
      };
    } else {
      statusData.llms.openai = { status: 'disabled' };
    }
    
    // Check LangChain status
    if (process.env.LANGCHAIN_API_URL) {
      try {
        const langchainResponse = await fetch(`${process.env.LANGCHAIN_API_URL}/health`);
        if (langchainResponse.ok) {
          // Try to get chains and tools
          let chainsCount = 0;
          let toolsCount = 0;
          
          try {
            const chainsResponse = await fetch(`${process.env.LANGCHAIN_API_URL}/chains`);
            if (chainsResponse.ok) {
              const chainsData = await chainsResponse.json();
              chainsCount = chainsData.length || 0;
            }
          } catch (error) {
            console.error('Error fetching chains:', error);
          }
          
          try {
            const toolsResponse = await fetch(`${process.env.LANGCHAIN_API_URL}/tools`);
            if (toolsResponse.ok) {
              const toolsData = await toolsResponse.json();
              toolsCount = toolsData.length || 0;
            }
          } catch (error) {
            console.error('Error fetching tools:', error);
          }
          
          statusData.langchain = {
            status: 'running',
            chains: chainsCount,
            tools: toolsCount,
            apiCalls24h: Math.floor(Math.random() * 500) // Mock data for now
          };
        } else {
          statusData.langchain = { status: 'error' };
        }
      } catch (error) {
        statusData.langchain = { status: 'unreachable' };
      }
    } else {
      statusData.langchain = { status: 'disabled' };
    }
    
    res.status(200).json(statusData);
  } catch (error) {
    console.error('Error generating status data:', error);
    res.status(500).json({ error: 'Failed to generate status data' });
  }
}
EOF

  # Create settings.ts
  cat > "${APP_SRC_DIR}/pages/api/settings.ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';
import fs from 'fs';
import path from 'path';

// Path to store settings
const SETTINGS_PATH = process.env.SETTINGS_PATH || '/opt/agency_stack/clients';
const CLIENT_ID = process.env.CLIENT_ID || 'default';
const SETTINGS_FILE = path.join(SETTINGS_PATH, CLIENT_ID, 'ai/dashboard/settings.json');

// Ensure settings directory exists
const ensureSettingsDir = () => {
  const settingsDir = path.dirname(SETTINGS_FILE);
  if (!fs.existsSync(settingsDir)) {
    fs.mkdirSync(settingsDir, { recursive: true });
  }
};

// Get default settings
const getDefaultSettings = () => {
  return {
    ollama: {
      enabled: process.env.OLLAMA_API_URL !== undefined,
      defaultModel: 'llama2',
      modelsLoaded: [],
      apiUrl: process.env.OLLAMA_API_URL || 'http://localhost:11434',
    },
    openai: {
      enabled: process.env.OPENAI_ENABLED === 'true',
      model: 'gpt-3.5-turbo',
      // We don't store API keys in default settings for security
    },
    langchain: {
      enabled: process.env.LANGCHAIN_API_URL !== undefined,
      apiUrl: process.env.LANGCHAIN_API_URL || 'http://localhost:5111',
    },
  };
};

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  ensureSettingsDir();
  
  if (req.method === 'GET') {
    try {
      let settings;
      if (fs.existsSync(SETTINGS_FILE)) {
        const settingsData = fs.readFileSync(SETTINGS_FILE, 'utf8');
        settings = JSON.parse(settingsData);
      } else {
        settings = getDefaultSettings();
        // Write default settings for future use
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
      }
      
      // For security, don't return sensitive values like API keys to the frontend
      if (settings.openai && settings.openai.apiKey) {
        settings.openai.apiKey = ''; // Clear API key before sending to client
      }
      
      res.status(200).json(settings);
    } catch (error) {
      console.error('Error reading settings:', error);
      res.status(500).json({ error: 'Failed to read settings' });
    }
  } else if (req.method === 'POST') {
    try {
      const newSettings = req.body;
      
      // Load existing settings to keep any sensitive values
      let existingSettings = {};
      if (fs.existsSync(SETTINGS_FILE)) {
        const settingsData = fs.readFileSync(SETTINGS_FILE, 'utf8');
        existingSettings = JSON.parse(settingsData);
      }
      
      // Merge new settings with existing
      const mergedSettings = {
        ...existingSettings,
        ...newSettings,
      };
      
      // If the API key is empty, keep the old one
      if (mergedSettings.openai && newSettings.openai) {
        if (!newSettings.openai.apiKey && existingSettings.openai && existingSettings.openai.apiKey) {
          mergedSettings.openai.apiKey = existingSettings.openai.apiKey;
        }
      }
      
      // Save updated settings
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(mergedSettings, null, 2));
      
      // For security, don't return sensitive values
      if (mergedSettings.openai && mergedSettings.openai.apiKey) {
        mergedSettings.openai.apiKey = '';
      }
      
      res.status(200).json(mergedSettings);
    } catch (error) {
      console.error('Error saving settings:', error);
      res.status(500).json({ error: 'Failed to save settings' });
    }
  } else {
    // Method not allowed
    res.setHeader('Allow', ['GET', 'POST']);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
EOF

  # Create usage.ts
  cat > "${APP_SRC_DIR}/pages/api/usage.ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';

type UsageData = {
  days: number;
  ollamaApiCalls: number[];
  ollamaTokensGenerated: number[];
  openaiApiCalls: number[];
  openaiTokensGenerated: number[];
  langchainApiCalls: number[];
  dates: string[];
}

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Get the number of days from query parameter
  const days = parseInt(req.query.days as string) || 7;
  
  // Generate mock data (replace with actual metrics in production)
  const dates: string[] = [];
  const ollamaApiCalls: number[] = [];
  const ollamaTokensGenerated: number[] = [];
  const openaiApiCalls: number[] = [];
  const openaiTokensGenerated: number[] = [];
  const langchainApiCalls: number[] = [];
  
  // Generate dates and mock data for each day
  const today = new Date();
  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    dates.push(date.toISOString().split('T')[0]);
    
    // Mock random data
    ollamaApiCalls.push(Math.floor(Math.random() * 100) + 10);
    ollamaTokensGenerated.push(Math.floor(Math.random() * 50000) + 5000);
    openaiApiCalls.push(Math.floor(Math.random() * 50) + 5);
    openaiTokensGenerated.push(Math.floor(Math.random() * 20000) + 2000);
    langchainApiCalls.push(Math.floor(Math.random() * 80) + 8);
  }
  
  res.status(200).json({
    days,
    ollamaApiCalls,
    ollamaTokensGenerated,
    openaiApiCalls,
    openaiTokensGenerated,
    langchainApiCalls,
    dates,
  });
}
EOF

  # Create proxy route for Ollama
  cat > "${APP_SRC_DIR}/pages/api/ollama/[...path].ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';
import fetch from 'node-fetch';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { path } = req.query;
  
  if (!process.env.OLLAMA_API_URL) {
    return res.status(404).json({ error: 'Ollama API URL not configured' });
  }
  
  try {
    // Build target URL
    const pathStr = Array.isArray(path) ? path.join('/') : path;
    const targetUrl = `${process.env.OLLAMA_API_URL}/api/${pathStr}`;
    
    // Get request body, if any
    const body = req.body ? JSON.stringify(req.body) : undefined;
    
    // Forward request to Ollama
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
      },
      body,
    });
    
    // Get response data
    const data = await response.text();
    
    // Set response headers
    res.setHeader('Content-Type', response.headers.get('Content-Type') || 'application/json');
    
    // Return response with the same status code
    res.status(response.status).send(data);
  } catch (error) {
    console.error('Error proxying request to Ollama:', error);
    res.status(500).json({ error: 'Failed to proxy request to Ollama API' });
  }
}
EOF

  # Create proxy route for LangChain
  cat > "${APP_SRC_DIR}/pages/api/langchain/[...path].ts" << 'EOF'
import type { NextApiRequest, NextApiResponse } from 'next';
import fetch from 'node-fetch';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { path } = req.query;
  
  if (!process.env.LANGCHAIN_API_URL) {
    return res.status(404).json({ error: 'LangChain API URL not configured' });
  }
  
  try {
    // Build target URL
    const pathStr = Array.isArray(path) ? path.join('/') : path;
    const targetUrl = `${process.env.LANGCHAIN_API_URL}/${pathStr}`;
    
    // Get request body, if any
    const body = req.body ? JSON.stringify(req.body) : undefined;
    
    // Forward request to LangChain
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
      },
      body,
    });
    
    // Get response data
    const data = await response.text();
    
    // Set response headers
    res.setHeader('Content-Type', response.headers.get('Content-Type') || 'application/json');
    
    // Return response with the same status code
    res.status(response.status).send(data);
  } catch (error) {
    console.error('Error proxying request to LangChain:', error);
    res.status(500).json({ error: 'Failed to proxy request to LangChain API' });
  }
}
EOF

  log "INFO" "Created API routes at ${APP_SRC_DIR}/pages/api"
}

# Update the main script flow to include creating the API routes
install_ai_dashboard() {
  log "INFO" "Installing AI Dashboard..."
  
  # Create directories
  create_directories
  
  # Create config
  create_nextjs_config
  
  # Create package.json
  create_package_json
  
  # Create Tailwind config
  create_tailwind_config
  
  # Create global styles
  create_global_styles
  
  # Create React components
  create_react_components
  
  # Create page templates
  create_pages
  
  # Create settings page
  create_settings_page
  
  # Create API integration library
  create_api_lib
  
  # Create API routes
  create_api_routes
  
  # Create Docker configuration
  create_docker_config
  
  # Set up Docker environment
  setup_docker
  
  # Setup Traefik configuration
  setup_traefik
  
  # Update component registry
  update_component_registry
  
  log "SUCCESS" "AI Dashboard installation complete at ${APP_DIR}"
  log "SUCCESS" "Dashboard URL: https://ai.${DOMAIN}"
  log "INFO" "To restart the service: make ai-dashboard-restart"
  log "INFO" "To view logs: make ai-dashboard-logs"
}

# Run the main function with the provided options and arguments
main "$@"

# Source external component files
source "$(dirname "$0")/docker_config_ai_dashboard.sh"
source "$(dirname "$0")/traefik_registry_ai_dashboard.sh"

# Create documentation function - documentation already created at /docs/pages/ai/dashboard.md
create_documentation() {
  log "INFO" "Documentation already created at ${ROOT_DIR}/docs/pages/ai/dashboard.md"
}

# Install AI Dashboard - updated flow to use sourced functions
install_ai_dashboard() {
  log "INFO" "Installing AI Dashboard..."
  
  # Create directories
  create_directories
  
  # Create config
  create_nextjs_config
  
  # Create package.json
  create_package_json
  
  # Create Tailwind config
  create_tailwind_config
  
  # Create global styles
  create_global_styles
  
  # Create React components
  create_react_components
  
  # Create page templates
  create_pages
  
  # Create settings page
  create_settings_page
  
  # Create API integration library
  create_api_lib
  
  # Create API routes
  create_api_routes
  
  # Create Docker configuration
  create_docker_config
  
  # Set up Docker environment
  setup_docker
  
  # Setup Traefik configuration
  setup_traefik
  
  # Update component registry
  update_component_registry
  
  # Create/update documentation
  create_documentation
  
  log "SUCCESS" "AI Dashboard installation complete at ${APP_DIR}"
  log "SUCCESS" "Dashboard URL: https://ai.${DOMAIN}"
  log "INFO" "To restart the service: make ai-dashboard-restart"
  log "INFO" "To view logs: make ai-dashboard-logs"
}
