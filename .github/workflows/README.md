# GitHub Actions Workflow

This folder documents `.github/workflows/deploy-ecr-on-ec2.yml`.

The workflow runs on pushes to the `devops` branch. It builds Docker images on a dedicated EC2 build server, pushes them to Amazon ECR, then commits updated Kubernetes image tags back to this repository for ArgoCD to deploy.

## Flow

```text
push to devops
  -> GitHub Actions runner
  -> SSH to EC2 build server
  -> git clone/fetch repo on EC2
  -> docker build frontend and backend
  -> docker push to ECR
  -> update k8s deployment image tags in Git
  -> ArgoCD syncs the cluster
```

## Workflow File

- `deploy-ecr-on-ec2.yml`

## Images Built

| App | Dockerfile | ECR image |
|---|---|---|
| Frontend | `hospital_FE/Dockerfile` | `606030503959.dkr.ecr.us-east-1.amazonaws.com/ecr-fe:<sha>` |
| Backend | `hospital_BE/Hospital_API/Dockerfile` | `606030503959.dkr.ecr.us-east-1.amazonaws.com/ecr-be:<sha>` |

The image tag is the Git commit SHA: `${{ github.sha }}`.

## Required GitHub Secrets

Configure these in GitHub repository settings:

| Secret | Purpose |
|---|---|
| `EC2_SSH_PRIVATE_KEY` | Private SSH key used to connect to the EC2 build server. |
| `EC2_HOST` | Public IP or DNS name of the EC2 build server. |
| `EC2_HOST_KEY` | SSH host key from `ssh-keyscan -H <EC2_HOST>`. |
| `GIT_USERNAME` | GitHub username used by the EC2 build server when fetching the repo. |
| `GIT_PASSWORD` | GitHub token used by the EC2 build server when fetching the repo. |

## EC2 Build Server Requirements

The build server must have:

- Docker installed and running.
- AWS CLI installed.
- Permission to push to ECR, usually through an EC2 IAM role.
- Access to this GitHub repository.

## Loop Protection

The workflow commits image tag updates back to `devops`. To prevent an infinite build loop, it skips commits whose message contains:

```text
ci: update image tag
```

## Files Updated by CI

```text
k8s-traefik-lb-demo/k8s/05-fe-deployment.yaml
k8s-traefik-lb-demo/k8s/07-be-deployment.yaml
```
