import os
import time
from flask import Flask, jsonify

app = Flask(__name__)
START = time.time()
ENV_ID = os.environ.get("ENV_ID", "unknown")
ENV_NAME = os.environ.get("ENV_NAME", "unknown")

@app.route("/")
def index():
    return jsonify({"message": f"Hello from {ENV_NAME}", "env_id": ENV_ID})

@app.route("/health")
def health():
    return jsonify({"status": "ok", "uptime": round(time.time() - START, 2), "env_id": ENV_ID})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
