import os
import json
import subprocess
import glob
import time
from flask import Flask, jsonify, request

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENVS_DIR = os.path.join(BASE_DIR, "envs")
LOGS_DIR = os.path.join(BASE_DIR, "logs")
PLATFORM_DIR = os.path.join(BASE_DIR, "platform")

def load_env(env_id):
    path = os.path.join(ENVS_DIR, f"{env_id}.json")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)

def list_envs():
    envs = []
    for path in glob.glob(os.path.join(ENVS_DIR, "*.json")):
        try:
            with open(path) as f:
                envs.append(json.load(f))
        except Exception:
            pass
    return envs

@app.route("/envs", methods=["POST"])
def create_env():
    data = request.get_json() or {}
    name = data.get("name", "myenv")
    ttl = data.get("ttl", 1800)
    result = subprocess.run(
        ["bash", os.path.join(PLATFORM_DIR, "create_env.sh"), name, str(ttl)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    output = result.stdout
    env_id = None
    for line in output.splitlines():
        if "ENV_ID" in line:
            env_id = line.split(":")[1].strip()
            break
    return jsonify({"message": "Environment created", "env_id": env_id, "output": output}), 201

@app.route("/envs", methods=["GET"])
def get_envs():
    envs = list_envs()
    result = []
    now = time.time()
    for e in envs:
        ttl_remaining = max(0, e["created_at"] + e["ttl"] - now)
        result.append({**e, "ttl_remaining": round(ttl_remaining)})
    return jsonify(result)

@app.route("/envs/<env_id>", methods=["DELETE"])
def delete_env(env_id):
    env = load_env(env_id)
    if not env:
        return jsonify({"error": "Not found"}), 404
    result = subprocess.run(
        ["bash", os.path.join(PLATFORM_DIR, "destroy_env.sh"), env_id],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": f"Environment {env_id} destroyed"})

@app.route("/envs/<env_id>/logs", methods=["GET"])
def get_logs(env_id):
    log_file = os.path.join(LOGS_DIR, env_id, "app.log")
    if not os.path.exists(log_file):
        return jsonify({"error": "Logs not found"}), 404
    with open(log_file) as f:
        lines = f.readlines()[-100:]
    return jsonify({"env_id": env_id, "logs": lines})

@app.route("/envs/<env_id>/health", methods=["GET"])
def get_health(env_id):
    log_file = os.path.join(LOGS_DIR, env_id, "health.log")
    if not os.path.exists(log_file):
        return jsonify({"error": "Health log not found"}), 404
    with open(log_file) as f:
        lines = f.readlines()[-10:]
    return jsonify({"env_id": env_id, "health": lines})

@app.route("/envs/<env_id>/outage", methods=["POST"])
def simulate_outage(env_id):
    data = request.get_json() or {}
    mode = data.get("mode", "crash")
    env = load_env(env_id)
    if not env:
        return jsonify({"error": "Not found"}), 404
    result = subprocess.run(
        ["bash", os.path.join(PLATFORM_DIR, "simulate_outage.sh"),
         "--env", env_id, "--mode", mode],
        capture_output=True, text=True
    )
    return jsonify({"message": f"Outage simulated: {mode}", "output": result.stdout})

if __name__ == "__main__":
    os.makedirs(ENVS_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=8000, debug=False)
