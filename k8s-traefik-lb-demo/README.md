# Kubernetes Traefik Load Balancing Stack

![Kubernetes](https://img.shields.io/badge/Kubernetes-Runtime-326CE5?logo=kubernetes&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-Gateway%20API-24A1C1?logo=traefikproxy&logoColor=white)
![HAProxy](https://img.shields.io/badge/HAProxy-Edge%20LB-106DA9?logo=haproxy&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-HAProxy%20Runtime-2496ED?logo=docker&logoColor=white)

This folder contains the Kubernetes runtime layer and the public HAProxy edge load balancer for the Hospital platform.

The stack separates public ingress from in-cluster routing:

| Layer | Responsibility |
|---|---|
| `alb/` | Public HAProxy endpoint, HTTPS termination, worker node discovery, backend reloads. |
| `k8s/` | Traefik Gateway API, application deployments, services, HTTP routes, middleware, network policies. |

## Architecture

```mermaid
flowchart TB
    internet[Internet] --> dns[DNS record]
    dns --> alb[HAProxy in alb/]
    alb --> nodeport[Worker NodePort 30080]
    nodeport --> traefik[Traefik DaemonSet]
    traefik --> gateway[Gateway web-gateway-v1]
    gateway --> route[HTTPRoute web-route-v1]
    route --> fe[fe-service-v1]
    route --> be[be-service-v1]
    fe --> fepods[React/Nginx pods]
    be --> bepods[ASP.NET Core pods]
```

## Public Endpoints

| Endpoint | Destination |
|---|---|
| `https://benhvien.teamdevops.shop/` | Frontend application. |
| `https://benhvien.teamdevops.shop/api/*` | Backend API. |
| `https://benhvien.teamdevops.shop/swagger` | Backend Swagger UI. |

## Deployment Order

1. Prepare Kubernetes cluster and worker nodes.
2. Create runtime secrets in namespace `hospital`.
3. Apply `k8s/` manifests manually or through Argo CD.
4. Configure DNS and TLS for HAProxy.
5. Start HAProxy from `alb/`.
6. Verify external traffic.

## Read Next

| Folder | Documentation |
|---|---|
| `k8s/` | Kubernetes manifests, Gateway API, services, secrets, network policies. |
| `alb/` | HAProxy edge load balancer, TLS certificate setup, node discovery, reload automation. |
