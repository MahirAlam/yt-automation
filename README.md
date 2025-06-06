# No-Code Architecture Stack

This repository contains a Docker Compose setup for a No-Code Architecture stack with various services for content creation and automation.

## Overview

The No-Code Architecture Stack provides a complete environment for content creation, media processing, workflows automation, and storage. The stack includes the following services:

- **MinIO**: S3-compatible object storage for storing media files and assets
- **NCA Toolkit**: No-Code Architects Toolkit for content creation and management
- **Workflows (n8n)**: Workflow automation tool with custom Python scripts for video processing
- **Kokoro TTS**: Text-to-Speech service for generating speech from text

## System Requirements

- Docker and Docker Compose installed
- At least 8GB RAM recommended
- (Optional) GPU for accelerated video processing
- Internet connection for container downloads

## Quick Start

Choose the appropriate setup commands based on your operating system:

### Windows Setup

```batch
.\setup.bat
```

### Linux Setup

```bash
# Make the scripts executable
chmod +x *.sh

# Run the setup script
./setup.sh
```

## GPU Support

This stack supports GPU acceleration for video processing on multiple GPU vendors:

- NVIDIA
- AMD
- Intel

### Configuring GPU Support

Edit the `.env` file to configure GPU settings:

```
# GPU CONFIGURATION
# GPU driver to use (iHD for Intel, radeonsi for AMD, nvidia for NVIDIA)
GPU_DRIVER=iHD
# Docker runtime for GPU (runc for default, nvidia for NVIDIA)
GPU_RUNTIME=runc
# CUDA/NVIDIA visible devices (all, 0, 1, etc.)
CUDA_VISIBLE_DEVICES=all
NVIDIA_VISIBLE_DEVICES=all
```

For different GPU vendors:

1. **NVIDIA GPUs**:

   - Set `GPU_DRIVER=nvidia`
   - Set `GPU_RUNTIME=nvidia`
   - Install the NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

2. **AMD GPUs**:

   - Set `GPU_DRIVER=radeonsi`
   - Keep `GPU_RUNTIME=runc`

3. **Intel GPUs**:
   - Set `GPU_DRIVER=iHD` (default)
   - Keep `GPU_RUNTIME=runc`

## Detailed Setup Guide

### Manual Setup Instructions

#### 1. Clone the repository

```bash
git clone https://github.com/yourusername/no-code-architecture-stack.git
cd no-code-architecture-stack
```

#### 2. Create or modify the environment file

```bash
# Windows
copy env.tmp .env

# Linux
cp env.tmp .env
```

#### 3. Create Docker network and volumes

```bash
docker network create --subnet 172.28.0.0/16 app-network
docker volume create n8n_data
docker volume create minio_data
```

#### 4. Start MinIO

```bash
docker compose -f docker-compose.yml --project-name minio up -d minio
```

#### 5. Create S3 bucket

For Windows:

```batch
.\mc.exe alias set myminio http://localhost:9000 admin password123
.\mc.exe mb myminio/nca-toolkit
.\mc.exe anonymous set download myminio/nca-toolkit
```

For Linux:

```bash
./mc alias set myminio http://localhost:9000 admin password123
./mc mb myminio/nca-toolkit
./mc anonymous set download myminio/nca-toolkit
```

#### 6. Start the services

```bash
docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit
docker compose -f docker-compose.yml --project-name workflows up -d workflows
docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts
```

## Service URLs

After setup, access the services at:

- **MinIO API**: http://localhost:9000
- **MinIO Console**: http://localhost:9001
- **NCA Toolkit**: http://localhost:8080
- **Workflows (n8n)**: http://localhost:5678
- **Kokoro TTS**: http://localhost:8880

## Content Creation Workflow

The No-Code Architecture Stack supports the following content creation workflow:

1. **Media Storage**: Upload media files to MinIO for storage
2. **Video Processing**: Use the Workflows service (n8n) to process videos:
   - Split videos into segments
   - Extract clips from videos
   - Process audio from video clips
3. **Content Generation**: Use the NCA Toolkit to generate content
4. **Text-to-Speech**: Convert text to speech using Kokoro TTS

## Available Scripts

### Windows Scripts

- **setup.bat**: Sets up the environment, creates volumes, and starts services
- **update.ps1**: Updates Python scripts in the Docker container
- **restart.bat**: Restarts specific services
- **cleanup.bat**: Stops containers, removes volumes, and cleans up

### Linux Scripts

- **setup.sh**: Sets up the environment, creates volumes, and starts services
- **update.sh**: Updates Python scripts in the Docker container
- **restart.sh**: Restarts specific services
- **status.sh**: Checks the status of all services
- **cleanup.sh**: Stops containers, removes volumes, and cleans up

## Updating Python Scripts

If you modify any Python scripts in the `short-story/scripts/` directory, update them in the Docker container:

For Windows:

```batch
powershell -ExecutionPolicy Bypass -File .\update.ps1
```

For Linux:

```bash
./update.sh
```

## Troubleshooting

### Services Show as Unhealthy

If services show as unhealthy, try:

1. Restart the affected service:

   ```bash
   # Windows
   .\restart.bat [service_name]

   # Linux
   ./restart.sh [service_name]
   ```

2. Check the service logs for errors:
   ```bash
   docker logs [container_name]
   ```

### GPU Issues

If you experience GPU-related issues:

1. Verify your GPU is recognized by the host system:

   ```bash
   # For NVIDIA
   nvidia-smi

   # For Intel
   intel_gpu_top

   # For AMD
   rocm-smi
   ```

2. Check if the container can access the GPU:

   ```bash
   docker exec -it workflows ls -la /dev/dri
   ```

3. For NVIDIA GPU, verify the NVIDIA Container Toolkit is properly installed:
   ```bash
   docker info | grep -i runtime
   ```

### MinIO Connection Issues

If the NCA Toolkit can't connect to MinIO, verify:

1. MinIO is running and healthy:

   ```bash
   docker ps --filter "name=minio" --filter "health=healthy"
   ```

2. The bucket exists:

   ```bash
   # Windows
   .\mc.exe ls myminio/

   # Linux
   ./mc ls myminio/
   ```

3. Your .env file has the correct credentials.

## License

MIT License

## About the Services

### MinIO

MinIO is an open-source, S3-compatible object storage solution with:

- High-performance optimization for any workload
- 100% compatibility with Amazon S3 API
- Encryption, identity management, and object locking
- Scalability from terabytes to exabytes

### NCA Toolkit

The No-Code Architects Toolkit provides tools for creating and managing content without coding.

### Workflows (n8n)

n8n is a workflow automation tool that connects various applications and services, with custom Python scripts for video processing.

### Kokoro TTS

Kokoro TTS is a Text-to-Speech service that generates natural-sounding speech from text.
