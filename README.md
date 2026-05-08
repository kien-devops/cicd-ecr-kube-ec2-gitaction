# Hospital CI/CD, GitOps, and Kubernetes Infrastructure

This repository contains a full deployment stack for a Hospital web application:

- `hospital_FE`: React/Vite frontend served by Nginx.
- `hospital_BE/Hospital_API`: ASP.NET Core 9 backend API using SQL Server.
- `.github/workflows`: GitHub Actions pipeline that builds images on an EC2 build host and pushes them to ECR.
- `argocd`: ArgoCD application that syncs Kubernetes manifests from Git.
- `k8s-traefik-lb-demo/k8s`: Kubernetes manifests for Traefik Gateway API, frontend, backend, services, routes, and network policies.
- `k8s-traefik-lb-demo/alb`: HAProxy edge load balancer for public HTTPS traffic.
- `prometheus` and `alertmanager`: monitoring, alerting, and auto-scale trigger config.
- `terraform` and `ansible-web`: EC2 worker provisioning and Kubernetes node join automation.

## Runtime Flow

```text
User
  -> https://benhvien.teamdevops.shop
  -> HAProxy edge LB, TLS termination
  -> Traefik NodePort 30080
  -> Gateway API HTTPRoute
     - /api/* -> backend service -> ASP.NET API pods
     - /*     -> frontend service -> React/Nginx pods
```

## CI/CD Flow

1. Developer pushes to branch `devops`.
2. GitHub Actions SSHes to the EC2 build server.
3. The EC2 build server builds:
   - `hospital_FE/Dockerfile` -> `ecr-fe:<git-sha>`
   - `hospital_BE/Hospital_API/Dockerfile` -> `ecr-be:<git-sha>`
4. Images are pushed to Amazon ECR.
5. GitHub Actions updates the image tags in:
   - `k8s-traefik-lb-demo/k8s/05-fe-deployment.yaml`
   - `k8s-traefik-lb-demo/k8s/07-be-deployment.yaml`
6. ArgoCD detects the manifest change and syncs the cluster.

## Important Server Secrets

Do not commit real credentials to Git.

The backend database connection is injected in Kubernetes through a Secret referenced by `07-be-deployment.yaml`:

```bash
kubectl -n hospital create secret generic be-db-secret \
  --from-literal=default-connection='Server=<DB_HOST>,1433;Database=hospital;User Id=sa;Password=<DB_PASSWORD>;TrustServerCertificate=True;Encrypt=True' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Restart the backend after changing the secret:

```bash
kubectl -n hospital rollout restart deployment/be-deployment-v1
kubectl -n hospital rollout status deployment/be-deployment-v1
```

## Public API Checks

Use these from the server or your machine:

```bash
curl -i https://benhvien.teamdevops.shop/api/User/test
curl -i https://benhvien.teamdevops.shop/api/Branch
curl -i https://benhvien.teamdevops.shop/api/Doctor
```

`/api/User/test` does not query the database. If it returns `200` but `/api/Branch` or `/api/Doctor` returns `500`, routing is working and the next thing to check is backend logs or SQL connectivity:

```bash
kubectl -n hospital logs deployment/be-deployment-v1 -c be-v1 --tail=100
```

## Useful Commands

```bash
kubectl get nodes -o wide
kubectl get pods -n hospital -o wide
kubectl get pods -n traefik -o wide
kubectl get gateway,httproute -n hospital
kubectl -n hospital describe deployment be-deployment-v1
```

## Folder Guides

Each main folder has its own README:

- `.github/workflows/README.md`
- `hospital_FE/README.md`
- `hospital_BE/README.md`
- `hospital_BE/Hospital_API/README.md`
- `argocd/README.md`
- `k8s-traefik-lb-demo/k8s/README.md`
- `k8s-traefik-lb-demo/alb/README.md`
- `prometheus/README.md`
- `alertmanager/README.md`
- `terraform/README.md`
- `ansible-web/README.md`
- `scripts/README.md`
