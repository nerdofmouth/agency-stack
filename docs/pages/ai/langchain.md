# LangChain

LangChain is a powerful framework for developing applications powered by language models. Integrated into AgencyStack, it provides a structured way to create chains, agents, and tools that use Large Language Models (LLMs) like those provided by Ollama or OpenAI.

## Overview

- **Component Type**: AI Foundation / Developer Service
- **Ports**: 5111 (API)
- **Multi-tenant**: Yes
- **Hardened**: Yes
- **Data Location**: `/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain`

LangChain is designed to facilitate the development of context-aware, reasoning applications by creating chains that combine prompts, models, and actions in a structured way. It's particularly useful for building complex AI assistants, autonomous agents, and workflow automation tools.

## Installation

### Prerequisites

- Linux system with Docker and Docker Compose
- Recommended: Local LLM service (Ollama) or OpenAI API key

### Basic Installation

```bash
make langchain
```

### Installation with Ollama Integration

```bash
make langchain ARGS="--client-id client1 --use-ollama"
```

### Installation with OpenAI Integration

```bash
make langchain ARGS="--client-id client1 --enable-openai"
```

### Available Installation Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client ID for multi-tenant setup | `default` |
| `--domain` | Domain name for service | `localhost` |
| `--port` | Port for LangChain API | `5111` |
| `--enable-openai` | Enable OpenAI API integration | `false` |
| `--use-ollama` | Configure to use local Ollama LLM | `false` |
| `--ollama-port` | Port for Ollama API | `11434` |
| `--with-deps` | Install dependencies (Docker, etc.) | `false` |
| `--force` | Force installation even if already installed | `false` |
| `--disable-monitoring` | Disable monitoring integration | `false` |

## Management

AgencyStack provides several Makefile targets to manage your LangChain installation:

| Command | Description |
|---------|-------------|
| `make langchain-status` | Show LangChain service status and available chains/tools |
| `make langchain-logs` | Display LangChain container logs |
| `make langchain-stop` | Stop the LangChain service |
| `make langchain-start` | Start the LangChain service |
| `make langchain-restart` | Restart the LangChain service |
| `make langchain-test` | Test the LangChain API with a simple prompt |

## API Endpoints

LangChain provides a RESTful API for interacting with language models, chains, and tools:

### Health Check

```
GET /health
```

Returns the current status of the LangChain service.

### List Available Chains

```
GET /chains
```

Returns a list of available chains that can be run.

### Run a Chain

```
POST /chain/run
```

**Request Body:**
```json
{
  "chain_id": "summarize",
  "inputs": {
    "text": "This is the text I want to summarize."
  },
  "streaming": false
}
```

Executes a specific chain with the provided inputs.

### Run a Simple Prompt

```
POST /prompt
```

**Request Body:**
```json
{
  "template": "What is {topic}?",
  "inputs": {
    "topic": "LangChain"
  },
  "model": "llama2",
  "temperature": 0.7,
  "streaming": false
}
```

Runs a templated prompt through the configured LLM provider.

### List Available Tools

```
GET /tools
```

Returns a list of available tools that can be used by agents.

## Integration with LLM Providers

LangChain can be configured to use different LLM providers:

### Ollama Integration

When installed with `--use-ollama`, LangChain will automatically connect to your local Ollama instance. This provides:

- Private, self-hosted model inference
- Access to all models installed in Ollama
- No data sent to external services

Example API call using Ollama:

```bash
curl -X POST "http://localhost:5111/prompt" \
  -H "Content-Type: application/json" \
  -d '{
    "template": "Write a short poem about {topic}",
    "inputs": {
      "topic": "artificial intelligence"
    },
    "model": "llama2",
    "temperature": 0.7
  }'
```

### OpenAI Integration

When installed with `--enable-openai`, LangChain can use OpenAI's cloud-based models. You'll need to:

1. Set your OpenAI API key in the configuration file
2. Configure the model you want to use

The OpenAI API key should be set in:
```
/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/config/.env
```

Example API call using OpenAI:

```bash
curl -X POST "http://localhost:5111/prompt" \
  -H "Content-Type: application/json" \
  -d '{
    "template": "Explain {topic} in simple terms",
    "inputs": {
      "topic": "quantum computing"
    },
    "model": "gpt-3.5-turbo",
    "temperature": 0.3
  }'
```

## Working with Chains and Tools

