# Hospital Frontend

React 19 frontend built with Vite and served by Nginx in production.

## Tech Stack

| Area | Tool |
|---|---|
| Framework | React 19 |
| Build tool | Vite 6 |
| UI | Ant Design, React Bootstrap, Bootstrap |
| Routing | React Router DOM |
| HTTP | Axios |
| Charts | Chart.js, react-chartjs-2 |
| Editor | TinyMCE React |
| Runtime image | Nginx Alpine |

## Local Development

```bash
cd hospital_FE
npm install
npm run dev
```

Build:

```bash
npm run build
```

Lint:

```bash
npm run lint
```

Preview build:

```bash
npm run preview
```

## Docker

```bash
cd hospital_FE
docker build -t hospital-fe .
docker run --rm -p 5173:8000 hospital-fe
```

The Dockerfile uses:

1. `node:22-alpine` to build static files.
2. `nginx:1.27-alpine` to serve `dist/`.

Nginx listens on port `8000` because the container runs as the non-root `nginx` user.

## Kubernetes

The frontend is deployed by:

```text
k8s-traefik-lb-demo/k8s/05-fe-deployment.yaml
k8s-traefik-lb-demo/k8s/06-fe-service.yaml
```

Public route:

```text
https://benhvien.teamdevops.shop/
```

## CI/CD

GitHub Actions builds this image on the EC2 build server and pushes it to ECR as:

```text
606030503959.dkr.ecr.us-east-1.amazonaws.com/ecr-fe:<git-sha>
```
