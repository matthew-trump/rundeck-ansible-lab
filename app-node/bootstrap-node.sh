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
    cp /tmp/app-init/* /srv/app/ 2>/dev/null || true
    git config --local user.email "deploy@lab" || true
    git config --local user.name "Deploy" || true
    chown -R deploy:deploy /srv/app
fi

chown -R deploy:deploy /srv/app
echo "[bootstrap] Node ready; setup.sh will install and start the app."
tail -f /dev/null
