# Alertmanager

Run Alertmanager with the configuration from this folder.

Copy `.env.example` to `.env` and set the real scale webhook URL before rendering `alertmanager.yml`:

```bash
cp alertmanager/.env.example alertmanager/.env
bash alertmanager/render-config.sh
```

## Model

```mermaid
flowchart LR
    PROM[Prometheus<br/>:9090] -->|send alerts| ALERT[Alertmanager<br/>:9093]
    ALERT -->|HighAverageNodeCpuUsage| WEBHOOK[Scale Webhook<br/>:5001]
    ALERT -->|LowAverageNodeCpuUsage| WEBHOOK
    WEBHOOK -->|scale out| ADD[terraform/add-node.sh]
    WEBHOOK -->|scale in| REMOVE[terraform/remove-node.sh]
```

The same webhook handles scale-out and scale-in:

- `HighAverageNodeCpuUsage` with `action=scale-ec2` adds one EC2 worker.
- `LowAverageNodeCpuUsage` with `action=scale-down-ec2` removes one Terraform-managed worker.

Set `SCALE_WEBHOOK_MIN_TERRAFORM_NODES` in `scale-webhook.env` to keep a minimum number of Terraform nodes. The default is `1`, so scale-in will not remove the last `nodeN` entry from `terraform.tfvars`.

## Run With Docker

Create the Docker network if it does not already exist:

```bash
docker network create demo_network
```

Run Alertmanager:

```bash
docker run -d \
  --name alertmanager \
  --network demo_network \
  -p 9093:9093 \
  -v "<path-to-repo>/alertmanager:/etc/alertmanager:ro" \
  prom/alertmanager:latest
```

Replace `<path-to-repo>` with the absolute path to this repository on the server.

Open Alertmanager:

```text
http://<server-ip>:9093
```
