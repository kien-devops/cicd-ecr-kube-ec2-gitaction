# ArgoCD GitOps

This folder contains the ArgoCD `Application` that deploys the Kubernetes stack from Git.

## Files

| File | Purpose |
|---|---|
| `hospital-traefik-app.yaml` | ArgoCD Application for the hospital stack. |
| `SETUP.md` | Step-by-step ArgoCD installation notes. |
| `images/` | Documentation images. |

## Application Source

| Setting | Value |
|---|---|
| Repository | `https://github.com/kien-devops/cicd-ecr-kube-ec2-gitaction.git` |
| Target revision | `devops` |
| Path | `k8s-traefik-lb-demo/k8s` |
| Destination server | `https://kubernetes.default.svc` |
| Destination namespace | `hospital` |
| Auto sync | Enabled with `prune: true` and `selfHeal: true` |

## Apply the Application

Run on the Kubernetes control plane or any host with cluster access:

```bash
kubectl apply -f argocd/hospital-traefik-app.yaml
```

## Access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0
```

Open:

```text
https://<server-ip>:8080
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

## Check Sync

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application hospital-traefik-app
kubectl get pods -n hospital
kubectl get pods -n traefik
```

## Important Notes

- ArgoCD self-heal can overwrite manual changes made directly in the cluster.
- Runtime-only secrets, such as `be-db-secret`, should be created on the server and referenced by manifests.
- Do not put database passwords or JWT secrets into tracked YAML files.
