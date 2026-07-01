# Stage 1: Build
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder

RUN dnf update -y && \
    dnf install -y dotnet-sdk-8.0 findutils && \
    dnf clean all

WORKDIR /build

# Copy project files for dependency restore layer caching
COPY app/Bookstore.Web/Bookstore.Web.csproj ./app/Bookstore.Web/
COPY app/Bookstore.Data/Bookstore.Data.csproj ./app/Bookstore.Data/
COPY app/Bookstore.Domain/Bookstore.Domain.csproj ./app/Bookstore.Domain/

# Restore only the web application and its dependencies (tests and CDK excluded)
RUN dotnet restore app/Bookstore.Web/Bookstore.Web.csproj

# Copy the rest of the source code
COPY app/ ./app/

# Publish the web application
RUN dotnet publish app/Bookstore.Web/Bookstore.Web.csproj \
    -c Release \
    -o /publish \
    --no-restore

# Stage 2: Runtime
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

RUN dnf update -y && \
    dnf install -y aspnetcore-runtime-8.0 findutils shadow-utils && \
    dnf clean all

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy published output
COPY --chown=appuser:appuser --from=builder /publish ./

# Create writable directory for local file uploads (Development mode)
RUN mkdir -p /app/wwwroot/images/coverimages && \
    chown -R appuser:appuser /app/wwwroot

USER appuser

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080

CMD ["dotnet", "Bookstore.Web.dll"]
