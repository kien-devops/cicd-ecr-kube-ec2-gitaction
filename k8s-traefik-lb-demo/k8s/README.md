# Kubernetes Runtime Manifests

![Kubernetes](https://img.shields.io/badge/Kubernetes-Manifests-326CE5?logo=kubernetes&logoColor=white)
![Gateway API](https://img.shields.io/badge/Gateway%20API-HTTPRoute-326CE5?logo=kubernetes&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-Ingress%20Gateway-24A1C1?logo=traefikproxy&logoColor=white)
![Amazon ECR](https://img.shields.io/badge/Amazon%20ECR-Images-FF9900?logo=amazonaws&logoColor=white)
![NetworkPolicy](https://img.shields.io/badge/NetworkPolicy-Security-326CE5?logo=kubernetes&logoColor=white)

This folder defines the in-cluster runtime stack for the Hospital application. It deploys Traefik as the Gateway API implementation, runs the frontend and backend workloads, exposes them through services, and protects traffic with NetworkPolicies and Traefik middleware.

In normal production operation, Argo CD applies this folder from Git. The included `apply.sh` script is useful for first-time setup or manual recovery.

## Architecture

```mermaid
flowchart TB
    hp[HAProxy edge LB] --> np[Traefik NodePort 30080]
    np --> ds[Traefik DaemonSet<br/>namespace traefik]
    ds --> gw[Gateway web-gateway-v1<br/>namespace hospital]
    gw --> hr[HTTPRoute web-route-v1]
    hr -->|PathPrefix /api| besvc[be-service-v1]
    hr -->|PathPrefix /| fesvc[fe-service-v1]
    besvc --> bepods[be-deployment-v1<br/>ASP.NET Core 8080]
    fesvc --> fepods[fe-deployment-v1<br/>Nginx 8000]
    bepods --> db[(SQL Server)]
```

## Manifest Inventory

| File | Purpose |
|---|---|
| `00-namespace.yaml` | Creates `traefik` and `hospital` namespaces. |
| `01-traefik-rbac.yaml` | Creates Traefik ServiceAccount, ClusterRole, and binding. |
| `02-traefik-gatewayclass.yaml` | Defines GatewayClass `traefik`. |
| `03-traefik-deployment.yaml` | Runs Traefik as a DaemonSet. |
| `04-external-secrets.yaml` | Defines ClusterSecretStore, ECR token generator, and ExternalSecrets for DB & ECR. |
| `04-traefik-service.yaml` | Exposes Traefik on NodePort `30080`. |
| `05-fe-deployment.yaml` | Runs frontend pods from ECR image `ecr-fe:<sha>`. |
| `06-fe-service.yaml` | ClusterIP service for frontend pods. |
| `07-be-deployment.yaml` | Runs backend pods from ECR image `ecr-be:<sha>` and reads DB secret. |
| `08-be-service.yaml` | ClusterIP service for backend pods. |
| `09-gateway-routes.yaml` | Gateway, HTTPRoute, rate limit middleware, security headers middleware. |
| `10-network-policy.yaml` | Default-deny ingress plus allow rules from Traefik to application pods. |
| `apply.sh` | Installs required CRDs if missing and applies all manifests. |

## Required Secrets (Automated via External Secrets Operator)

The application workload secrets are now managed automatically by the **External Secrets Operator (ESO)** using AWS integration. They do not require manual creation or 12-hour CLI updates.

### 1. ECR Pull Secret (`ecr-registry-secret`)

The frontend and backend deployments reference this secret to pull their respective Docker images from AWS ECR:

```yaml
imagePullSecrets:
  - name: ecr-registry-secret
```

This secret is generated dynamically by the `ECRAuthorizationToken` generator defined in `04-external-secrets.yaml` and is automatically rotated every hour.

### 2. Backend Database Secret (`be-db-secret`)

The backend API pod reads the connection string key `default-connection` from this secret:

```yaml
env:
  - name: ConnectionStrings__DefaultConnection
    valueFrom:
      secretKeyRef:
        name: be-db-secret
        key: default-connection
```

This secret is dynamically populated from AWS Secrets Manager using the `be-db-secret` ExternalSecret.

To update the connection string:
1. Modify the secret named `hospital-db-connection` in AWS Secrets Manager (`us-east-1`).
2. The controller will automatically sync the changes into the K8s cluster within 1 hour. To force an immediate update:
   ```bash
   kubectl -n hospital rollout restart deployment/be-deployment-v1
   ```

## Manual Apply

From the repository root:

```bash
cd k8s-traefik-lb-demo
bash k8s/apply.sh
```

The script installs these CRDs if missing:

| CRD group | Used for |
|---|---|
| Gateway API `v1.3.0` | `GatewayClass`, `Gateway`, `HTTPRoute`. |
| Traefik CRD | `Middleware`. |

## GitOps Apply

The recommended steady-state path is Argo CD:

```bash
kubectl apply -f argocd/hospital-traefik-app.yaml
```

Argo CD watches:

```text
repo: https://github.com/kien-devops/cicd-ecr-kube-ec2-gitaction.git
branch: devops
path: k8s-traefik-lb-demo/k8s
```

## Routing Rules

| Match | Backend service |
|---|---|
| `PathPrefix /api` | `be-service-v1` on service port `80`. |
| `PathPrefix /` | `fe-service-v1` on service port `80`. |

The API route is listed before the frontend route so `/api/*` does not fall through to the React application.

## Security Controls

| Control | Location |
|---|---|
| Non-root frontend container | `05-fe-deployment.yaml`. |
| Non-root backend container | `07-be-deployment.yaml`. |
| Read-only frontend root filesystem | `05-fe-deployment.yaml`. |
| Backend upload volume | `07-be-deployment.yaml`. |
| API rate limit middleware | `09-gateway-routes.yaml`. |
| Security headers middleware | `09-gateway-routes.yaml`. |
| Network default-deny | `10-network-policy.yaml`. |

## Verification

```bash
kubectl get pods -n traefik -o wide
kubectl get pods -n hospital -o wide
kubectl get svc -n traefik
kubectl get svc -n hospital
kubectl get gatewayclass
kubectl get gateway,httproute,middleware -n hospital
kubectl describe httproute web-route-v1 -n hospital
```

Test externally:

```bash
curl -I https://benhvien.teamdevops.shop
curl -i https://benhvien.teamdevops.shop/api/User/test
curl -i https://benhvien.teamdevops.shop/api/Branch
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Gateway resources fail to apply | Gateway API and Traefik CRDs. |
| Pods show `ImagePullBackOff` | `ecr-registry-secret`, ECR tag, worker access to ECR. |
| Backend readiness fails | `/healthz`, DB secret, backend logs. |
| API returns frontend HTML | HTTPRoute rule order and `/api` path match. |
| HAProxy cannot reach Traefik | NodePort `30080`, worker security group, Traefik pod placement. |
| Traffic blocked inside cluster | `10-network-policy.yaml` allow rules and pod labels. |
