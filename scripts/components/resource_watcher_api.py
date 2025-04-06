# API Endpoints for Resource Watcher

# Health check endpoint for liveness/readiness probes
@app.get("/healthz")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

# Detailed status endpoint
@app.get("/status")
async def get_status():
    # Get basic system info
    system_info = get_system_info()
    
    # Get current metrics
    cpu_metrics = get_cpu_metrics()
    memory_metrics = get_memory_metrics()
    
    # Check dependency statuses
    llm_status = "not_enabled"
    if settings.llm_enabled:
        if settings.use_ollama:
            llm_status = check_ollama_status()
        else:
            llm_status = check_langchain_status()
            
    prometheus_status = "not_enabled"
    if settings.prometheus_enabled:
        prometheus_status = check_prometheus_status()
    
    # Count alerts in last hour
    now = datetime.now()
    one_hour_ago = now - timedelta(hours=1)
    one_hour_ago_str = one_hour_ago.isoformat()
    
    recent_alerts = [a for a in alerts_history if a.timestamp > one_hour_ago_str]
    
    # Count metrics by resource type and severity
    alert_counts = {
        "total": len(recent_alerts),
        "by_level": {},
        "by_resource": {}
    }
    
    for alert in recent_alerts:
        # Count by level
        if alert.level not in alert_counts["by_level"]:
            alert_counts["by_level"][alert.level] = 0
        alert_counts["by_level"][alert.level] += 1
        
        # Count by resource type
        if alert.resource_type not in alert_counts["by_resource"]:
            alert_counts["by_resource"][alert.resource_type] = 0
        alert_counts["by_resource"][alert.resource_type] += 1
    
    return {
        "system": system_info.dict(),
        "current": {
            "cpu_usage": cpu_metrics.usage_percent,
            "memory_usage": memory_metrics.used_percent,
            "load_avg": cpu_metrics.load_avg_5min
        },
        "metrics_collection": {
            "is_active": is_collecting,
            "interval_seconds": settings.collection_interval,
            "metrics_count": len(metrics_history),
            "retention_minutes": settings.retention_period
        },
        "alerts": alert_counts,
        "dependencies": {
            "llm": llm_status,
            "prometheus": prometheus_status,
            "docker": settings.docker_enabled
        },
        "timestamp": datetime.now().isoformat()
    }

# Get current metrics
@app.get("/metrics")
async def get_metrics():
    # Get latest metrics if available
    if not metrics_history:
        # No metrics yet, collect them now
        system_info = get_system_info()
        cpu_metrics = get_cpu_metrics()
        memory_metrics = get_memory_metrics()
        disk_metrics = get_disk_metrics()
        network_metrics = get_network_metrics()
        docker_metrics = get_docker_metrics() if settings.docker_enabled else None
        
        metrics = ResourceMetrics(
            timestamp=datetime.now().isoformat(),
            system=system_info,
            cpu=cpu_metrics,
            memory=memory_metrics,
            disks=disk_metrics,
            network=network_metrics,
            docker=docker_metrics
        )
    else:
        # Use the latest metrics from history
        metrics = metrics_history[-1]
    
    return metrics.dict()

