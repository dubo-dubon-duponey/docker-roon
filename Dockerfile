#######################
# Extra builder for healthchecker
#######################
ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/http-health ./cmd/http

##########################
# Building image bridge
##########################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder-bridge

# Install dependencies and tools: bridge
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1

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
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder-server

# Install dependencies and tools: bridge
RUN           apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1 \
                ffmpeg=7:4.1.4-1~deb10u1 \
                cifs-utils=2:6.8-2

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
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE                                                                                             AS runtime-bridge

USER          root

ARG           DEBIAN_FRONTEND="noninteractive"
# XXX this is possibly not necessary, as roon apparently is able to adress the device directly
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.1.8-1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder-bridge --chown=$BUILD_UID:root /dist .

ENV           ROON_DATAROOT /data
ENV           ROON_ID_DIR /data

VOLUME        /data
VOLUME        /tmp

#######################
# Running image server
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE                                                                                             AS runtime-server

USER          root

# Removing this will prevent the RoonServer from using audio devices, hence making the use of RaatBridges mandatory (which is fine)
#                libasound2=1.1.8-1 \
ARG           DEBIAN_FRONTEND="noninteractive"
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                ffmpeg=7:4.1.4-1~deb10u1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder-server --chown=$BUILD_UID:root /dist .

ENV           ROON_DATAROOT /data
ENV           ROON_ID_DIR /data

EXPOSE        9003/udp
EXPOSE        9100-9110/tcp

VOLUME        /data
VOLUME        /tmp
VOLUME        /music

ENV           HEALTHCHECK_URL=http://127.0.0.1:9100/healthcheck

HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
