#!/usr/bin/env bash

# Build parameters

# Specific to this image
TITLE_BRIDGE="Roon Bridge"
DESCRIPTION_BRIDGE="A dubo image for Roon Bridge"
IMAGE_NAME_BRIDGE="roon-bridge"

TITLE_SERVER="Roon Server"
DESCRIPTION_SERVER="A dubo image for Roon Server"
IMAGE_NAME_SERVER="roon-server"

# Registry configuration, with defaults
REGISTRY="${REGISTRY:-registry-1.docker.io}"
VENDOR="${VENDOR:-dubodubonduponey}"
IMAGE_TAG="${IMAGE_TAG:-v1}"

# Configurable, with sane defaults for this image
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}" # No v6

# Behavioral overrides
[ "$NO_PUSH" ] || PUSH=--push
[ ! "$NO_CACHE" ] || CACHE=--no-cache

# Automated metadata
LICENSE="$(head -n 1 LICENSE)"
# https://tools.ietf.org/html/rfc3339
# XXX it doesn't seem like BSD date can format the timezone appropriately according to RFC3339 - eg: %:z doesn't work and %z misses the colon, so the gymnastic here
DATE="$(date +%Y-%m-%dT%T%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
VERSION="$(git describe --match 'v[0-9]*' --dirty='.m' --always)"
REVISION="$(git rev-parse HEAD)$(if ! git diff --no-ext-diff --quiet --exit-code; then printf ".m\\n"; fi)"
# XXX this is dirty, resolve ssh aliasing to github by default
URL="$(git remote show -n origin | grep "Fetch URL")"
URL="${URL#*Fetch URL: }"
URL="$(printf "%s" "$URL"| sed -E 's,.git$,,' | sed -E 's,^[a-z-]+:([^/]),https://github.com/\1,')"
DOCUMENTATION="$URL/blob/1/README.md"
SOURCE="$URL/tree/1"

# Docker settings
export DOCKER_CONTENT_TRUST=1
export DOCKER_CLI_EXPERIMENTAL=enabled

docker::version_check(){
  dv="$(docker version | grep "^ Version")"
  dv="${dv#*:}"
  dv="${dv##* }"
  if [ "${dv%%.*}" -lt "19" ]; then
    >&2 printf "Docker is too old and doesn't support buildx. Failing!\n"
    return 1
  fi
}

build::setup(){
  docker buildx create --node "dubo-dubon-duponey-building-0" --name "dubo-dubon-duponey-building"
  docker buildx use "dubo-dubon-duponey-building"
}

docker::version_check || exit 1
build::setup

docker buildx build --pull --platform "$PLATFORMS" \
  --build-arg="BUILD_CREATED=$DATE" \
  --build-arg="BUILD_URL=$URL" \
  --build-arg="BUILD_DOCUMENTATION=$DOCUMENTATION" \
  --build-arg="BUILD_SOURCE=$SOURCE" \
  --build-arg="BUILD_VERSION=$VERSION" \
  --build-arg="BUILD_REVISION=$REVISION" \
  --build-arg="BUILD_VENDOR=$VENDOR" \
  --build-arg="BUILD_LICENSES=$LICENSE" \
  --build-arg="BUILD_REF_NAME=$REGISTRY/$VENDOR/$IMAGE_NAME_BRIDGE:$IMAGE_TAG" \
  --build-arg="BUILD_TITLE=$TITLE_BRIDGE" \
  --build-arg="BUILD_DESCRIPTION=$DESCRIPTION_BRIDGE" \
  --target runtime-bridge \
  -t "$REGISTRY/$VENDOR/$IMAGE_NAME_BRIDGE:$IMAGE_TAG" ${CACHE} ${PUSH} "$@" .

docker buildx build --pull --platform "linux/amd64" \
  --build-arg="BUILD_CREATED=$DATE" \
  --build-arg="BUILD_URL=$URL" \
  --build-arg="BUILD_DOCUMENTATION=$DOCUMENTATION" \
  --build-arg="BUILD_SOURCE=$SOURCE" \
  --build-arg="BUILD_VERSION=$VERSION" \
  --build-arg="BUILD_REVISION=$REVISION" \
  --build-arg="BUILD_VENDOR=$VENDOR" \
  --build-arg="BUILD_LICENSES=$LICENSE" \
  --build-arg="BUILD_REF_NAME=$REGISTRY/$VENDOR/$IMAGE_NAME_SERVER:$IMAGE_TAG" \
  --build-arg="BUILD_TITLE=$TITLE_SERVER" \
  --build-arg="BUILD_DESCRIPTION=$DESCRIPTION_SERVER" \
  --target runtime-server \
  -t "$REGISTRY/$VENDOR/$IMAGE_NAME_SERVER:$IMAGE_TAG" ${CACHE} ${PUSH} "$@" .
