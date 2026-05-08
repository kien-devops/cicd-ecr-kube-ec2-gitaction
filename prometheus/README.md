# Prometheus Monitoring

This folder contains Prometheus configuration and alert rules for EC2 worker monitoring and autoscaling signals.

## Files

| File | Purpose |
|---|---|
| `prometheus.yml` | Prometheus scrape and alertmanager configuration. |
| `alert_rules.yml` | CPU based scale-up and scale-down alert rules. |

## Scrape Jobs

| Job | Purpose |
|---|---|
| `node-exporter-monitor-host` | Static scrape for the monitoring host on `54.163.216.25:9100`. |
| `node-exporter-ec2-workers` | AWS EC2 service discovery for worker nodes tagged `Monitoring=enabled`. |

The EC2 worker job uses AWS EC2 metadata labels and scrapes node exporter on port `9100`.

## Alerts

| Alert | Condition | Duration | Action label |
|---|---|---|---|
| `HighAverageNodeCpuUsage` | Average worker CPU above 70% | 2 minutes | `scale-ec2` |
| `LowAverageNodeCpuUsage` | Average worker CPU below 30% | 5 minutes | `scale-down-ec2` |

Alertmanager receives these alerts and forwards them to the scale webhook.

## Run Prometheus

The host needs AWS permission to describe EC2 instances, either through an instance profile or environment credentials.

```bash
cd prometheus
docker network create demo_network || true

docker run -d \
  --name prometheus \
  --network demo_network \
  -p 9090:9090 \
  -e AWS_REGION=us-east-1 \
  -v "$(pwd):/etc/prometheus:ro" \
  prom/prometheus:latest
```

Open:

```text
http://<server-ip>:9090
```

## Verify

In the Prometheus UI:

- Check `Status -> Targets`.
- Confirm `node-exporter-ec2-workers` targets are `UP`.
- Query:

```promql
up{job="node-exporter-ec2-workers"}
```

Check alert state:

```promql
ALERTS
```
