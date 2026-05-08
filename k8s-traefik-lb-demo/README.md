# Kubernetes Traefik Load Balancing Demo

This folder contains the Kubernetes Gateway API stack and the HAProxy edge load balancer used by the hospital application.

## Structure

| Path | Purpose |
|---|---|
| `k8s/` | Kubernetes manifests for namespaces, Traefik, frontend, backend, services, routes, and network policies. |
| `alb/` | HAProxy edge load balancer config and reload scripts. |

## Request Flow

```text
Internet
  -> HAProxy in alb/
  -> Traefik in k8s/
  -> frontend or backend services
```

Public domain:

```text
https://benhvien.teamdevops.shop
```

Backend API prefix:

```text
https://benhvien.teamdevops.shop/api
```

## Read Next

- `k8s/README.md` for Kubernetes manifests.
- `alb/README.md` for HAProxy, TLS, and public traffic.
