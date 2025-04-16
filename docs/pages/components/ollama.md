# Ollama

![Ollama Logo](https://ollama.com/public/ollama.png)

Ollama is a lightweight, local-first LLM (Large Language Model) server that allows you to run powerful AI models on your own hardware. AgencyStack integrates Ollama as part of the AI Foundation layer, providing a secure, hardened deployment with multi-tenant capabilities.

## Overview

- **Component Type**: AI Foundation
- **Ports**: 11434 (API), 11435 (Metrics)
- **Multi-tenant**: Yes
- **Hardened**: Yes
- **Data Location**: `/opt/agency_stack/clients/[CLIENT_ID]/ai/ollama`
- **Models Location**: `/var/lib/ollama/models`

Ollama provides a simple API for running inference with various open-source large language models. It supports models like Llama 2, Mistral, Code Llama, and others without requiring complex setup or cloud services.

## Installation

### Prerequisites

- Linux system with Docker and Docker Compose
- At least 8GB RAM (16GB+ recommended for larger models)
- At least 10GB free disk space (more recommended for multiple models)
- NVIDIA GPU with appropriate drivers (optional, for accelerated inference)

### Basic Installation

```bash
make ollama
```

### Installation with Options

```bash
make ollama ARGS="--client-id client1 --models 'llama2 mistral codellama' --memory-limit 16g --use-gpu"
```

### Available Installation Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client ID for multi-tenant setup | `default` |
| `--models` | Space-separated list of models to install | `llama2` |
| `--port` | Port for Ollama API | `11434` |
| `--metrics-port` | Port for Prometheus metrics | `11435` |
| `--memory-limit` | Memory limit for Ollama container | `8g` |
| `--with-deps` | Install dependencies (Docker, etc.) | `false` |
| `--force` | Force installation even if already installed | `false` |
| `--use-gpu` | Enable GPU acceleration (requires NVIDIA GPU and drivers) | `false` |
| `--disable-monitoring` | Disable monitoring integration | `false` |

## Management

AgencyStack provides several Makefile targets to manage your Ollama installation:

| Command | Description |
|---------|-------------|
| `make ollama-status` | Show Ollama status and loaded models |
| `make ollama-logs` | Display Ollama container logs |
| `make ollama-stop` | Stop the Ollama service |
| `make ollama-start` | Start the Ollama service |
| `make ollama-restart` | Restart the Ollama service |
| `make ollama-pull MODEL=modelname` | Pull a specific model |
| `make ollama-list` | List all available models |
| `make ollama-test MODEL=llama2 PROMPT="Your prompt here"` | Test a model with a prompt |

## Model Management

Ollama supports various LLM models. You can list available models, pull new ones, and remove ones you no longer need.

### Listing Models

```bash
make ollama-list
```

Or directly using the helper script:

```bash
ollama-list-models-[CLIENT_ID]
```

### Pulling Models

```bash
make ollama-pull MODEL=mistral
```

Or directly using the helper script:

```bash
ollama-pull-models-[CLIENT_ID]
```

### Available Models

Ollama supports many open-source models, including:

- `llama2`: Meta's Llama 2 model (7B parameters)
- `mistral`: Mistral 7B model
- `codellama`: Code-specialized Llama model
- `orca-mini`: Lightweight general-purpose model
- `vicuna`: Conversational model based on Llama
- `phi`: Microsoft's small but capable model
- `gemma`: Google's lightweight model

For the full list of available models, visit [Ollama's model library](https://ollama.com/library).

## Using the API

Ollama provides a simple HTTP API for integration with other services and applications.

### Generate Text

```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "prompt": "Tell me about AgencyStack"
  }'
```

### Chat Interface

```bash
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [
      {"role": "user", "content": "Hello, who are you?"}
    ]
  }'
```

### Full API Documentation

For complete API documentation, see the [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md).

## Multi-Tenant Usage

AgencyStack's Ollama integration supports multi-tenant usage, allowing different clients to have their own isolated configuration, models, and usage tracking.

Each client's configuration is stored in:
```
/opt/agency_stack/clients/[CLIENT_ID]/ai/ollama/
```

To work with a specific client, use the CLIENT_ID parameter:

```bash
make ollama-status CLIENT_ID=client1
make ollama-pull CLIENT_ID=client1 MODEL=mistral
```

## Integration with Other Services

Ollama can be integrated with various other AgencyStack components:

### Integration with ChatWoot

If you're using ChatWoot for customer support, you can integrate Ollama to provide AI-powered responses. This requires creating a webhook connector in ChatWoot and setting up an intermediary service to handle requests between ChatWoot and Ollama.

### Integration with Python Applications

For Python applications, you can use the Ollama Python client:

```python
import requests

def generate_text(prompt, model="llama2"):
    response = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": model, "prompt": prompt}
    )
    return response.json()["response"]

# Example usage
result = generate_text("Explain the benefits of self-hosted LLMs")
print(result)
```

## Troubleshooting

### Common Issues

#### Model Download Errors

If model downloads fail or timeout:

```bash
# Check the logs
make ollama-logs

# Try downloading with verbose output
ollama-pull-models-[CLIENT_ID]
```

#### Out of Memory Errors

If you see out-of-memory errors:

1. Increase the memory limit by reinstalling with a higher `--memory-limit` value
2. Use a smaller model that requires less RAM
3. Ensure no other memory-intensive processes are running

#### GPU Issues

If GPU acceleration isn't working:

1. Verify NVIDIA drivers are installed: `nvidia-smi`
2. Ensure nvidia-container-toolkit is installed and configured
3. Check the logs for GPU-related errors: `make ollama-logs`

### Logs

Ollama logs are stored in:
- Container logs: Access via `make ollama-logs`
- Component logs: `/var/log/agency_stack/components/ollama.log`
- Client usage logs: `/opt/agency_stack/clients/[CLIENT_ID]/ai/ollama/usage/`

## Security Considerations

- Ollama API has no built-in authentication. It's recommended to:
  - Run it behind a firewall/VPN
  - Use Traefik for TLS and basic authentication if exposing externally
  - Limit network access to the API port (11434)
- Model files are stored unencrypted, ensure proper filesystem permissions
- API requests and responses may contain sensitive data, be mindful of what you send to the model

## Performance Optimization

- Use GPU acceleration for significantly faster inference
- Smaller models (7B parameter models) run well on systems with 8GB RAM
- Larger models (13B+ parameters) require 16GB+ RAM and benefit greatly from GPU acceleration
- Consider using quantized models (4-bit or 8-bit) for better memory efficiency

## Further Reading

- [Ollama GitHub Repository](https://github.com/ollama/ollama)
- [Ollama Documentation](https://github.com/ollama/ollama/tree/main/docs)
- [Model Library](https://ollama.com/library)
