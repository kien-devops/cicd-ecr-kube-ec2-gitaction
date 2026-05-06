# 🏗️ Terraform Infrastructure (IaC)

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)

This directory contains the Terraform configuration to provision EC2 worker nodes for the Kubernetes cluster, generate the Ansible inventory file dynamically, and configure IAM Roles for ECR image pulls.

---

## 📂 Directory Structure

```text
terraform/
  ├── main.tf                      # Root module calls
  ├── variables.tf                 # Input variables definition
  ├── outputs.tf                   # Useful outputs (IPs, Roles)
  ├── terraform.tfvars.example     # Template for local configurations
  ├── add-node.sh                  # Helper script to scale OUT
  ├── remove-node.sh               # Helper script to scale IN
  └── modules/
      └── ec2-workers/
          ├── main.tf              # EC2 instances & Ansible hosts.ini generation
          ├── iam.tf               # IAM Role & Instance Profile for ECR pulls
          ├── variables.tf
          └── outputs.tf
```

---

## 🔒 ECR Authentication (IAM Profiles)

Unlike traditional setups that rely on short-lived `imagePullSecrets`, this infrastructure uses **AWS IAM Instance Profiles**. 

Every EC2 worker node is automatically assigned the `hospital-worker-profile` IAM Profile. The Kubelet and containerd runtime seamlessly authenticate with ECR via the EC2 metadata endpoint.

**Benefits:**
- ❌ No Kubernetes Secrets required for Docker registries.
- ❌ No 12-hour token expiration issues.
- ✅ New nodes added via Terraform automatically inherit access.
- ✅ Follows the principle of least privilege (only 4 specific `ecr:*` read actions are allowed).

---

## 🚀 Usage Guide

### 1. Initial Setup

Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with your specific AWS resources (VPC, Subnets, AMI, Key Pair).

### 2. Standard Terraform Workflow

```bash
terraform init
terraform fmt -recursive
terraform plan
terraform apply
```

### 3. Scaling Operations

We provide bash wrappers to safely interact with Terraform for auto-scaling events.

**Add a new worker node:**
```bash
bash add-node.sh
# Or with specific name/type: bash add-node.sh node3 t3.medium
```

**Remove the latest worker node:**
```bash
bash remove-node.sh
# Or remove specific node: bash remove-node.sh node2
```

---

## ⚙️ Integrations

1. **Ansible**: Terraform automatically generates the `/ansible-web/hosts.ini` inventory file containing the newly provisioned node IPs.
2. **Prometheus**: Nodes are automatically tagged with `Monitoring=enabled`, which Prometheus uses for EC2 Service Discovery (`ec2_sd_configs`).