# Get metrics in Prometheus format
@app.get("/metrics/prometheus")
async def get_prometheus_metrics():
    if not metrics_history:
        return ""
    
    metrics = metrics_history[-1]
    
    # Format metrics in Prometheus text format
    prometheus_lines = []
    
    # CPU metrics
    prometheus_lines.append(f"# HELP cpu_usage_percent CPU usage percentage")
    prometheus_lines.append(f"# TYPE cpu_usage_percent gauge")
    prometheus_lines.append(f"cpu_usage_percent{{client_id=\"{settings.client_id}\"}} {metrics.cpu.usage_percent}")
    
    prometheus_lines.append(f"# HELP cpu_load_avg_1min System load average (1 minute)")
    prometheus_lines.append(f"# TYPE cpu_load_avg_1min gauge")
    prometheus_lines.append(f"cpu_load_avg_1min{{client_id=\"{settings.client_id}\"}} {metrics.cpu.load_avg_1min}")
    
    prometheus_lines.append(f"# HELP cpu_load_avg_5min System load average (5 minutes)")
    prometheus_lines.append(f"# TYPE cpu_load_avg_5min gauge")
    prometheus_lines.append(f"cpu_load_avg_5min{{client_id=\"{settings.client_id}\"}} {metrics.cpu.load_avg_5min}")
    
    # Memory metrics
    prometheus_lines.append(f"# HELP memory_used_percent Memory usage percentage")
    prometheus_lines.append(f"# TYPE memory_used_percent gauge")
    prometheus_lines.append(f"memory_used_percent{{client_id=\"{settings.client_id}\"}} {metrics.memory.used_percent}")
    
    prometheus_lines.append(f"# HELP memory_available_gb Available memory in GB")
    prometheus_lines.append(f"# TYPE memory_available_gb gauge")
    prometheus_lines.append(f"memory_available_gb{{client_id=\"{settings.client_id}\"}} {metrics.memory.available_gb}")
    
    # Disk metrics
    for disk in metrics.disks:
        prometheus_lines.append(f"# HELP disk_used_percent Disk usage percentage")
        prometheus_lines.append(f"# TYPE disk_used_percent gauge")
        prometheus_lines.append(f"disk_used_percent{{client_id=\"{settings.client_id}\",device=\"{disk.device}\",mountpoint=\"{disk.mountpoint}\"}} {disk.used_percent}")
        
        prometheus_lines.append(f"# HELP disk_free_gb Free disk space in GB")
        prometheus_lines.append(f"# TYPE disk_free_gb gauge")
        prometheus_lines.append(f"disk_free_gb{{client_id=\"{settings.client_id}\",device=\"{disk.device}\",mountpoint=\"{disk.mountpoint}\"}} {disk.free_gb}")
    
    # Network metrics
    for network in metrics.network:
        prometheus_lines.append(f"# HELP network_bytes_sent Network bytes sent")
        prometheus_lines.append(f"# TYPE network_bytes_sent counter")
        prometheus_lines.append(f"network_bytes_sent{{client_id=\"{settings.client_id}\",interface=\"{network.interface}\"}} {network.bytes_sent}")
        
        prometheus_lines.append(f"# HELP network_bytes_recv Network bytes received")
        prometheus_lines.append(f"# TYPE network_bytes_recv counter")
        prometheus_lines.append(f"network_bytes_recv{{client_id=\"{settings.client_id}\",interface=\"{network.interface}\"}} {network.bytes_recv}")
    
    # Docker metrics
    if metrics.docker:
        for container in metrics.docker:
            prometheus_lines.append(f"# HELP docker_cpu_percent Docker container CPU usage percentage")
            prometheus_lines.append(f"# TYPE docker_cpu_percent gauge")
            prometheus_lines.append(f"docker_cpu_percent{{client_id=\"{settings.client_id}\",container=\"{container.name}\",image=\"{container.image}\"}} {container.cpu_percent}")
            
            prometheus_lines.append(f"# HELP docker_memory_percent Docker container memory usage percentage")
            prometheus_lines.append(f"# TYPE docker_memory_percent gauge")
            prometheus_lines.append(f"docker_memory_percent{{client_id=\"{settings.client_id}\",container=\"{container.name}\",image=\"{container.image}\"}} {container.memory_percent}")
    
    return "\n".join(prometheus_lines)

