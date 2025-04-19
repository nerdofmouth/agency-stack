# Agent Tools Bridge

## Overview

The Agent Tools Bridge connects the Agent Orchestrator backend with the AI Control Panel frontend, providing a user-friendly interface for sovereign entrepreneurs to monitor and control AI agents running on their own infrastructure.

This interface allows users to:
- View AI recommendations from the Agent Orchestrator
- Trigger safe actions for AI components
- Monitor system logs and metrics
- Test prompts using the LangChain API

## Prerequisites

- Agent Orchestrator must be installed and running (port 5210 by default)
- LangChain service should be accessible
- Node.js 16+ and npm 7+ for development

## Installation

### Using Makefile Target

The easiest way to install the Agent Tools Bridge is to use the provided Makefile target:

```bash
make ai-agent-tools
```

This will:
1. Install all required dependencies
2. Build the NextJS application
3. Set up the necessary configuration

### Manual Installation

If you prefer to install manually, follow these steps:

1. Navigate to the agent_tools directory:
   ```bash
   cd /path/to/agency-stack/apps/agent_tools
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the application:
   ```bash
   npm run build
   ```

## Running the Agent Tools Bridge

### Development Mode

Start the Agent Tools Bridge in development mode with:

```bash
make ai-agent-tools-start
```

Or manually:

```bash
cd /path/to/agency-stack/apps/agent_tools
npm run dev
```

The interface will be available at `http://localhost:5120`

### Production Mode

For production environments, you can build and start the application:

```bash
npm run build
npm run start
```

## Configuration

The Agent Tools Bridge can be configured using the following methods:

### Environment Variables

Create a `.env.local` file in the `agent_tools` directory with the following variables:

```
NEXT_PUBLIC_ORCHESTRATOR_API=http://localhost:5210
NEXT_PUBLIC_DEFAULT_CLIENT_ID=your_default_client_id
```

### Query Parameters

You can also pass configuration via URL query parameters:

- `client_id`: Specify the client ID for multi-tenant setups
  Example: `http://localhost:5120?client_id=client1`

## Components

### AgentDashboard

The main dashboard displays AI recommendations from the Agent Orchestrator. It shows:
- Action recommendations based on system analysis
- Urgency levels and relevance
- One-click execution for safe actions

### AgentActions

Displays available safe actions that can be triggered manually:
- Service management (restart services)
- Data management (sync logs)
- Model management (pull LLM models)
- Cache management (clear caches)
- Diagnostics (run tests)

### AgentLogs

Provides a real-time view of system logs from different components:
- Agent Orchestrator logs
- LangChain logs
- Ollama logs
- Filtering capabilities
- Download option for offline analysis

### AgentMetrics

Visualizes performance metrics for system components:
- CPU and memory usage
- Request counts and latency
- Error rates
- Custom metrics from the Orchestrator

### PromptSandbox

A testing environment for LLM prompts:
- Send prompts directly to the LangChain API
- Configure model parameters (temperature, max tokens)
- Store prompt history for reuse
- View formatted responses

## API Routes

The Agent Tools Bridge provides the following API routes:

### `/api/agent/recommendations`

Fetches AI recommendations from the Agent Orchestrator.

**Request:**
```
GET /api/agent/recommendations?client_id=client1
```

**Response:**
```json
{
  "recommendations": [
    {
      "id": "rec123",
      "title": "Restart Database Service",
      "description": "Database connection timeouts detected",
      "action_type": "restart_service",
      "target": "database",
      "urgency": "high",
      "timestamp": "2023-04-05T15:30:45.123Z"
    }
  ]
}
```

### `/api/agent/actions`

Triggers safe actions through the Agent Orchestrator.

**Request:**
```
POST /api/agent/actions
Content-Type: application/json

{
  "client_id": "client1",
  "action": {
    "action_type": "restart_service",
    "target": "langchain",
    "description": "Restart LangChain service"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Service langchain restart initiated",
  "details": {
    "status": "pending"
  }
}
```

### `/api/agent/logs/[component]`

Retrieves logs for a specific component.

**Request:**
```
GET /api/agent/logs/langchain?client_id=client1&lines=100
```

**Response:**
```json
{
  "logs": [
    "[2023-04-05 15:30:45.123] [INFO] LangChain service started",
    "[2023-04-05 15:31:12.345] [ERROR] Database connection timeout"
  ]
}
```

### `/api/agent/metrics/[component]`

Retrieves metrics for a specific component.

**Request:**
```
GET /api/agent/metrics/langchain?client_id=client1&time_range=1h
```

**Response:**
```json
{
  "metrics": [
    {
      "name": "cpu_usage",
      "timestamps": ["2023-04-05T15:00:00Z", "2023-04-05T15:15:00Z"],
      "values": [23.5, 45.2],
      "unit": "%"
    }
  ],
  "component": "langchain",
  "start_time": "2023-04-05T15:00:00Z",
  "end_time": "2023-04-05T16:00:00Z"
}
```

### `/api/agent/prompt`

Sends a prompt to the LangChain API via the Agent Orchestrator.

**Request:**
```
POST /api/agent/prompt
Content-Type: application/json

{
  "client_id": "client1",
  "prompt": "Explain the benefits of sovereign entrepreneurship",
  "model": "llama2",
  "parameters": {
    "temperature": 0.7,
    "max_tokens": 500
  }
}
```

**Response:**
```json
{
  "response": "Sovereign entrepreneurship refers to..."
}
```

## Security Considerations

The Agent Tools Bridge implements several security measures:

1. **Client ID Validation**: All requests require a valid client ID
2. **Safe Action Constraints**: Only predefined safe actions can be executed
3. **Validation**: Input validation for all API endpoints
4. **Rate Limiting**: Prevention of API abuse (configured in production)

## Troubleshooting

### Common Issues

1. **"Agent Orchestrator is not available"**
   - Ensure the Agent Orchestrator is running on port 5210
   - Check network connectivity between services

2. **"Invalid client_id"**
   - Verify the client ID exists in your AgencyStack configuration
   - Pass the client ID via query parameter or environment variable

3. **Component not responding**
   - Check the individual component status with `make [component]-status`
   - Review logs for specific error messages

### Logs

You can view the Agent Tools Bridge logs with:

```bash
tail -f /var/log/agency_stack/components/agent_tools.log
```

## Integration with Other AgencyStack Components

The Agent Tools Bridge integrates with:

- **Agent Orchestrator**: For AI recommendations and actions
- **LangChain**: For LLM access and prompt processing
- **Monitoring Stack**: For metrics visualization
- **Multi-Tenancy System**: For client isolation

## Development

For developers looking to extend the Agent Tools Bridge:

1. Fork the repository
2. Install dependencies: `npm install`
3. Run in development mode: `npm run dev`
4. Add custom components in the `components` directory
5. Add new API routes in the `pages/api` directory
6. Submit pull requests for community review

## License

The Agent Tools Bridge is part of AgencyStack and is released under the same license terms.
