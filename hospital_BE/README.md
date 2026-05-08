# Hospital Backend Folder

This folder contains the ASP.NET Core backend solution and backend deployment notes.

## Structure

| Path | Purpose |
|---|---|
| `Hospital_Project.sln` | Visual Studio solution. |
| `Hospital_API/` | Main ASP.NET Core 9 Web API project. |
| `nginx-deployment-guide.md` | Older/manual deployment notes. |
| `temp_history/` | Historical code snapshots. Not part of runtime. |

## Main Project

Read the project README:

```text
hospital_BE/Hospital_API/README.md
```

## Local Build

```bash
cd hospital_BE/Hospital_API
dotnet restore
dotnet build
dotnet run
```

The API listens on the port configured by launch settings locally, and on port `8080` inside Docker/Kubernetes.

## Database Config

For local development, use ignored local file:

```text
hospital_BE/Hospital_API/appsettings.json
```

For Kubernetes, do not put the connection string into Git. Create `be-db-secret` on the server and let `07-be-deployment.yaml` inject it into:

```text
ConnectionStrings__DefaultConnection
```
