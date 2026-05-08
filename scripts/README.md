# Utility Scripts

This folder contains helper scripts that are not part of the main Kubernetes GitOps flow.

## Files

| File | Purpose |
|---|---|
| `push-be-ecr.ps1` | PowerShell helper for building/pushing the backend image to ECR manually. |
| `run-ecs-task.ps1` | PowerShell helper for running an ECS task manually. |

## Notes

- The primary CI/CD path is `.github/workflows/deploy-ecr-on-ec2.yml`.
- Prefer the GitHub Actions pipeline for normal deployments.
- Use these scripts only for manual testing or one-off operations.
- Do not hardcode AWS credentials or application secrets in scripts.
