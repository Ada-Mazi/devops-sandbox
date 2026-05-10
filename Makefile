.PHONY: up down create destroy logs health simulate clean

up:
	@echo "Starting DevOps Sandbox Platform..."
	@docker network create sandbox-platform 2>/dev/null || true
	@docker run -d --name sandbox-nginx \
		--network sandbox-platform \
		-p 80:80 \
		-v $(PWD)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
		-v $(PWD)/nginx/conf.d:/etc/nginx/conf.d \
		nginx:alpine 2>/dev/null || echo "Nginx already running"
	@nohup bash platform/cleanup_daemon.sh > logs/cleanup.log 2>&1 &
	@echo $$! > logs/daemon.pid
	@nohup bash monitor/health_poller.sh > logs/health_poller.log 2>&1 &
	@echo $$! > logs/poller.pid
	@nohup python3 platform/api.py > logs/api.log 2>&1 &
	@echo $$! > logs/api.pid
	@echo "Platform started!"
	@echo "  Nginx  : http://34.46.53.225"
	@echo "  API    : http://34.46.53.225:8000"

down:
	@echo "Stopping platform..."
	@for f in envs/*.json; do \
		[ -f "$$f" ] || continue; \
		ENV_ID=$$(python3 -c "import json; print(json.load(open('$$f'))['id'])" 2>/dev/null); \
		[ -n "$$ENV_ID" ] && bash platform/destroy_env.sh "$$ENV_ID" 2>/dev/null || true; \
	done
	@docker stop sandbox-nginx 2>/dev/null || true
	@docker rm sandbox-nginx 2>/dev/null || true
	@[ -f logs/daemon.pid ] && kill $$(cat logs/daemon.pid) 2>/dev/null || true
	@[ -f logs/poller.pid ] && kill $$(cat logs/poller.pid) 2>/dev/null || true
	@[ -f logs/api.pid ] && kill $$(cat logs/api.pid) 2>/dev/null || true
	@docker network rm sandbox-platform 2>/dev/null || true
	@echo "Platform stopped."

create:
	@read -p "Environment name: " name; \
	read -p "TTL in seconds (default 1800): " ttl; \
	ttl=$${ttl:-1800}; \
	bash platform/create_env.sh "$$name" "$$ttl"

destroy:
	@bash platform/destroy_env.sh $(ENV)

logs:
	@tail -f logs/$(ENV)/app.log

health:
	@echo "=== Environment Health Status ==="
	@for f in envs/*.json; do \
		[ -f "$$f" ] || continue; \
		python3 -c "import json; d=json.load(open('$$f')); print(f\"  {d['id']} | {d['name']} | status={d['status']} | port={d['port']}\")"; \
	done

simulate:
	@bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	@echo "Cleaning all state..."
	@rm -rf envs/*.json logs/env-* logs/cleanup.log logs/api.log
	@rm -f nginx/conf.d/env-*.conf
	@echo "Clean complete."
