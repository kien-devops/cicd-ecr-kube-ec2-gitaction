# Hospital API

ASP.NET Core 9 Web API for the hospital system.

## Tech Stack

| Area | Tool |
|---|---|
| Runtime | ASP.NET Core 9 |
| Database | SQL Server |
| ORM | Entity Framework Core 9 |
| Auth | JWT Bearer |
| Password hashing | BCrypt.Net-Next |
| Mapping | AutoMapper |
| Docs | Swagger / Swashbuckle |
| Email | SendGrid |

## Important Files

| Path | Purpose |
|---|---|
| `Program.cs` | Service registration, CORS, Swagger, JWT auth, DB context, routing. |
| `Data/HospitalDbContext.cs` | EF Core database context. |
| `Controllers/` | API controllers. Routes use `api/[controller]`. |
| `Services/` | Business logic. |
| `Repositories/` | Data access. |
| `DTOs/` | Request and response models. |
| `Migrations/` | EF Core migrations. |
| `appsettings.example.json` | Safe template only. |
| `appsettings.json` | Local ignored config. Do not commit. |
| `Dockerfile` | Multi-stage .NET build/runtime image. |

## Local Configuration

Create `appsettings.json` from the example:

```bash
cp appsettings.example.json appsettings.json
```

Set local values:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=<DB_HOST>,1433;Database=hospital;User Id=sa;Password=<DB_PASSWORD>;TrustServerCertificate=True;Encrypt=True"
  }
}
```

`appsettings.json` is ignored by Git.

## Kubernetes Configuration

The Kubernetes deployment does not need `appsettings.json`. It reads the DB connection string from env:

```text
ConnectionStrings__DefaultConnection
```

Create the Secret on the server:

```bash
kubectl -n hospital create secret generic be-db-secret \
  --from-literal=default-connection='Server=<DB_HOST>,1433;Database=hospital;User Id=sa;Password=<DB_PASSWORD>;TrustServerCertificate=True;Encrypt=True' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Restart:

```bash
kubectl -n hospital rollout restart deployment/be-deployment-v1
```

## Run Locally

```bash
dotnet restore
dotnet build
dotnet run
```

Swagger is available when the app is reachable at:

```text
/swagger
```

## Docker

```bash
docker build -t hospital-api .
docker run --rm -p 5247:8080 hospital-api
```

## Public API Tests

When deployed behind HAProxy and Traefik:

```bash
curl -i https://benhvien.teamdevops.shop/api/User/test
curl -i https://benhvien.teamdevops.shop/api/Branch
curl -i https://benhvien.teamdevops.shop/api/Doctor
```

`/api/User/test` checks routing only. `/api/Branch` and `/api/Doctor` also check SQL Server access.

## Troubleshooting

Backend logs:

```bash
kubectl -n hospital logs deployment/be-deployment-v1 -c be-v1 --tail=100
```

Check env injection:

```bash
kubectl -n hospital get deploy be-deployment-v1 -o yaml | grep -A8 "ConnectionStrings__DefaultConnection"
```

Check the Secret value:

```bash
kubectl -n hospital get secret be-db-secret -o jsonpath='{.data.default-connection}' | base64 -d
echo
```
