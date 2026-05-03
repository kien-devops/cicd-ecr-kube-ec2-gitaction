# Kubernetes Traefik Gateway Stack

This folder deploys Traefik as a Kubernetes Gateway API controller and routes the hospital app through one domain.

Traffic flow inside the cluster:

```text
Traefik NodePort -> Gateway web-gateway-v1 -> HTTPRoute
/api -> be-service-v1 -> backend pods
/    -> fe-service-v1 -> frontend pods
```

Main resources:

- `00-namespace.yaml`: creates the `traefik` and `hospital` namespaces.
- `01-traefik-rbac.yaml`: grants Traefik access to Services, Gateway API resources, and Middleware CRDs.
- `02-traefik-gatewayclass.yaml`: registers the Traefik GatewayClass.
- `03-traefik-deployment.yaml`: runs Traefik with Gateway API and CRD providers enabled.
- `04-traefik-service.yaml`: exposes Traefik through NodePort `30080` and `30443`.
- `05` to `08`: deploy frontend/backend workloads and services in the `hospital` namespace.
- `09-gateway-routes.yaml`: defines Gateway, Middleware, and HTTPRoutes in the `hospital` namespace.

Prerequisites:

- Gateway API CRDs installed.
- Traefik CRDs installed for `Middleware`.
- `ecr-secret` exists in the `hospital` namespace if the ECR images are private.

Apply:

```bash
kubectl apply -f k8s/
```
