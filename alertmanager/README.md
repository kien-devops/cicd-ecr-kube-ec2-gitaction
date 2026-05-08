# Alertmanager and Scale Webhook

This folder contains Alertmanager config and the Python webhook that turns Prometheus alerts into scale actions.

## Files

| File | Purpose |
|---|---|
| `alertmanager.yml.tpl` | Template config. Uses `${SCALE_WEBHOOK_URL}`. |
| `alertmanager.yml` | Rendered config used by Alertmanager. |
| `render-config.sh` | Renders `alertmanager.yml` from the template and `.env`. |
| `scale_webhook.py` | HTTP webhook that receives Alertmanager payloads and runs scale scripts. |
| `.env.example` | Example config for rendering Alertmanager. |
| `scale-webhook.env` | Optional local runtime env for `scale_webhook.py`; do not commit secrets. |

## Alert Flow

```text
Prometheus alert
  -> Alertmanager
  -> POST /scale-ec2
  -> scale_webhook.py
  -> scale up: ansible-web/provision-ec2-and-run-ansible.sh
  -> scale down: remove-worker-and-reload.sh or terraform/remove-node.sh
```

## Render Alertmanager Config

```bash
cd alertmanager
cp .env.example .env
```

Edit `.env`:

```env
SCALE_WEBHOOK_URL="http://<webhook-host>:5001/scale-ec2"
```

Render:

```bash
bash render-config.sh
```

## Run the Scale Webhook

The webhook defaults to `127.0.0.1:5001`. Configure it with env vars or `scale-webhook.env`.

Useful variables:

| Variable | Default | Purpose |
|---|---|---|
| `SCALE_WEBHOOK_HOST` | `127.0.0.1` | Bind address. |
| `SCALE_WEBHOOK_PORT` | `5001` | Webhook port. |
| `SCALE_WEBHOOK_COOLDOWN_SECONDS` | `1800` | Cooldown between scale actions. |
| `SCALE_WEBHOOK_MIN_TERRAFORM_NODES` | `0` | Minimum worker count for scale down. |
| `SCALE_SSH_TARGET` | empty | If set, run scale commands on a remote host through SSH. |

Start it:

```bash
cd alertmanager
python3 scale_webhook.py
```

## Run Alertmanager

```bash
docker network create demo_network || true

docker run -d \
  --name alertmanager \
  --network demo_network \
  -p 9093:9093 \
  -v "$(pwd):/etc/alertmanager:ro" \
  prom/alertmanager:latest
```

Open:

```text
http://<server-ip>:9093
```

## Troubleshooting

Check webhook logs:

```bash
tail -f alertmanager/scale_webhook.log
```

Check Alertmanager config:

```bash
docker logs alertmanager
```
