ARG           FROM_IMAGE_BUILDER=ghcr.io/dubo-dubon-duponey/base:builder-bullseye-2021-06-01@sha256:addbd9b89d8973df985d2d95e22383961ba7b9c04580ac6a7f406a3a9ec4731e
ARG           FROM_IMAGE_RUNTIME=ghcr.io/dubo-dubon-duponey/base:runtime-bullseye-2021-06-01@sha256:a2b1b2f69ed376bd6ffc29e2d240e8b9d332e78589adafadb84c73b778e6bc77

#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM $FROM_IMAGE_BUILDER                                                             AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8c
ARG           GIT_COMMIT=51ebf8ca3d255e0c846307bf72740f731e6210c3
ARG           GO_BUILD_SOURCE=./cmd/http
ARG           GO_BUILD_OUTPUT=http-health
ARG           GO_LD_FLAGS="-s -w"
ARG           GO_TAGS="netgo osusergo"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"
ARG           GOOS="$TARGETOS"
ARG           GOARCH="$TARGETARCH"

# hadolint ignore=SC2046
RUN           env GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)" go build -trimpath $(if [ "$CGO_ENABLED" = 1 ]; then printf "%s" "-buildmode pie"; fi) \
                -ldflags "$GO_LD_FLAGS" -tags "$GO_TAGS" -o /dist/boot/bin/"$GO_BUILD_OUTPUT" "$GO_BUILD_SOURCE"

##########################
# Building image bridge
##########################
FROM          $FROM_IMAGE_BUILDER                                                                                       AS builder-bridge

# Install dependencies and tools: bridge
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.8-4 \
                libasound2=1.2.4-1.1

WORKDIR       /dist/boot/bin
COPY          "./cache/$TARGETPLATFORM/bridge.tar.bz2" .
RUN           tar -xjf bridge.tar.bz2
RUN           rm bridge.tar.bz2
RUN           ./RoonBridge/check.sh

# XXX see note in shairport-sync
#WORKDIR       /dist/boot/lib/
#RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

##########################
# Building image server
##########################
FROM          $FROM_IMAGE_BUILDER                                                                                       AS builder-server

# Install dependencies and tools: bridge
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.8-4 \
                libasound2=1.2.4-1.1 \
                ffmpeg=7:4.3.2-0+deb11u1 \
                cifs-utils=2:6.11-3

WORKDIR       /dist/boot/bin
COPY          "./cache/linux/amd64/server.tar.bz2" .
RUN           tar -xjf server.tar.bz2
RUN           rm server.tar.bz2
RUN           ./RoonServer/check.sh

RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RAATServer
RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonAppliance
RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonServer

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin

# XXX see note in shairport-sync
#WORKDIR       /dist/boot/lib/
#RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

#######################
# Running image bridge
#######################
FROM          $FROM_IMAGE_RUNTIME                                                                                       AS runtime-bridge

USER          root

# XXX this is possibly not necessary, as roon apparently is able to adress the device directly
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.2.4-1.1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder-bridge --chown=$BUILD_UID:root /dist /

ENV           ROON_DATAROOT=/data
ENV           ROON_ID_DIR=/data

VOLUME        /data
VOLUME        /tmp

#######################
# Running image server
#######################
FROM          $FROM_IMAGE_RUNTIME                                                                                       AS runtime-server

USER          root

# Removing this will prevent the RoonServer from using audio devices, hence making the use of RaatBridges mandatory (which is fine)
#                libasound2=1.2.4-1.1 \
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                ffmpeg=7:4.3.2-0+deb11u1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder-server --chown=$BUILD_UID:root /dist /

ENV           ROON_DATAROOT=/data
ENV           ROON_ID_DIR=/data

EXPOSE        9003/udp
EXPOSE        9100-9110/tcp

VOLUME        /data
VOLUME        /tmp
VOLUME        /music

ENV           HEALTHCHECK_URL=http://127.0.0.1:9100/healthcheck

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
