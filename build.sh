#!/usr/bin/env bash

IMAGE_OWNER=${IMAGE_OWNER:-dubodubonduponey}
IMAGE_VERSION=v1

export DOCKER_CLI_EXPERIMENTAL=enabled
docker buildx create --name "roon"
docker buildx use "roon"

docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -f Dockerfile.bridge -t "$IMAGE_OWNER/roon-bridge:$IMAGE_VERSION" --push .
docker buildx build --platform linux/amd64 -f Dockerfile.server -t "$IMAGE_OWNER/roon-server:$IMAGE_VERSION" --push .