# Get resource usage summary with optional LLM-enhanced insights
@app.get("/summary")
async def get_summary(
    time_range: str = "1h",  # 1h, 6h, 24h, 7d
    include_insights: bool = False
):
    # Parse time range
    now = datetime.now()
    start_time = now
    
    if time_range.endswith('m'):
        minutes = int(time_range[:-1])
        start_time = now - timedelta(minutes=minutes)
    elif time_range.endswith('h'):
        hours = int(time_range[:-1])
        start_time = now - timedelta(hours=hours)
    elif time_range.endswith('d'):
        days = int(time_range[:-1])
        start_time = now - timedelta(days=days)
    else:
        raise HTTPException(status_code=400, detail="Invalid time range format. Use Xm, Xh, or Xd.")
    
    start_time_str = start_time.isoformat()
    
    # Filter metrics based on time range
    filtered_metrics = []
    for metric in metrics_history:
        metric_time = datetime.fromisoformat(metric.timestamp.replace('Z', '+00:00'))
        if metric_time >= start_time:
            filtered_metrics.append(metric)
    
    if not filtered_metrics:
        raise HTTPException(status_code=404, detail="No metrics found for the specified time range.")
    
    # Get system info from the latest metrics
    system = filtered_metrics[-1].system
    
    # Calculate CPU stats
    cpu_values = [m.cpu.usage_percent for m in filtered_metrics]
    cpu_avg = sum(cpu_values) / len(cpu_values) if cpu_values else 0
    cpu_max = max(cpu_values) if cpu_values else 0
    
    # Calculate memory stats
    memory_values = [m.memory.used_percent for m in filtered_metrics]
    memory_avg = sum(memory_values) / len(memory_values) if memory_values else 0
    memory_max = max(memory_values) if memory_values else 0
    
    # Calculate disk usage averages
    disk_usage_avg = {}
    for metric in filtered_metrics:
        for disk in metric.disks:
            if disk.mountpoint not in disk_usage_avg:
                disk_usage_avg[disk.mountpoint] = []
            disk_usage_avg[disk.mountpoint].append(disk.used_percent)
    
    for mountpoint, values in disk_usage_avg.items():
        disk_usage_avg[mountpoint] = sum(values) / len(values) if values else 0
    
    # Calculate network traffic (in MB)
    network_traffic_mb = {}
    if len(filtered_metrics) >= 2:
        first_metric = filtered_metrics[0]
        last_metric = filtered_metrics[-1]
        
        for interface in [n.interface for n in last_metric.network]:
            network_traffic_mb[interface] = {"sent": 0, "received": 0}
            
            # Find first and last metrics for this interface
            first_net = next((n for n in first_metric.network if n.interface == interface), None)
            last_net = next((n for n in last_metric.network if n.interface == interface), None)
            
            if first_net and last_net:
                bytes_sent_diff = max(0, last_net.bytes_sent - first_net.bytes_sent)
                bytes_recv_diff = max(0, last_net.bytes_recv - first_net.bytes_recv)
                
                network_traffic_mb[interface]["sent"] = bytes_sent_diff / (1024**2)
                network_traffic_mb[interface]["received"] = bytes_recv_diff / (1024**2)
    
    # Get alerts for the time range
    filtered_alerts = []
    for alert in alerts_history:
        alert_time = datetime.fromisoformat(alert.timestamp.replace('Z', '+00:00'))
        if alert_time >= start_time:
            filtered_alerts.append(alert)
    
    # Create the summary
    summary = ResourceSummary(
        start_time=start_time_str,
        end_time=now.isoformat(),
        system=system,
        cpu_avg=cpu_avg,
        cpu_max=cpu_max,
        memory_avg=memory_avg,
        memory_max=memory_max,
        disk_usage_avg=disk_usage_avg,
        network_traffic_mb=network_traffic_mb,
        alerts=filtered_alerts,
        anomalies=None,
        recommendations=None
    )
    
    # Add LLM-enhanced insights if requested and available
    if include_insights and settings.llm_enabled:
        try:
            insights = await get_llm_insights(summary)
            if insights:
                summary.anomalies = insights.get("anomalies", [])
                summary.recommendations = insights.get("recommendations", [])
        except Exception as e:
            logger.error(f"Error getting LLM insights: {e}")
    
    return summary.dict()

