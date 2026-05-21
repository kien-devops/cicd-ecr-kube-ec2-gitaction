# Argo CD GitOps

![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Deployments-326CE5?logo=kubernetes&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Source%20of%20Truth-181717?logo=github&logoColor=white)
![YAML](https://img.shields.io/badge/YAML-Manifests-CB171E?logo=yaml&logoColor=white)

This folder contains the Argo CD `Application` that continuously deploys the Kubernetes runtime stack from Git.

Argo CD is the desired-state controller for the cluster. Git is the source of truth, and manual cluster changes may be reverted when self-heal is enabled.

## Architecture

```mermaid
flowchart LR
    git[Git repository<br/>branch devops] --> app[Argo CD Application]
    app --> path[k8s-traefik-lb-demo/k8s]
    path --> sync[Automated sync]
    sync --> ns1[namespace traefik]
    sync --> ns2[namespace hospital]
    ns1 --> traefik[Traefik Gateway]
    ns2 --> workloads[Frontend and backend workloads]
```

## Files

| File | Purpose |
|---|---|
| `hospital-traefik-app.yaml` | Argo CD Application for the Hospital Kubernetes stack. |
| `external-secrets-app.yaml` | Argo CD Application for the External Secrets Operator stack. |
| `SETUP.md` | Step-by-step Argo CD installation notes. |
| `images/` | Documentation images. |

## Application Configuration

| Setting | Value |
|---|---|
| Repository | `https://github.com/kien-devops/cicd-ecr-kube-ec2-gitaction.git` |
| Target revision | `devops` |
| Manifest path | `k8s-traefik-lb-demo/k8s` |
| Destination server | `https://kubernetes.default.svc` |
| Destination namespace | `hospital` |
| Automated sync | Enabled |
| Prune | Enabled |
| Self-heal | Enabled |

## Deployment Flow

```mermaid
sequenceDiagram
    participant CI as GitHub Actions
    participant Git as Git repository
    participant A as Argo CD
    participant K as Kubernetes

    CI->>Git: Commit updated image tags
    A->>Git: Poll or receive refresh
    A->>A: Compare desired state with live state
    A->>K: Apply manifests
    A->>K: Prune removed resources
    A->>K: Self-heal drift
```

## Apply the Application

Run on a host with cluster access:

```bash
kubectl apply -f argocd/hospital-traefik-app.yaml
```

## Access the Argo CD UI

Port-forward the API server:

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

## Verify Sync

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application hospital-traefik-app
kubectl get pods -n hospital
kubectl get pods -n traefik
kubectl get gateway,httproute -n hospital
```

If you use the Argo CD CLI:

```bash
argocd app get hospital-traefik-app
argocd app sync hospital-traefik-app
```

## Operational Notes

| Topic | Guidance |
|---|---|
| Manual edits | Avoid `kubectl edit` for managed resources. Commit the change to Git instead. |
| Runtime secrets | Managed dynamically by External Secrets Operator (ESO) from AWS Secrets Manager. |
| Image deployment | GitHub Actions updates image tags in Git, then Argo CD syncs. |
| Drift | Self-heal will bring live resources back to Git state. |
| Prune | Deleted manifests can delete live resources during sync. Review changes carefully. |

## Troubleshooting

| Symptom | Check |
|---|---|
| Application is OutOfSync | Review changed resources and sync status. |
| Application is Degraded | Inspect pod status, events, and CRD readiness. |
| Sync fails on Gateway resources | Gateway API CRDs and Traefik CRDs must exist. |
| Image pull errors after sync | ECR secret, ECR tag, worker registry access. |
| Manual changes disappear | Expected behavior when self-heal is enabled. |
