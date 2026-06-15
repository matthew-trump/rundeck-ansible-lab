#!/bin/bash
set -e

# Wait for authorized_keys to be injected by the setup script
echo "[bootstrap] Waiting for SSH authorized_keys..."
for i in $(seq 1 30); do
    if [ -f /home/deploy/.ssh/authorized_keys ]; then
        echo "[bootstrap] authorized_keys found."
        break
    fi
    sleep 1
done

# Start SSH daemon
echo "[bootstrap] Starting sshd..."
/usr/sbin/sshd

# Initialize the app directory as a git repo if not already done
if [ ! -d /srv/app/.git ]; then
    echo "[bootstrap] Initializing app repo..."
    cd /srv/app
    git init
    git config user.email "deploy@lab"
    git config user.name "Deploy"
    cp /tmp/app-init/* /srv/app/ 2>/dev/null || true
fi

# Create venv and install dependencies if not present
if [ ! -d /srv/app/venv ]; then
    echo "[bootstrap] Creating virtualenv..."
    cd /srv/app
    python3 -m venv venv
    ./venv/bin/pip install --quiet fastapi uvicorn
fi

# Start the FastAPI app
echo "[bootstrap] Starting FastAPI app..."
cd /srv/app
exec ./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
