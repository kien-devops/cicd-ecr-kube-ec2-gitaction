global:
  resolve_timeout: 5m

route:
  receiver: default-receiver
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 30s
  repeat_interval: 1m
  routes:
    - matchers:
        - alertname="HighAverageNodeCpuUsage"
        - action="scale-ec2"
      receiver: scale-ec2-webhook
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 5m
      repeat_interval: 30m
      continue: false
    - matchers:
        - alertname="LowAverageNodeCpuUsage"
        - action="scale-down-ec2"
      receiver: scale-ec2-webhook
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 5m
      repeat_interval: 30m
      continue: false

receivers:
  - name: default-receiver
  - name: scale-ec2-webhook
    webhook_configs:
      - url: "${SCALE_WEBHOOK_URL}"
        send_resolved: false