LangChain allows you to create reusable chains and tools for your AI applications.

### Chains

Chains are stored as JSON configuration files in:
```
/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/chains/
```

A chain definition includes:
- Input parameters
- LLM configuration
- Prompt templates
- Processing logic

Example chain definition (`summarize.json`):
```json
{
  "name": "Text Summarizer",
  "description": "Chain that summarizes a text document",
  "inputs": ["text"],
  "llm_config": {
    "temperature": 0.3
  },
  "prompt_template": "Please summarize the following text in a concise manner:\n\n{text}\n\nSummary:"
}
```

### Tools

Tools are Python modules that provide specific functionality to LangChain agents. They are stored in:
```
/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/tools/
```

Example tool implementation:
```python
from langchain.tools import BaseTool
from pydantic import BaseModel, Field

class WeatherInput(BaseModel):
    location: str = Field(..., description="The city and state")

class WeatherTool(BaseTool):
    name = "weather"
    description = "Get the current weather in a location"
    args_schema = WeatherInput

    def _run(self, location: str) -> str:
        # Implementation to get weather data
        return f"Weather for {location}: 72°F, Sunny"
```

## Multi-Tenant Usage

AgencyStack's LangChain integration supports multi-tenant usage. Each client's configuration and data are isolated:

```
/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/
```

To work with a specific client, use the CLIENT_ID parameter:

```bash
make langchain-status CLIENT_ID=client1
```

## Monitoring and Logs

### Logging

LangChain logs are stored in:
- Container logs: Access via `make langchain-logs`
- Component logs: `/var/log/agency_stack/components/langchain.log`
- API logs: `/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/config/logs/langchain-api.log`

### Monitoring

LangChain integrates with Prometheus for monitoring key metrics:
- API request counts and response times
- LLM token usage
- Chain execution success/failure rates

## Security Considerations

- API Authentication: The LangChain API doesn't include built-in authentication. For production use, deploy behind a reverse proxy with authentication.
- Data Privacy: When using OpenAI, be aware that data is sent to external cloud services.
- API Keys: OpenAI API keys are stored in configuration files. Ensure proper file permissions.

## Common Use Cases

LangChain within AgencyStack can be utilized for:

### 1. Document Processing Pipelines

Create chains that process, summarize, and extract information from documents:

```bash
curl -X POST "http://localhost:5111/chain/run" \
  -H "Content-Type: application/json" \
  -d '{
    "chain_id": "summarize",
    "inputs": {
      "text": "Your document text here..."
    }
  }'
```

### 2. Intelligent Agents

Build agents that can use tools to answer questions and perform tasks:

```bash
# Example agent that can use weather and calculator tools
curl -X POST "http://localhost:5111/agent/run" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "assistant",
    "inputs": {
      "question": "What's the weather like in Seattle and how many degrees Celsius is 72°F?"
    }
  }'
```

### 3. Knowledge-Based Chatbots

Develop chatbots with access to specific knowledge bases:

```bash
curl -X POST "http://localhost:5111/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What are our company policies on remote work?"}
    ],
    "knowledge_base": "company_policies"
  }'
```

## Integration with Other Components

LangChain can be integrated with other AgencyStack components:

### With Ollama

LangChain automatically detects and uses your Ollama installation for local, private inference.

### With Document Management Systems

LangChain can process and analyze documents stored in AgencyStack's document management systems.

### With Dashboards

LangChain's monitoring metrics can be integrated into AgencyStack dashboards for visualization.

## Further Development

### Creating Custom Chains

1. Define a new chain configuration in `/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/chains/`
2. Use the LangChain API to execute the chain

### Creating Custom Tools

1. Implement a new tool in `/opt/agency_stack/clients/[CLIENT_ID]/ai/langchain/tools/`
2. The tool will be automatically discovered and available for use

## Troubleshooting

### Common Issues

#### Connection to LLM Provider Fails

If connections to Ollama or OpenAI fail:

```bash
# Check Ollama status
make ollama-status

# Check LangChain logs
make langchain-logs
```

#### Chain Execution Errors

If a chain fails to execute:

1. Verify the chain definition is valid JSON
2. Check the logs for specific error messages
3. Ensure all required inputs are provided

## Further Reading

- [LangChain Documentation](https://python.langchain.com/docs/get_started/introduction)
- [OpenAI API Documentation](https://platform.openai.com/docs/introduction)
- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/README.md)
