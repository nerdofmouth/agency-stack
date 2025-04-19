# Agent Tools Bridge

A NextJS-based interface that bridges the Agent Orchestrator backend with the AI Control Panel frontend for AgencyStack.

## Overview

This application provides a user-friendly interface for sovereign entrepreneurs to:
- Monitor AI recommendations from the orchestrator
- Execute safe actions for AI components
- View system logs and performance metrics
- Test AI prompts using the LangChain API

## Getting Started

### Installation

Install dependencies:

```bash
npm install
```

### Development

Run the development server:

```bash
npm run dev
```

Open [http://localhost:5120](http://localhost:5120) in your browser.

### Production Build

Build for production:

```bash
npm run build
npm run start
```

## Project Structure

```
/apps/agent_tools/
├── components/            # React components
│   ├── AgentDashboard.tsx # Lists AI recommendations
│   ├── AgentActions.tsx   # Shows available safe actions
│   ├── AgentLogs.tsx      # Shows logs per component
│   ├── AgentMetrics.tsx   # Shows metrics per component
│   ├── PromptSandbox.tsx  # Prompt testing environment
│   └── Layout.tsx         # Main application layout
├── pages/                 # NextJS pages
│   ├── index.tsx          # Dashboard page
│   ├── actions.tsx        # Actions page
│   ├── logs.tsx           # Logs page
│   ├── metrics.tsx        # Metrics page
│   ├── sandbox.tsx        # Prompt sandbox page
│   └── api/               # API routes
│       └── agent/         # Agent-related endpoints
│           ├── recommendations.ts    # Get agent recommendations
│           ├── actions.ts            # Execute safe actions
│           ├── logs/[component].ts   # Get component logs
│           ├── metrics/[component].ts# Get component metrics
│           └── prompt.ts             # Test AI prompts
├── styles/                # CSS files
│   └── globals.css        # Global styles with Tailwind
├── public/                # Static assets
├── package.json           # Dependencies and scripts
└── README.md              # Documentation
```

## Usage

The application requires a running Agent Orchestrator backend (default port: 5210).

Pass your client ID via the URL:

```
http://localhost:5120?client_id=your_client_id
```

## Makefile Commands

From the AgencyStack root:

```bash
# Install the Agent Tools Bridge
make ai-agent-tools

# Start the Agent Tools Bridge
make ai-agent-tools-start

# Check status
make ai-agent-tools-status
```

## Documentation

For detailed documentation, see the [Agent Tools Bridge Guide](/docs/pages/ai/agent_tools.md).
