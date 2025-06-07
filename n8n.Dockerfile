# n8n.Dockerfile
FROM docker.n8n.io/n8nio/n8n

# Switch to root to install packages
USER root

# Install Python, pip, ffmpeg, and dependencies
# Note: Package names adjusted for Alpine Linux availability
RUN apk add --update python3 py3-pip gcc python3-dev musl-dev curl ffmpeg yt-dlp

# Install boto3 for S3/MinIO uploads
RUN pip3 install --no-cache-dir --break-system-packages moviepy a4f-local

# Create a directory for scripts and copy them
RUN mkdir -p /opt/scripts
COPY ./short-story/scripts/ /opt/scripts/

# Make scripts executable
RUN chmod +x /opt/scripts/*.py
RUN chmod +x /opt/scripts/*.sh 2>/dev/null || true

# Create output directories for videos
RUN mkdir -p /files/video_chunks /files/temp_processing_clips /files/processed_audio /files/output_shorts_clips /files/downloads && \
    chmod -R 777 /files

USER node
