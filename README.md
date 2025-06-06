# No-Code Architecture Stack Setup Guide

This repository contains a Docker Compose setup for a No-Code Architecture stack with MinIO for S3-compatible storage.

## Quick Start (Automatic Installation)

For Windows users, we've provided batch scripts to automate the setup process:

1. **Setup everything**:

   ```bash
   .\setup.bat
   ```

   This script will:

   - Create environment file from env.tmp (if .env doesn't exist)
   - Create required Docker volumes
   - Create Docker network
   - Start MinIO
   - Create S3 bucket
   - Start all services (NCA Toolkit, Baserow, Workflows, Kokoro TTS)

2. **Check service status**:

   ```bash
   .\status.bat
   ```

3. **Clean up everything**:

   ```bash
   .\cleanup.bat
   ```

4. **Restart a specific service**:
   ```bash
   .\restart.bat [service-name]
   ```

## Manual Setup Guide

If you prefer to set up the stack manually, follow these steps:

### 1. Create environment file

```bash
copy env.tmp .env
```

### 2. Create required Docker volumes

```bash
docker volume create baserow_data
docker volume create n8n_data
docker volume create minio_data
```

### 3. Create Docker network

```bash
docker network create --subnet 172.28.0.0/16 app-network
```

### 4. Start MinIO

```bash
docker compose -f docker-compose.yml --project-name minio up -d minio
```

### 5. Create S3 bucket

Wait for MinIO to be healthy, then create the bucket:

```bash
.\mc.exe config host add myminio http://localhost:9000 admin password123
.\mc.exe mb myminio/nca-toolkit
.\mc.exe anonymous set download myminio/nca-toolkit
```

### 6. Start other services

```bash
docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit --no-deps
docker compose -f docker-compose.yml --project-name baserow up -d baserow --no-deps
docker compose -f docker-compose.yml --project-name workflows up -d workflows --no-deps
docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts --no-deps
```

## Service URLs

After setup, the services will be available at:

- **MinIO API**: http://localhost:9000
- **MinIO Console**: http://localhost:9001
- **NCA Toolkit**: http://localhost:8080
- **Baserow**: http://localhost:8980
- **Workflows (n8n)**: http://localhost:5678
- **Kokoro TTS**: http://localhost:8880

**Important**: Always use the localhost URLs shown above when accessing services from your browser. The internal container hostnames (like 'ncatoolkit' or 'workflows') will only work within the Docker network, not from your local machine.

## Troubleshooting

### Services Show as Unhealthy

If services show as unhealthy in the status check, try the following steps:

1. Restart the affected service:

   ```bash
   .\restart.bat [service_name]
   ```

2. Check the service logs for errors:

   ```bash
   docker logs [container_name]
   ```

3. Some services may need more time to initialize. Try running the status check again after a few minutes.

### Connection Issues

If the NCA Toolkit can't connect to MinIO, verify:

1. MinIO is running and healthy:

   ```bash
   docker ps --filter "name=minio" --filter "health=healthy"
   ```

2. The bucket exists:

   ```bash
   .\mc.exe ls myminio/
   ```

3. Your .env file has the correct credentials:
   ```
   MINIO_ROOT_USER=admin
   MINIO_ROOT_PASSWORD=password123
   S3_ACCESS_KEY=admin
   S3_SECRET_KEY=password123
   ```

## About MinIO

MinIO is an open-source, S3-compatible object storage solution. Key benefits:

1. **Performance**: High-performance, optimized for any workload
2. **Compatibility**: 100% compatible with Amazon S3 API
3. **Security**: Encryption, identity management, and object locking
4. **Scalability**: Scale from terabytes to exabytes without compromising speed
5. **Simplicity**: Easy to deploy and manage

This configuration is optimized for Windows environments using Docker.
