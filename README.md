# Rundeck + Ansible Lab

A self-contained Docker lab that mirrors a real Linode-style git-pull deployment
workflow. Rundeck provides the operations UI; Ansible does the actual work.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Docker lab network                         │
│                                             │
│  [rundeck]      web UI at :4440             │
│  [ansible]      control node (SSH client)   │
│  [app-node-1]   "Linode" target :8001       │
│  [app-node-2]   "Linode" target :8002       │
└─────────────────────────────────────────────┘
```

Rundeck triggers an Ansible playbook → Ansible SSHes into app nodes →
git pull + venv install + service restart + health check.

## Quick Start

```bash
# 1. Start the lab
docker compose up -d

# Wait ~30 seconds for Rundeck to fully boot, then:

# 2. Wire SSH keys and start the apps
chmod +x scripts/setup.sh
./scripts/setup.sh

# 3. Verify the apps are up
curl http://localhost:8001/health
curl http://localhost:8002/health
```

## Run a Deploy via Ansible (CLI)

```bash
# Deploy to all nodes
docker exec ansible ansible-playbook /ansible/playbooks/deploy.yml

# Deploy to one node only
docker exec ansible ansible-playbook /ansible/playbooks/deploy.yml \
  --limit app-node-1

# Deploy a specific branch (when using a real repo)
docker exec ansible ansible-playbook /ansible/playbooks/deploy.yml \
  -e "app_branch=staging"

# Dry run (check mode — no changes made)
docker exec ansible ansible-playbook /ansible/playbooks/deploy.yml \
  --check
```

## Run a Deploy via Rundeck (UI)

1. Open http://localhost:4440
2. Login: `admin` / `admin`
3. Create a new **Project** named `lab`
4. Go to **Jobs → Import Job** and upload `rundeck/job-definitions/deploy-fastapi.yml`
5. Click **Run Job Now**
6. Watch the live log output

You can also schedule the job (cron) or parameterize the branch from the UI.

## Simulating a New Release

To simulate a code change and re-deploy:

```bash
# Edit the version string in the stub app
# (in a real project this would be a git push)
docker exec app-node-1 sed -i 's/VERSION = "1.0.0"/VERSION = "1.1.0"/' /srv/app/main.py

# Now run the deploy — it will bounce the process and you'll see the new version
docker exec ansible ansible-playbook /ansible/playbooks/deploy.yml --limit app-node-1

# Check the result
curl http://localhost:8001/
```

## Project Structure

```
rundeck-ansible-lab/
├── docker-compose.yml
├── Dockerfile.ansible          # Ansible control node image
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.ini           # Points to app-node-1, app-node-2
│   ├── playbooks/
│   │   └── deploy.yml          # Main deploy playbook
│   └── roles/
│       └── deploy-app/
│           ├── tasks/main.yml  # git pull, venv, restart, health check
│           └── handlers/main.yml
├── app-node/
│   ├── Dockerfile.node         # Debian + SSH + Python target image
│   ├── bootstrap-node.sh
│   └── app/
│       ├── main.py             # Stub FastAPI app
│       └── requirements.txt
├── rundeck/
│   └── job-definitions/
│       └── deploy-fastapi.yml  # Rundeck job (import via UI)
└── scripts/
    └── setup.sh                # One-time SSH wiring script
```

## Connecting to Your Real Linode Servers

When you're ready to graduate from the lab:

1. Edit `ansible/inventory/hosts.ini` — swap Docker hostnames for real IPs
2. Point `ansible_ssh_private_key_file` at your actual deploy key
3. Set `app_repo` to your real git repo URL
4. The playbook runs identically — that's the point

## Useful Commands

```bash
# SSH into a node manually
docker exec -it app-node-1 bash

# Watch app logs on a node
docker exec app-node-1 tail -f /tmp/app.log

# Ad-hoc Ansible commands
docker exec ansible ansible all -m command -a "uptime"
docker exec ansible ansible all -m shell -a "ps aux | grep uvicorn"

# Stop everything
docker compose down

# Nuke volumes and start fresh
docker compose down -v
```
