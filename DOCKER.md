# Docker Instructions — Bob's Used Bookstore

## Overview

This is an ASP.NET Core 8 MVC web application (customer and admin portals) containerized using a multi-stage Docker build. The runtime image uses Amazon Linux 2023 with the `aspnetcore-runtime-8.0` package.

---

## Build

From the root of the extracted source directory (the directory containing `BobsBookstore.sln`):

```bash
docker build -t bobs-used-bookstore .
```

---

## Run

### Development mode (no AWS credentials required)

In `Development` mode the application uses:
- **Local fake authentication** (no Amazon Cognito required)
- **Local file storage** in `wwwroot/` (no Amazon S3 required)
- **SQLite or SQL Server LocalDB** via a connection string (no AWS Secrets Manager required)

```bash
docker run -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Development \
  -e "ConnectionStrings__BookstoreDbDefaultConnection=<your-sql-server-connection-string>" \
  bobs-used-bookstore
```

Then open http://localhost:8080 in your browser.

### Production mode (AWS credentials required)

In production the application connects to AWS services at startup. Provide credentials via environment variables or an IAM role (ECS task role recommended).

```bash
docker run -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  -e AWS__Region=us-east-1 \
  -e dbsecretsname=<your-secrets-manager-secret-name> \
  -e AWS_ACCESS_KEY_ID=<key> \
  -e AWS_SECRET_ACCESS_KEY=<secret> \
  -e AWS_SESSION_TOKEN=<token> \
  bobs-used-bookstore
```

---

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | Runtime environment (`Development`, `Test`, `Production`). Controls auth mode and config sources. | Yes |
| `ConnectionStrings__BookstoreDbDefaultConnection` | Direct SQL Server connection string. If set, bypasses AWS Secrets Manager for DB credentials. | No |
| `dbsecretsname` | Name of the AWS Secrets Manager secret containing RDS SQL Server credentials (`host`, `port`, `username`, `password`). | No (if connection string is set) |
| `AWS__Region` | AWS region for SDK service clients (S3, Cognito, Secrets Manager, SSM). | No (inferred from instance metadata on ECS) |
| `AWS__BucketName` | Amazon S3 bucket name for book cover image storage. | No (only in non-Development mode) |
| `AWS__CloudFrontDomain` | Amazon CloudFront domain for serving book cover images. | No (only in non-Development mode) |
| `AWS__Service` | Deployment target identifier (`EC2`, `AppRunner`). Selects the correct Cognito client ID. | No |

---

## AWS Service Dependencies (non-Development mode)

| Service | Purpose |
|---|---|
| **Amazon RDS (SQL Server)** | Application database. Credentials fetched from Secrets Manager via `dbsecretsname`. |
| **AWS Systems Manager Parameter Store** | Application configuration loaded from `/BobsBookstore/` path at startup. |
| **Amazon Cognito** | User authentication (OpenID Connect / Hosted UI). |
| **Amazon S3** | Book cover image storage. |
| **Amazon Rekognition** | Image content validation for uploaded book covers. |
| **Amazon CloudWatch Logs** | Application log output (log group: `BobsBookstore`). |

---

## Secret Handling

For production deployments, manage secrets using:
- **ECS**: [Secrets Manager integration with ECS task definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)
- **EKS**: [Secrets Manager or KMS encryption for Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/security-k8s.html)

Do **not** pass secrets as plain environment variables in production.

---

## Exposed Port

| Port | Protocol | Description |
|---|---|---|
| `8080` | HTTP | ASP.NET Core Kestrel web server |

---

## Notes

- The application runs as a non-root user (`appuser`) inside the container.
- In `Development` mode, uploaded book cover images are stored ephemerally in `/app/wwwroot/images/coverimages/` inside the container. Mount a volume if persistence is needed locally.
- The `ASPNETCORE_URLS` environment variable is set to `http://+:8080` in the Dockerfile. TLS termination should be handled by the load balancer (ALB) in production.
