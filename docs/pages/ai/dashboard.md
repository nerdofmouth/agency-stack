# AI Dashboard

## Overview

The AI Dashboard is a web interface for managing, monitoring, and interacting with the AI services in AgencyStack. It provides a unified interface to work with LLMs through Ollama, LangChain, and optionally OpenAI.

## Features

- **Service Health Monitoring**: View the status of Ollama, LangChain, and OpenAI integrations.
- **Prompt Testing**: Test prompts using different models and providers.
- **LangChain Playground**: Design and test LangChain chains.
- **LLM Settings**: Configure your LLM providers and default settings.
- **Usage Metrics**: Monitor API calls and token usage.

## Installation

### Prerequisites

- Docker
- AgencyStack core components including Traefik

### Installation Command

```bash
./scripts/components/install_ai_dashboard.sh --client-id=<client_id> --domain=<domain> [--use-ollama] [--enable-openai] [--with-deps] [--force]
```

#### Options:

- `--client-id`: Client ID for multi-tenant setup (required)
- `--domain`: Domain for the AI Dashboard (required)
- `--use-ollama`: Enable integration with Ollama
- `--enable-openai`: Enable integration with OpenAI (requires API key configuration)
- `--with-deps`: Install dependencies if not already installed
- `--force`: Force reinstallation even if already installed

### Makefile Targets

```bash
# Install AI Dashboard
make ai-dashboard

# Check the status of the AI Dashboard
make ai-dashboard-status

# View logs
make ai-dashboard-logs

# Restart the service
make ai-dashboard-restart

# Test the dashboard
make ai-dashboard-test
```

## Configuration

### Environment Variables

The AI Dashboard can be configured using environment variables:

- `CLIENT_ID`: Client ID for multi-tenant setup
- `DOMAIN`: Domain for the AI Dashboard
- `PORT`: Port for the AI Dashboard (default: 5130)
- `OLLAMA_PORT`: Port for the Ollama API (default: 11434)
- `LANGCHAIN_PORT`: Port for the LangChain API (default: 5111)
- `OPENAI_ENABLED`: Enable OpenAI integration (true/false)

### LLM Settings

LLM settings can be configured through the dashboard interface:

1. Navigate to the AI Dashboard at `https://ai.<domain>`
2. Go to "LLM Settings"
3. Configure Ollama, LangChain, and/or OpenAI settings
4. Save the configuration

## Using the AI Dashboard

### Testing Prompts

1. Go to the "Prompt Test" page
2. Select the LLM provider (Ollama or LangChain)
3. Enter your prompt
4. Configure any model-specific parameters
5. Click "Submit" to generate a response

### LangChain Playground

The LangChain Playground allows you to design and test LangChain chains:

1. Go to the "LangChain Playground" page
2. Select or create a chain
3. Configure inputs and parameters
4. Run the chain to see the output

### Monitoring Usage

The dashboard provides usage metrics for your AI services:

- API call volume
- Token usage
- Model popularity
- Error rates

## Integration with Other Components

The AI Dashboard integrates with:

- **Ollama**: For accessing open-source LLMs
- **LangChain**: For building chains and agents
- **OpenAI**: Optional integration for accessing commercial LLMs

## Troubleshooting

### Common Issues

1. **Dashboard Not Loading**: Ensure that the Docker container is running:
   ```bash
   make ai-dashboard-status
   ```

2. **Cannot Connect to Ollama/LangChain**: Verify that these services are running:
   ```bash
   make ollama-status
   make langchain-status
   ```

3. **Settings Not Saving**: Check permissions on the settings directory:
   ```bash
   ls -la /opt/agency_stack/clients/<client_id>/ai/dashboard
   ```

### Logs

View logs to diagnose issues:

```bash
make ai-dashboard-logs
```

## Security Notes

- The AI Dashboard requires HTTPS for secure operation.
- OpenAI API keys are stored securely and never exposed in the frontend.
- Multi-tenant isolation ensures that each client's data and configurations remain separate.

## Roadmap

Future plans for the AI Dashboard include:

- SSO integration with Keycloak
- Enhanced usage analytics
- Custom chain builder interface
- Fine-tuning interface for models
- Team collaboration features

## Feedback and Support

For issues, feature requests, or contributions, please contact your AgencyStack administrator or submit a ticket through the support portal.