# Function to get LLM insights using LangChain or Ollama
async def get_llm_insights(summary: ResourceSummary):
    if not settings.llm_enabled:
        return None
    
    try:
        # Prepare the input context
        context = {
            "system": summary.system.dict(),
            "stats": {
                "time_range": f"{summary.start_time} to {summary.end_time}",
                "cpu": {
                    "avg": summary.cpu_avg,
                    "max": summary.cpu_max
                },
                "memory": {
                    "avg": summary.memory_avg,
                    "max": summary.memory_max
                },
                "disk": summary.disk_usage_avg,
                "network": summary.network_traffic_mb,
                "alerts": [a.dict() for a in summary.alerts]
            }
        }
        
        # Use LangChain if available
        if not settings.use_ollama:
            try:
                payload = {
                    "input": {
                        "context": context
                    },
                    "chain_type": "resource_watcher_insights"
                }
                
                response = await httpx.AsyncClient().post(
                    f"{settings.langchain_url}/chains/resource_watcher_insights/run",
                    json=payload
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(f"Error from LangChain: {response.text}")
                    return None
                    
            except Exception as e:
                logger.error(f"Error calling LangChain: {e}")
                return None
                
        # Use Ollama directly
        else:
            try:
                # Create a prompt for Ollama
                prompt = f"""
                You are ResourceWatcher, an AI system analyst for AgencyStack.
                
                Please analyze the following system metrics and provide insights:
                
                System: 
                - Hostname: {summary.system.hostname}
                - Platform: {summary.system.platform} {summary.system.platform_version}
                - Client ID: {summary.system.client_id}
                
                Time Range: {summary.start_time} to {summary.end_time}
                
                Performance Metrics:
                - CPU Average: {summary.cpu_avg:.1f}%, Maximum: {summary.cpu_max:.1f}%
                - Memory Average: {summary.memory_avg:.1f}%, Maximum: {summary.memory_max:.1f}%
                - Disk Usage: {', '.join([f"{mount}: {usage:.1f}%" for mount, usage in summary.disk_usage_avg.items()])}
                
                Alerts: {len(summary.alerts)} alerts detected
                {chr(10).join([f"- {a.level.upper()}: {a.message}" for a in summary.alerts[:5]])}
                {f"...and {len(summary.alerts) - 5} more alerts" if len(summary.alerts) > 5 else ""}
                
                Based on this data, please identify:
                1. Any anomalies or concerning patterns
                2. Actionable recommendations to improve system health
                
                Format your response as JSON with the following structure:
                {{
                  "anomalies": [
                    {{"title": "Anomaly title", "description": "Detailed description", "severity": "low|medium|high"}}
                  ],
                  "recommendations": [
                    {{"title": "Recommendation title", "description": "Detailed description", "action": "Specific action to take"}}
                  ]
                }}
                """
                
                # Call Ollama
                response = await httpx.AsyncClient().post(
                    f"{settings.ollama_url}/api/generate",
                    json={"model": "llama2", "prompt": prompt, "stream": False}
                )
                
                if response.status_code == 200:
                    # Extract JSON from the response
                    result = response.json()
                    response_text = result.get("response", "")
                    
                    # Try to extract JSON from the response
                    json_start = response_text.find("{")
                    json_end = response_text.rfind("}") + 1
                    
                    if json_start >= 0 and json_end > json_start:
                        json_str = response_text[json_start:json_end]
                        try:
                            return json.loads(json_str)
                        except json.JSONDecodeError:
                            logger.error("Error parsing JSON from Ollama response")
                    
                    return {
                        "anomalies": [],
                        "recommendations": []
                    }
                else:
                    logger.error(f"Error from Ollama: {response.text}")
                    return None
                    
            except Exception as e:
                logger.error(f"Error calling Ollama: {e}")
                return None
    except Exception as e:
        logger.error(f"Error in get_llm_insights: {e}")
        return None

# Run the application
if __name__ == "__main__":
    import asyncio
    import uvicorn
    
    port = int(os.getenv("PORT", "5211"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
