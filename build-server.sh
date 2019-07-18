#!/usr/bin/env bash

IMAGE_OWNER="${IMAGE_OWNER:-dubodubonduponey}"
IMAGE_NAME="${IMAGE_NAME:-roon-server}"
IMAGE_VERSION="${IMAGE_VERSION:-v1}"
PLATFORMS="${PLATFORMS:-linux/amd64}" # Just amd64

export DOCKER_CONTENT_TRUST=1
export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx create --name "$IMAGE_NAME"
docker buildx use "$IMAGE_NAME"
docker buildx build --platform "$PLATFORMS" -t "$IMAGE_OWNER/$IMAGE_NAME:$IMAGE_VERSION" -f Dockerfile.server --push .
