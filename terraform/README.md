# Terraform Infrastructure

This folder provisions EC2 worker nodes used by the Kubernetes cluster.

## Files

| File | Purpose |
|---|---|
| `main.tf` | Root module that calls `modules/ec2-workers`. |
| `variables.tf` | Root input variables. |
| `outputs.tf` | Outputs such as worker IPs. |
| `moved.tf` | Terraform state move declarations. |
| `terraform.tfvars.example` | Example local variable file. |
| `add-node.sh` | Adds a worker node. |
| `remove-node.sh` | Removes a worker node. |
| `modules/ec2-workers/` | EC2 worker module with instance and IAM config. |

## Worker Module

`modules/ec2-workers` creates:

- EC2 worker instances.
- IAM role and instance profile.
- Tags used by Prometheus service discovery, including `Monitoring=enabled`.
- Ansible inventory file at the configured `ansible_inventory_path`.

## Setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your AWS values:

- Region
- AMI ID
- Instance type
- Key pair name
- VPC ID
- Security group ID
- Worker node map
- Ansible inventory path

## Standard Terraform Commands

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Scale Out

```bash
cd terraform
bash add-node.sh
```

Or pass a name and instance type if supported by the script:

```bash
bash add-node.sh node3 t3.medium
```

## Scale In

```bash
cd terraform
bash remove-node.sh
```

Or remove a named node if supported by the script:

```bash
bash remove-node.sh node3
```

## Integration Points

- `ansible-web/provision-ec2-and-run-ansible.sh` calls `add-node.sh`, then joins the new EC2 instance to Kubernetes.
- `prometheus/prometheus.yml` discovers workers using EC2 service discovery.
- `alertmanager/scale_webhook.py` calls scale scripts when CPU alerts fire.
