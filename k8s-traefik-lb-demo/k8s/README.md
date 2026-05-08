# Kubernetes and Traefik Gateway Manifests

This folder contains the Kubernetes runtime stack for the hospital application.

## Traffic Flow

```text
HAProxy HTTPS edge
  -> HTTP to Traefik NodePort 30080
  -> Gateway web-gateway-v1
  -> HTTPRoute web-route-v1
     - /api -> be-service-v1 -> backend pods on 8080
     - /    -> fe-service-v1 -> frontend pods on 8000
```

## Files

| File | Purpose |
|---|---|
| `00-namespace.yaml` | Creates `traefik` and `hospital` namespaces. |
| `01-traefik-rbac.yaml` | ServiceAccount, ClusterRole, and binding for Traefik. |
| `02-traefik-gatewayclass.yaml` | Defines `GatewayClass` named `traefik`. |
| `03-traefik-deployment.yaml` | Runs Traefik as a DaemonSet on port `8000`. |
| `04-traefik-service.yaml` | Exposes Traefik through NodePort `30080`. |
| `05-fe-deployment.yaml` | Frontend Deployment from ECR. |
| `06-fe-service.yaml` | Frontend ClusterIP Service. |
| `07-be-deployment.yaml` | Backend Deployment from ECR. Reads DB connection from `be-db-secret`. |
| `08-be-service.yaml` | Backend ClusterIP Service. |
| `09-gateway-routes.yaml` | Gateway, HTTPRoute, rate limit, and security headers. |
| `10-network-policy.yaml` | Default-deny ingress plus allow rules for Traefik to FE/BE. |
| `apply.sh` | Installs required CRDs and applies all manifests. |

## Required Secrets

### ECR Pull Secret

The deployments reference:

```yaml
imagePullSecrets:
  - name: ecr-registry-secret
```

Create or refresh it:

```bash
aws ecr get-login-password --region us-east-1 \
  | kubectl create secret docker-registry ecr-registry-secret \
    -n hospital \
    --docker-server=606030503959.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password-stdin \
    --dry-run=client -o yaml | kubectl apply -f -
```

### Backend Database Secret

The backend reads `ConnectionStrings__DefaultConnection` from `be-db-secret`:

```bash
kubectl -n hospital create secret generic be-db-secret \
  --from-literal=default-connection='Server=<DB_HOST>,1433;Database=hospital;User Id=sa;Password=<DB_PASSWORD>;TrustServerCertificate=True;Encrypt=True' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Restart after changing it:

```bash
kubectl -n hospital rollout restart deployment/be-deployment-v1
```

## Manual Apply

```bash
cd k8s-traefik-lb-demo
bash k8s/apply.sh
```

In normal operation, ArgoCD applies this folder from Git.

## Verify

```bash
kubectl get pods -n traefik -o wide
kubectl get pods -n hospital -o wide
kubectl get svc -n traefik
kubectl get svc -n hospital
kubectl get gateway,httproute -n hospital
```

## Test API

```bash
curl -i https://benhvien.teamdevops.shop/api/User/test
curl -i https://benhvien.teamdevops.shop/api/Branch
```

`/api/User/test` proves routing to the backend. `/api/Branch` also proves SQL Server access.
