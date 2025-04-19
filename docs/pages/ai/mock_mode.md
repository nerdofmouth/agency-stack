# AI Suite Mock Mode

## Overview

The AI Suite Mock Mode provides a safe sandbox environment for testing the interaction and integration between all AI components without requiring a full installation of the underlying services. This testing harness is particularly useful for:

- Demonstrating the AI Suite capabilities without real data or resources
- Testing UI components and workflows in a controlled environment
- Verifying integrations between components work correctly
- Training new users without risk of affecting production systems

## Components

The Mock Mode simulates the following components:

1. **Agent Orchestrator** - Provides simulated recommendations and actions
2. **LangChain** - Handles mock LLM requests and responses
3. **Resource Watcher** - Generates fake metrics and resource usage data
4. **Agent Tools UI** - Enhanced with a Mock Mode banner and simulation controls

## Getting Started

### Starting the Test Harness

To start the AI Suite Test Harness, run:

```bash
make ai-mock-mode
```

This command will:
- Create test client directories
- Start mock containers for Agent Orchestrator, LangChain, and Resource Watcher
- Launch the Agent Tools UI in Mock Mode
- Set `CLIENT_ID=test` for all components

### Accessing the Test Environment

After starting the Test Harness, you can access the various components at:

- **Agent Tools UI**: http://localhost:5120/?client_id=test&mock=true
- **Agent Orchestrator**: http://localhost:5210
- **LangChain**: http://localhost:5111
- **Resource Watcher**: http://localhost:5220

### Resetting the Test Environment

To stop all mock containers and reset the test environment:

```bash
make ai-mock-mode-disable
```

This will:
- Stop all running mock containers
- Kill the Agent Tools UI process
- Clear the test client data

## Testing Flows

### Simulating Events

The Agent Tools UI includes a "Simulate" button in Mock Mode that allows you to trigger various events:

1. **High Memory Usage** - Simulates an Ollama instance consuming excessive memory
   - Triggers a resource alert
   - Generates a recommendation to clear cache

2. **Slow API Response** - Simulates the LangChain service responding slowly
   - Increases response time metrics 
   - May trigger a recommendation to restart the service

3. **New Model Available** - Simulates a new LLM model becoming available
   - Creates a recommendation to pull the new model
   - Updates the models list in the LangChain component

4. **Error Condition** - Simulates an error in one of the components
   - Generates error logs
   - May trigger a recommendation to restart the affected service

### Using the Dashboard

The Dashboard view will display simulated recommendations from the Agent Orchestrator. These recommendations will appear periodically and can be:

- Viewed in detail
- Executed (simulated execution)
- Dismissed

The recommendations will be refreshed automatically and after triggering simulated events.

### Testing Actions

The Actions view provides access to safe, pre-defined actions that can be executed against the mock services:

1. **Service Management** - Test restarting services
2. **Data Management** - Test log synchronization 
3. **Model Management** - Test model pulling operations
4. **Cache Management** - Test cache clearing operations
5. **Diagnostics** - Test running diagnostic operations

All actions are simulated but will return realistic responses to verify UI behaviors.

### Viewing Logs and Metrics

The Logs and Metrics views display simulated data that changes over time:

- **Logs** include timestamps, log levels, and realistic messages
- **Metrics** show simulated resource usage with trending patterns

### Testing Prompts

The Prompt Sandbox allows testing of LLM interactions:

1. Enter a prompt in the input field
2. Select a model (all models are simulated)
3. Configure parameters like temperature and max tokens
4. Submit the prompt to receive a simulated response

## Expected Behaviors

### What Should Succeed

The following operations should work correctly in Mock Mode:

- Viewing and executing recommendations
- Running all available actions
- Viewing logs from all components
- Viewing and filtering metrics
- Submitting prompts and receiving responses
- Triggering simulated events
- Testing all UI components and workflows

### What Should Fail

The following limitations are intentional in Mock Mode:

- Accessing real models or data
- Direct file system access
- Persistent configuration changes
- Network connections to external services

## Troubleshooting

### Common Issues

1. **Missing Mock Banner**
   - Ensure `NEXT_PUBLIC_MOCK_MODE=true` is set
   - Check that the URL includes `?mock=true`

2. **Mock Containers Not Starting**
   - Verify Docker is running
   - Check port availability (5210, 5111, 5220)
   - Examine container logs for errors

3. **Simulation Not Working**
   - Verify the mock container for the targeted service is running
   - Check browser console for API errors
   - Try resetting the test environment with `make ai-mock-mode-disable`

### Logs

Mock service logs can be viewed with:

```bash
# For Agent Orchestrator mock
docker logs agent-orchestrator-mock

# For LangChain mock
docker logs langchain-mock

# For Resource Watcher mock
docker logs resource-watcher-mock
```

## Extending the Mock Environment

### Adding Custom Simulations

The mock services can be extended by modifying the simulation scripts:

1. Edit `/scripts/mock/start_mock_server.sh` to add new simulation types
2. Add new simulation options to the Agent Tools UI in `/apps/agent_tools/components/Layout.tsx`
3. Extend the simulation API in `/apps/agent_tools/pages/api/agent/simulate.ts`

### Creating Realistic Test Data

To make the mock environment more realistic for demonstrations:

1. Copy real log formats from actual services
2. Model resource usage patterns after real-world scenarios
3. Create domain-specific prompt responses for common queries

## Transitioning to Real Environment

After testing in the mock environment, you can transition to a real environment by:

1. Installing the actual AI Suite components
   ```bash
   make install-ai-suite
   ```

2. Accessing the real Agent Tools UI without the mock flag
   ```
   http://localhost:5120/?client_id=your_client_id
   ```

3. Verifying that all tested workflows function as expected with real data

## Security Considerations

Even though the Mock Mode uses simulated data, follow these security practices:

1. Do not use real API keys or sensitive data in the mock environment
2. Avoid exposing the mock services on public networks
3. Reset the test environment when finished to clear any test data

## Conclusion

The AI Suite Mock Mode provides a safe, controlled environment for testing, training, and demonstration. By simulating realistic behaviors without requiring complex infrastructure, it allows rapid iteration and validation of the AI Suite components working together.
