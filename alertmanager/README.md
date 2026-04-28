# Alertmanager EC2 Scale Webhook

Workflow:

1. Prometheus fires `HighAverageNodeCpuUsage` when average CPU across `node_exporter` targets is above 50%.
2. Alertmanager sends the alert to `http://127.0.0.1:5001/scale-ec2`.
3. `scale_webhook.py` receives the webhook and runs the scale workflow.
4. If `SCALE_SERVER_IP` is set, the webhook SSHs into that server and runs `cd $SCALE_WORKFLOW_DIR && bash ./$SCALE_WORKFLOW_SCRIPT`.
5. The workflow creates/updates EC2 with Terraform, then runs Ansible to join the node to Kubernetes.

```mermaid
flowchart TD
    A[Node Exporter targets] -->|CPU metrics| B[Prometheus]
    B -->|Evaluate alert_rules.yml every 15s| C{Average CPU > 50% for 2m?}
    C -->|No| D[Alert stays inactive]
    C -->|Yes| E[Fire HighAverageNodeCpuUsage]
    E -->|Send alert| F[Alertmanager]
    F -->|Route action=scale-ec2| G[Webhook receiver<br/>http://127.0.0.1:5001/scale-ec2]
    G -->|Read scale-webhook.env| H[scale_webhook.py]
    H -->|SSH with user.pem| I[Terraform server]
    I -->|cd SCALE_WORKFLOW_DIR| J[Run provision-ec2-and-run-ansible.sh]
    J -->|terraform apply| K[AWS EC2 creates one new node]
    K --> L[Terraform updates hosts.ini]
    L --> M[Ansible runs common.sh and kubeadm join]
```

Example SSH mode:

```bash
cp alertmanager/scale-webhook.env.example alertmanager/scale-webhook.env
vi alertmanager/scale-webhook.env
python3 alertmanager/scale_webhook.py
```

`alertmanager/scale-webhook.env` is ignored by git. Put the Terraform server IP there:

```bash
SCALE_SERVER_IP=ip serrver 
SCALE_SSH_USER=ubuntu
SCALE_SSH_KEY=/home/ubuntu/alertmanager/user.pem
SCALE_WORKFLOW_DIR=/home/ubuntu
SCALE_WORKFLOW_SCRIPT=provision-ec2-and-run-ansible.sh
```

Install with systemd:

```bash
sudo cp alertmanager/scale-webhook.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now scale-webhook
sudo systemctl status scale-webhook
```

Notes:

- The machine running the webhook must be able to SSH to the Terraform server without an interactive password prompt. The default key path is `alertmanager/user.pem`; on your server that is `/home/ubuntu/alertmanager/user.pem`.
- The Terraform/Ansible server must already have AWS credentials, Terraform, Ansible, `terraform/terraform.tfvars`, `ansible-web/.env`, and `ansible-web/kien.pem`.
- `provision-ec2-and-run-ansible.sh` must be available inside `SCALE_WORKFLOW_DIR`.
- Cooldown defaults to 30 minutes via `SCALE_WEBHOOK_COOLDOWN_SECONDS=1800`, so repeated alerts do not create EC2 instances continuously.
