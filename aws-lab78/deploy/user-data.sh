#!/bin/bash
set -euo pipefail

dnf install -y docker
systemctl enable --now docker
image='${image}'
registry=$(printf '%s' "$image" | cut -d/ -f1)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$registry"
docker pull "$image"
docker run -d --name lab78-flask --restart unless-stopped -p 80:8080 "$image"
docker logout "$registry"
