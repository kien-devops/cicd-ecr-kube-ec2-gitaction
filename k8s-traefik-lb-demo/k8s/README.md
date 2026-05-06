# 🚦 Kubernetes Traefik Gateway Stack

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-24A1C1?style=for-the-badge&logo=TraefikProxy&logoColor=white)

This directory contains the Kubernetes manifests to deploy Traefik as a **Gateway API** controller alongside the core hospital application workloads (Frontend and Backend).

---

## 🏗 Traffic Flow Architecture

```mermaid
flowchart TD
    Client([External Load Balancer / HAProxy])
    
    Client -->|NodePort :30080| TraefikSvc[Traefik Service]
    
    TraefikSvc --> Gateway[Gateway: web-gateway-v1]
    
    Gateway --> Route[HTTPRoute: web-route-v1]
    
    subgraph Middlewares
        Route --> RateLimit[Rate Limit: 10 req/s]
        RateLimit --> Prefix[Strip Prefix /api]
    end
    
    Prefix --> Condition{Path matching}
    
    Condition -->|/api/*| BE[Backend Service: be-service-v1]
    Condition -->|/*| FE[Frontend Service: fe-service-v1]
    
    BE --> BEPods(Backend API Pods)
    FE --> FEPods(Frontend React Pods)
```

---

## 📂 Manifests Breakdown

| File | Purpose |
|---|---|
| `00-namespace.yaml` | Creates `traefik` and `hospital` namespaces. |
| `01-traefik-rbac.yaml` | ClusterRoles/Bindings for Traefik to read Gateways & Services. |
| `02-traefik-gatewayclass.yaml` | Registers the Traefik `GatewayClass`. |
| `03-traefik-deployment.yaml` | Deploys Traefik as a DaemonSet across worker nodes. |
| `04-traefik-service.yaml` | Exposes Traefik globally via NodePort `30080` (HTTP) and `30443` (HTTPS). |
| `05` to `08` | Frontend and Backend Deployments + ClusterIP Services. |
| `09-gateway-routes.yaml` | Defines `Gateway`, Traefik `Middleware` (Rate Limits, Headers), and `HTTPRoute`. |

---

## 🔒 ECR Authentication

The Deployments (`05` and `07`) pull private images from Amazon ECR **without `imagePullSecrets`**.
Authentication is securely delegated to the **AWS IAM Instance Profiles** attached directly to the EC2 worker nodes by Terraform. 

---

## 🚀 Deployment / Setup

The provided shell script automatically checks for and installs required custom CRDs (Gateway API `v1.3.0` and Traefik v3 CRDs) before applying the local manifests.

```bash
cd k8s-traefik-lb-demo
bash k8s/apply.sh
```

*(Note: In the full GitOps flow, ArgoCD handles the synchronization of these manifests automatically.)*

### Verify Deployment:
```bash
kubectl get pods -n hospital
kubectl get gateway,httproute -n hospital
