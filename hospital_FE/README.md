# 💻 Hospital Frontend (React + Vite)

![React](https://img.shields.io/badge/react-%2320232a.svg?style=for-the-badge&logo=react&logoColor=%2361DAFB)
![Vite](https://img.shields.io/badge/vite-%23646CFF.svg?style=for-the-badge&logo=vite&logoColor=white)
![Ant Design](https://img.shields.io/badge/-AntDesign-%230170FE?style=for-the-badge&logo=ant-design&logoColor=white)
![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)

The frontend web application for the Hospital Management System — a single-page application built with **React 19**, **Vite 6**, and **Ant Design 5**.

---

## 🛠 Tech Stack

| Category | Technology |
|---|---|
| **Framework** | React 19 |
| **Build Tool** | Vite 6 |
| **UI Library** | Ant Design 5, React Bootstrap |
| **HTTP Client** | Axios |
| **Routing** | React Router DOM v7 |
| **Charts** | Chart.js + react-chartjs-2 |
| **Rich Text Editor** | TinyMCE (via `@tinymce/tinymce-react`) |
| **Notifications** | React Toastify, SweetAlert2 |
| **Linting** | ESLint 9 |

---

## 🚀 Development

### Prerequisites
- Node.js >= 22 (matches the Dockerfile base image)

### Install & Run

```bash
npm install
npm run dev
```

### Available Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start Vite dev server with HMR |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint checks |

---

## 🐳 Docker Build

The Dockerfile uses a **multi-stage build** for optimal image size:

1. **Stage 1 (Build):** `node:22-alpine` — installs dependencies and runs `vite build`.
2. **Stage 2 (Runtime):** `nginx:1.27-alpine` — serves the static `dist/` output on port `80`.

```bash
docker build -t hospital-fe .
docker run -p 8080:80 hospital-fe
```

---

## 🔗 CI/CD Integration

In the automated pipeline:
1. **GitHub Actions** triggers a build on the EC2 build server.
2. The image is tagged with the Git commit SHA and pushed to **Amazon ECR** as `ecr-fe:<sha>`.
3. **ArgoCD** syncs the updated Kubernetes manifest, and the new image is deployed to the `hospital` namespace.

---

## ⚙️ Environment Variables

For features like the TinyMCE editor, use Vite environment variables:

```env
VITE_TINYMCE_API_KEY=your-api-key-here
```

Create a `.env` file in the project root (this file is `.gitignore`d).
