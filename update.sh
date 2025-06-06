#!/bin/bash

# Shell script to update Python scripts in the Docker container
echo "Updating scripts in the Docker container..."

# Ensure /opt/scripts exists in the container
docker exec workflows mkdir -p /opt/scripts/

# Copy the updated scripts to the container
docker cp short-story/scripts/video_splitter.py workflows:/opt/scripts/video_splitter.py
docker cp short-story/scripts/clip_cutter.py workflows:/opt/scripts/clip_cutter.py
docker cp short-story/scripts/a4f-local.py workflows:/opt/scripts/a4f-local.py

# Make scripts executable in the container
docker exec workflows chmod +x /opt/scripts/*.py

echo "Scripts updated successfully!" 