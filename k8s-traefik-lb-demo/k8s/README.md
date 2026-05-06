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
- `03-traefik-deployment.yaml`: runs Traefik as a DaemonSet with Gateway API and CRD providers enabled.
- `04-traefik-service.yaml`: exposes Traefik through NodePort `30080` and `30443`.
- `05` to `08`: deploy frontend/backend workloads and services in the `hospital` namespace.
- `09-gateway-routes.yaml`: defines Gateway, Middleware, and HTTPRoutes in the `hospital` namespace.

Prerequisites:

- The machine running the apply command can reach GitHub to install CRDs.
- AWS CLI is configured with permission to read ECR auth tokens.

Apply:

```bash
cd k8s-traefik-lb-demo
bash k8s/apply.sh
```

The script checks for CRDs first, installs Gateway API CRDs v1.3.0 and Traefik CRDs v3.0 when missing, waits for them to be ready, then applies the local manifests. Running only `kubectl apply -f k8s/` on a fresh cluster fails because `GatewayClass`, `Gateway`, `HTTPRoute`, and Traefik `Middleware` are custom resources.

The script also creates the ECR image pull secret used by frontend/backend deployments:

```bash
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry ecr-secret \
  --docker-server=606030503959.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="${ECR_PASSWORD}" \
  -n hospital
```

To refresh only the ECR secret:

```bash
bash k8s/create-ecr-secret.sh
```

Manual CRD checks:

```bash
kubectl get crd | grep -E 'gatewayclasses|gateways|httproutes|middlewares'
kubectl get crd | grep gateway.networking.k8s.io
kubectl get crd | grep traefik
```

Manual install if needed:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
kubectl apply -f k8s/
```

Verify:

```bash
kubectl get pods -A
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl get middleware -A
```
