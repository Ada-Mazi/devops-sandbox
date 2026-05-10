# DevOps Sandbox Platform

A self-service platform for spinning up isolated temporary environments with automatic cleanup, health monitoring, and chaos engineering.

## Architecture

    Internet
        |
    [Nginx :7080]  <-- dynamic per-env routing
        |
    [sandbox-platform network]
        |
    [env-abc123]  [env-def456]  ... (isolated containers)
        |
    [Health Poller] --> logs/ENV_ID/health.log
    [Cleanup Daemon] --> auto-destroy on TTL expiry
    [API :8000] --> REST control plane

## Prerequisites

- Docker
- Python 3.10+
- pip: flask requests

## Quick Start (5 commands)

    git clone https://github.com/Ada-Mazi/devops-sandbox
    cd devops-sandbox
    pip3 install flask requests
    docker build -t sandbox-app:latest app/
    make up

## Create your first environment

    make create
    # or via API:
    curl -X POST http://localhost:8000/envs -H "Content-Type: application/json" -d '{"name":"myapp","ttl":300}'

## Full Demo Walkthrough

    # 1. Start platform
    make up

    # 2. Create environment
    make create

    # 3. Check health
    make health

    # 4. Simulate outage
    make simulate ENV=env-abc123 MODE=crash

    # 5. Observe degraded status
    make health

    # 6. Recover
    make simulate ENV=env-abc123 MODE=recover

    # 7. Auto-destroy happens when TTL expires

    # 8. Destroy manually
    make destroy ENV=env-abc123

## API Reference

    POST   /envs              - create environment
    GET    /envs              - list all environments
    DELETE /envs/:id          - destroy environment
    GET    /envs/:id/logs     - last 100 lines of app.log
    GET    /envs/:id/health   - last 10 health check results
    POST   /envs/:id/outage   - simulate outage

## Known Limitations

- Single VM only - no multi-host support
- No persistent storage for app containers
- Stress mode requires stress-ng installed in container

## Quick Local Test
```bash
# Clone and run (from any machine)
git clone https://github.com/Ada-Mazi/devops-sandbox
cd devops-sandbox
pip3 install flask requests
docker build -t sandbox-app:latest app/
make up
bash platform/create_env.sh test 300
make health
make simulate ENV=env-xxx MODE=crash
sleep 35
make health
make down

## Quick Local Test
```bash
# Clone and run (from any machine)
git clone https://github.com/Ada-Mazi/devops-sandbox
cd devops-sandbox
pip3 install flask requests
docker build -t sandbox-app:latest app/
make up
bash platform/create_env.sh test 300
make health
make simulate ENV=env-xxx MODE=crash
sleep 35
make health
make down
