## Architecture Overview

```mermaid
flowchart LR
    Dev[Developer] --> GitHub[GitHub Repository]
    GitHub --> GHA[GitHub Actions CI/CD]
    GHA -->|Build & Push Image| ECR[Amazon ECR]

    User[End User] --> DNS[Route 53 / Domain]
    DNS --> ALB[Application Load Balancer]

    subgraph K8s[Kubernetes Cluster]
        CP[Control Plane]
        Ingress[Ingress Controller]

        subgraph Workers[Worker Nodes]
            W1[Worker Node 1]
            W2[Worker Node 2]
        end

        subgraph App[Application]
            FE[Frontend Pod]
            BE[Backend Pod]
        end
    end

    subgraph Monitoring[Monitoring Stack]
        Prom[Prometheus]
        Graf[Grafana]
    end

    ECR -->|Deploy / Update Image| CP
    ECR -. Pull Image .-> W1
    ECR -. Pull Image .-> W2

    ALB --> Ingress
    Ingress --> FE
    Ingress --> BE

    W1 -->|Node Metrics| Prom
    W2 -->|Node Metrics| Prom
    FE -->|App Metrics| Prom
    BE -->|App Metrics| Prom
    Prom --> Graf
```

### Description

- Source code is pushed to GitHub
- GitHub Actions builds Docker images and pushes them to Amazon ECR
- Kubernetes pulls images from ECR and deploys the application
- Users access the system through Route 53 and an Application Load Balancer
- Prometheus collects infrastructure and application metrics
- Grafana visualizes monitoring dashboards
