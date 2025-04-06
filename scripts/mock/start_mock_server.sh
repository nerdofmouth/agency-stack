#!/bin/bash
# start_mock_server.sh - Generic mock server for AgencyStack components
# This script starts a simple HTTP server that returns mock data for AI components

COMPONENT=$1
PORT=$2

if [ -z "$COMPONENT" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <component_name> <port>"
  echo "Example: $0 agent-orchestrator 5210"
  exit 1
fi

# Create a temp directory for the mock server
MOCK_DIR="/tmp/agency_stack_mock/$COMPONENT"
mkdir -p $MOCK_DIR

# Create Python mock server script
cat > $MOCK_DIR/mock_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import sys
import os
import random
import time
from datetime import datetime, timedelta
import threading

# Get configuration from arguments
component = sys.argv[1]
port = int(sys.argv[2])

# Set up component specific data
component_data = {
    "agent-orchestrator": {
        "recommendations": [
            {
                "id": "rec123",
                "title": "Restart LangChain Service",
                "description": "LangChain seems to be running slowly. A restart might improve performance.",
                "action_type": "restart_service",
                "target": "langchain",
                "urgency": "medium",
                "timestamp": (datetime.now() - timedelta(minutes=5)).isoformat()
            },
            {
                "id": "rec456",
                "title": "Clear Ollama Cache",
                "description": "Ollama cache has grown significantly. Clearing it may free up disk space.",
                "action_type": "clear_cache",
                "target": "ollama",
                "urgency": "low",
                "timestamp": (datetime.now() - timedelta(minutes=15)).isoformat()
            },
            {
                "id": "rec789",
                "title": "Pull Latest LLM Model",
                "description": "New version of 'llama2' model is available for better performance.",
                "action_type": "pull_model",
                "target": "ollama",
                "urgency": "medium",
                "timestamp": (datetime.now() - timedelta(minutes=30)).isoformat()
            }
        ],
        "logs": [
            f"[{(datetime.now() - timedelta(minutes=i)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Agent Orchestrator started successfully" for i in range(100, 0, -1)
        ] + [
            f"[{(datetime.now() - timedelta(minutes=25)).strftime('%Y-%m-%d %H:%M:%S')}] [WARN] High memory usage detected in Ollama",
            f"[{(datetime.now() - timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Sending recommendation to clear Ollama cache",
            f"[{(datetime.now() - timedelta(minutes=15)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] New model version detected for 'llama2'",
            f"[{(datetime.now() - timedelta(minutes=10)).strftime('%Y-%m-%d %H:%M:%S')}] [WARN] LangChain response time increasing",
            f"[{(datetime.now() - timedelta(minutes=5)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Sending recommendation to restart LangChain service",
        ]
    },
    "langchain": {
        "models": [
            {"name": "llama2", "provider": "ollama", "status": "loaded"},
            {"name": "mistral", "provider": "ollama", "status": "available"},
            {"name": "gpt-3.5-turbo", "provider": "openai", "status": "available"},
            {"name": "claude-instant", "provider": "anthropic", "status": "available"}
        ],
        "logs": [
            f"[{(datetime.now() - timedelta(minutes=i)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] LangChain service operational" for i in range(100, 0, -1)
        ] + [
            f"[{(datetime.now() - timedelta(minutes=30)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Processing chain request for 'qa_retrieval'",
            f"[{(datetime.now() - timedelta(minutes=25)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Loading embeddings from cache",
            f"[{(datetime.now() - timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')}] [WARN] Slow response from language model",
            f"[{(datetime.now() - timedelta(minutes=15)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Chain execution completed in 3.45s",
            f"[{(datetime.now() - timedelta(minutes=10)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Processing prompt request with 'llama2'",
        ]
    },
    "resource-watcher": {
        "resources": {
            "metrics": [
                {
                    "component": "ollama",
                    "resources": {
                        "cpu_usage": random.uniform(10, 35),
                        "memory_usage": random.uniform(500, 1500),
                        "memory_usage_percent": random.uniform(20, 60),
                        "disk_usage": random.uniform(5000, 10000),
                        "network_in": random.uniform(5, 20),
                        "network_out": random.uniform(3, 15)
                    },
                    "status": "healthy",
                    "last_updated": datetime.now().isoformat()
                },
                {
                    "component": "langchain",
                    "resources": {
                        "cpu_usage": random.uniform(5, 25),
                        "memory_usage": random.uniform(300, 800),
                        "memory_usage_percent": random.uniform(15, 40),
                        "disk_usage": random.uniform(1000, 2000),
                        "network_in": random.uniform(2, 10),
                        "network_out": random.uniform(1, 8)
                    },
                    "status": "healthy",
                    "last_updated": datetime.now().isoformat()
                }
            ],
            "models": [
                {
                    "name": "llama2",
                    "provider": "ollama",
                    "requests_count": random.randint(100, 300),
                    "tokens_input": random.randint(10000, 20000),
                    "tokens_output": random.randint(20000, 40000),
                    "avg_latency_ms": random.uniform(150, 300),
                    "last_used": (datetime.now() - timedelta(minutes=5)).isoformat()
                },
                {
                    "name": "mistral",
                    "provider": "ollama",
                    "requests_count": random.randint(50, 150),
                    "tokens_input": random.randint(5000, 10000),
                    "tokens_output": random.randint(10000, 20000),
                    "avg_latency_ms": random.uniform(100, 250),
                    "last_used": (datetime.now() - timedelta(minutes=15)).isoformat()
                }
            ],
            "alerts": [
                {
                    "component": "ollama",
                    "alert_type": "high_memory_usage",
                    "value": random.uniform(75, 90),
                    "threshold": 80.0,
                    "timestamp": (datetime.now() - timedelta(minutes=25)).isoformat(),
                    "severity": "warning"
                }
            ]
        },
        "logs": [
            f"[{(datetime.now() - timedelta(minutes=i)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Resource Watcher operational" for i in range(100, 0, -1)
        ] + [
            f"[{(datetime.now() - timedelta(minutes=30)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Collecting metrics from Ollama",
            f"[{(datetime.now() - timedelta(minutes=25)).strftime('%Y-%m-%d %H:%M:%S')}] [WARN] Ollama memory usage above threshold (83.5%)",
            f"[{(datetime.now() - timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Collecting metrics from LangChain",
            f"[{(datetime.now() - timedelta(minutes=15)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] LangChain response time normal (120ms)",
            f"[{(datetime.now() - timedelta(minutes=10)).strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Updating model usage statistics",
        ]
    }
}

# Create resource usage simulation for charts
def generate_time_series(length=24, min_val=0, max_val=100, trend="stable"):
    values = []
    current = random.uniform(min_val + (max_val - min_val) * 0.3, 
                            max_val - (max_val - min_val) * 0.3)
    
    for i in range(length):
        if trend == "increasing":
            # Trending upward
            current += random.uniform(-1, 3)
        elif trend == "decreasing":
            # Trending downward
            current += random.uniform(-3, 1)
        elif trend == "spike":
            # Normal with occasional spike
            if i == int(length * 0.7):
                current = max_val * 0.9
            else:
                current += random.uniform(-2, 2)
        else:
            # Stable with fluctuations
            current += random.uniform(-2, 2)
            
        # Keep within bounds
        current = max(min_val, min(current, max_val))
        values.append(current)
    
    return values

def generate_metric_timeseries():
    now = datetime.now()
    timestamps = [(now - timedelta(hours=i)).isoformat() for i in range(24, 0, -1)]
    
    return {
        "ollama": {
            "cpu_usage": {
                "name": "cpu_usage",
                "timestamps": timestamps,
                "values": generate_time_series(24, 5, 100, "spike"),
                "unit": "%"
            },
            "memory_usage": {
                "name": "memory_usage",
                "timestamps": timestamps,
                "values": generate_time_series(24, 400, 2000, "increasing"),
                "unit": "MB"
            }
        },
        "langchain": {
            "cpu_usage": {
                "name": "cpu_usage",
                "timestamps": timestamps,
                "values": generate_time_series(24, 5, 50, "stable"),
                "unit": "%"
            },
            "memory_usage": {
                "name": "memory_usage",
                "timestamps": timestamps,
                "values": generate_time_series(24, 200, 1000, "stable"),
                "unit": "MB"
            },
            "response_time": {
                "name": "response_time",
                "timestamps": timestamps,
                "values": generate_time_series(24, 50, 500, "increasing"),
                "unit": "ms"
            }
        }
    }

# Periodically update mock data to simulate changes
def update_mock_data():
    while True:
        # Update timestamps
        for rec in component_data["agent-orchestrator"]["recommendations"]:
            # Make timestamps more recent
            dt = datetime.fromisoformat(rec["timestamp"])
            rec["timestamp"] = (dt + timedelta(minutes=5)).isoformat()
        
        # Update resource metrics with small variations
        if "resource-watcher" in component_data:
            for metric in component_data["resource-watcher"]["resources"]["metrics"]:
                metric["resources"]["cpu_usage"] = random.uniform(10, 35)
                metric["resources"]["memory_usage"] = random.uniform(500, 1500)
                metric["resources"]["memory_usage_percent"] = random.uniform(20, 60)
                metric["last_updated"] = datetime.now().isoformat()
                
            # Occasionally add a new alert
            if random.random() > 0.8:  # 20% chance
                alert_types = ["high_cpu_usage", "high_memory_usage", "disk_space_low"]
                components = ["ollama", "langchain"]
                new_alert = {
                    "component": random.choice(components),
                    "alert_type": random.choice(alert_types),
                    "value": random.uniform(80, 95),
                    "threshold": 80.0,
                    "timestamp": datetime.now().isoformat(),
                    "severity": "warning"
                }
                component_data["resource-watcher"]["resources"]["alerts"].append(new_alert)
                
                # Keep only the 5 most recent alerts
                if len(component_data["resource-watcher"]["resources"]["alerts"]) > 5:
                    component_data["resource-watcher"]["resources"]["alerts"] = component_data["resource-watcher"]["resources"]["alerts"][-5:]
        
        # Wait before next update
        time.sleep(10)

# Start the periodic update thread
update_thread = threading.Thread(target=update_mock_data)
update_thread.daemon = True
update_thread.start()

class MockHandler(http.server.BaseHTTPRequestHandler):
    def _set_headers(self, content_type="application/json"):
        self.send_response(200)
        self.send_header('Content-type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        
    def do_OPTIONS(self):
        self._set_headers()
        
    def send_json_response(self, data):
        self._set_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def extract_client_id(self):
        # Extract client_id from query params or request body
        if '?' in self.path:
            from urllib.parse import parse_qs, urlparse
            query = parse_qs(urlparse(self.path).query)
            return query.get('client_id', ['test'])[0]
        return 'test'
        
    def extract_component_from_path(self):
        # Extract component from path like /logs/{component}
        path_parts = self.path.strip('/').split('/')
        if len(path_parts) >= 2:
            return path_parts[1]
        return None
    
    def do_GET(self):
        client_id = self.extract_client_id()
        path = self.path.split('?')[0]  # Remove query parameters
        
        # Health endpoint for all components
        if path == '/health':
            response = {
                "status": "healthy",
                "version": "1.0.0-mock",
                "component": component,
                "timestamp": datetime.now().isoformat()
            }
            self.send_json_response(response)
            return
        
        # Component specific endpoints
        if component == "agent-orchestrator":
            if path == '/recommendations':
                response = {
                    "recommendations": component_data["agent-orchestrator"]["recommendations"]
                }
                self.send_json_response(response)
                return
                
            elif path.startswith('/logs/'):
                component_name = self.extract_component_from_path()
                if component_name:
                    # Filter logs by component
                    filtered_logs = [log for log in component_data["agent-orchestrator"]["logs"] 
                                    if component_name.upper() in log]
                    response = {
                        "logs": filtered_logs
                    }
                else:
                    response = {
                        "logs": component_data["agent-orchestrator"]["logs"]
                    }
                self.send_json_response(response)
                return
                
            elif path.startswith('/metrics/'):
                component_name = self.extract_component_from_path()
                metrics = generate_metric_timeseries()
                if component_name and component_name in metrics:
                    response = {
                        "metrics": list(metrics[component_name].values()),
                        "component": component_name
                    }
                else:
                    # Return all metrics
                    all_metrics = []
                    for comp, comp_metrics in metrics.items():
                        all_metrics.extend(list(comp_metrics.values()))
                    response = {
                        "metrics": all_metrics
                    }
                self.send_json_response(response)
                return
                
        elif component == "langchain":
            if path == '/models':
                response = {
                    "models": component_data["langchain"]["models"]
                }
                self.send_json_response(response)
                return
                
            elif path == '/logs':
                response = {
                    "logs": component_data["langchain"]["logs"]
                }
                self.send_json_response(response)
                return
                
        elif component == "resource-watcher":
            if path == '/metrics/components':
                response = {
                    "metrics": component_data["resource-watcher"]["resources"]["metrics"]
                }
                self.send_json_response(response)
                return
                
            elif path == '/metrics/models':
                response = {
                    "models": component_data["resource-watcher"]["resources"]["models"]
                }
                self.send_json_response(response)
                return
                
            elif path == '/alerts':
                response = {
                    "alerts": component_data["resource-watcher"]["resources"]["alerts"]
                }
                self.send_json_response(response)
                return
                
            elif path == '/logs':
                response = {
                    "logs": component_data["resource-watcher"]["logs"]
                }
                self.send_json_response(response)
                return
        
        # Default response for unmatched paths
        self._set_headers("text/plain")
        self.wfile.write(f"Mock {component} server running. Unhandled path: {path}".encode())
        
    def do_POST(self):
        self._set_headers()
        content_length = int(self.headers['Content-Length']) if 'Content-Length' in self.headers else 0
        post_data = "{}"
        
        if content_length > 0:
            post_data = self.rfile.read(content_length).decode('utf-8')
            
        try:
            request = json.loads(post_data)
        except:
            request = {}
            
        client_id = request.get('client_id', 'test')
        path = self.path.split('?')[0]  # Remove query parameters
        
        # Component specific endpoints
        if component == "agent-orchestrator":
            if path == '/actions':
                action = request.get('action', {})
                response = {
                    "success": True,
                    "message": f"Action '{action.get('action_type', 'unknown')}' on '{action.get('target', 'unknown')}' initiated",
                    "details": {
                        "status": "pending",
                        "timestamp": datetime.now().isoformat()
                    }
                }
                self.send_json_response(response)
                return
                
            elif path == '/prompt':
                prompt = request.get('prompt', '')
                model = request.get('model', 'default')
                
                # Generate mock response based on prompt
                if "hello" in prompt.lower() or "hi" in prompt.lower():
                    response_text = "Hello! I'm a mock AI assistant. I'm here to help you with anything you need."
                elif "weather" in prompt.lower():
                    response_text = "The weather is sunny and pleasant today with a high of 75°F."
                elif "recommendation" in prompt.lower() or "suggest" in prompt.lower():
                    response_text = "Based on your request, I recommend optimizing the LangChain configuration for better performance."
                else:
                    response_text = f"This is a mock response to your query: '{prompt}'. In a real environment, this would be processed by the LangChain service with the {model} model."
                
                response = {
                    "response": response_text,
                    "model": model,
                    "processing_time": random.uniform(0.2, 2.0)
                }
                self.send_json_response(response)
                return
                
        elif component == "langchain":
            if path == '/prompt':
                prompt = request.get('prompt', '')
                model = request.get('model', 'default')
                
                # Generate mock response based on prompt
                if "hello" in prompt.lower() or "hi" in prompt.lower():
                    response_text = "Hello! I'm a mock LangChain AI service. I'm here to help you with anything you need."
                elif "weather" in prompt.lower():
                    response_text = "The weather is sunny and pleasant today with a high of 75°F."
                elif "recommendation" in prompt.lower() or "suggest" in prompt.lower():
                    response_text = "Based on your request, I recommend optimizing the LangChain configuration for better performance."
                else:
                    response_text = f"This is a mock LangChain response to your query: '{prompt}'. In a real environment, this would be processed by the {model} model."
                
                response = {
                    "response": response_text,
                    "model": model,
                    "processing_time": random.uniform(0.2, 2.0)
                }
                self.send_json_response(response)
                return
                
        # Default response for unmatched paths
        response = {
            "status": "success",
            "message": f"Mock {component} server received POST to {path}",
            "received_data": request
        }
        self.send_json_response(response)

# Start the server
httpd = socketserver.TCPServer(("", port), MockHandler)
print(f"Starting mock {component} server on port {port}...")
httpd.serve_forever()
EOF

# Make the Python script executable
chmod +x $MOCK_DIR/mock_server.py

# Start the mock server in the background
cd $MOCK_DIR
nohup python3 mock_server.py $COMPONENT $PORT > mock_server.log 2>&1 &
SERVER_PID=$!

# Write the PID to a file for later cleanup
echo $SERVER_PID > $MOCK_DIR/server.pid

echo "Mock $COMPONENT server started on port $PORT (PID: $SERVER_PID)"
echo "Logs available at: $MOCK_DIR/mock_server.log"
