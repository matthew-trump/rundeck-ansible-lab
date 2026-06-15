#!/bin/bash
# setup.sh — Run this ONCE after `docker compose up -d` to wire SSH between
# the Ansible control node and the app nodes.
set -e

echo "══════════════════════════════════════════════"
echo "  Rundeck/Ansible Lab — Initial SSH Setup"
echo "══════════════════════════════════════════════"

# 1. Generate an SSH keypair inside the ansible container
echo ""
echo "→ Generating SSH keypair in ansible container..."
docker exec ansible bash -c "
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    if [ ! -f /root/.ssh/lab_key ]; then
        ssh-keygen -t ed25519 -f /root/.ssh/lab_key -N '' -C 'ansible-lab'
        echo 'Keypair created.'
    else
        echo 'Keypair already exists, skipping.'
    fi
    chmod 600 /root/.ssh/lab_key
    chmod 644 /root/.ssh/lab_key.pub
"

# 2. Grab the public key
PUBKEY=$(docker exec ansible cat /root/.ssh/lab_key.pub)
echo ""
echo "→ Public key: $PUBKEY"

# 3. Copy app stub files into nodes and inject the public key
for NODE in app-node-1 app-node-2; do
    echo ""
    echo "→ Configuring $NODE..."

    # Inject app files
    docker cp app-node/app/main.py ${NODE}:/srv/app/main.py
    docker exec ${NODE} chown deploy:deploy /srv/app/main.py

    # Inject authorized_keys
    docker exec ${NODE} bash -c "
        mkdir -p /home/deploy/.ssh
        echo '${PUBKEY}' > /home/deploy/.ssh/authorized_keys
        chown -R deploy:deploy /home/deploy/.ssh
        chmod 700 /home/deploy/.ssh
        chmod 600 /home/deploy/.ssh/authorized_keys
    "

    # Install FastAPI if not already present
    docker exec --user deploy ${NODE} bash -c "
        cd /srv/app
        if [ ! -d venv ]; then
            python3 -m venv venv
            ./venv/bin/pip install --quiet fastapi uvicorn
        fi
    "

    # Start the app (background)
    docker exec --user deploy ${NODE} bash -c "
        cd /srv/app
        pkill -f uvicorn || true
        sleep 1
        nohup ./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
          >> /tmp/app.log 2>&1 &
        echo 'App started on port 8000'
    "

    echo "  ✓ $NODE ready"
done

# 4. Test Ansible connectivity
echo ""
echo "→ Testing Ansible ping to all nodes..."
docker exec ansible ansible all -i /ansible/inventory/hosts.ini -m ping

echo ""
echo "══════════════════════════════════════════════"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Open Rundeck:  http://localhost:4440"
echo "     Login:         admin / admin"
echo ""
echo "  2. Create a project named 'lab' in Rundeck"
echo "  3. Import the job:  rundeck/job-definitions/deploy-fastapi.yml"
echo ""
echo "  3. Or run Ansible directly:"
echo "     docker exec ansible ansible-playbook \\"
echo "       /ansible/playbooks/deploy.yml"
echo ""
echo "  App nodes:"
echo "     http://localhost:8001/health  (app-node-1)"
echo "     http://localhost:8002/health  (app-node-2)"
echo "══════════════════════════════════════════════"
