#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/http-health ./cmd/http

##########################
# Building image bridge
##########################
FROM          dubodubonduponey/base:builder                                                                             AS builder-bridge

# Install dependencies and tools: bridge
RUN           apt-get install -qq --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1

WORKDIR       /dist/boot/bin
COPY          "./cache/$TARGETPLATFORM/bridge.tar.bz2" .
RUN           tar -xjf bridge.tar.bz2
RUN           ./RoonBridge/check.sh

WORKDIR       /dist/boot/lib/
RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

##########################
# Building image server
##########################
FROM          dubodubonduponey/base:builder                                                                             AS builder-server

# Install dependencies and tools: bridge
RUN           apt-get install -qq --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1 \
                ffmpeg=7:4.1.4-1~deb10u1 \
                cifs-utils=2:6.8-2

WORKDIR       /dist/boot/bin
COPY          "./cache/linux/amd64/server.tar.bz2" .
RUN           tar -xjf server.tar.bz2
RUN           ./RoonServer/check.sh

RUN           ln -s /boot/bin/RoonMono/bin/mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RAATServer
RUN           ln -s /boot/bin/RoonMono/bin/mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonAppliance
RUN           ln -s /boot/bin/RoonMono/bin/mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonServer

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin

WORKDIR       /dist/boot/lib/
RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

#######################
# Running image bridge
#######################
FROM          dubodubonduponey/base:runtime                                                                             AS runtime-bridge

COPY          --from=builder-bridge --chown=$BUILD_UID:root /dist .

ENV           ROON_DATAROOT /data
ENV           ROON_ID_DIR /data

EXPOSE        9003/udp
EXPOSE        9100-9110/tcp

VOLUME        /data
VOLUME        /tmp

#######################
# Running image server
#######################
FROM          dubodubonduponey/base:runtime                                                                             AS runtime-server

USER          root

ARG           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN           apt-get update -qq          && \
              apt-get install -qq --no-install-recommends ffmpeg=7:4.1.4-1~deb10u1 \
                                        && \
              apt-get -qq autoremove       && \
              apt-get -qq clean            && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

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
