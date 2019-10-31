##########################
# Building image bridge
##########################
FROM          dubodubonduponey/base:builder                                   AS builder-bridge

WORKDIR       /dist

# Install dependencies and tools: bridge
RUN           apt-get install -y --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1  > /dev/null

COPY          "./cache/$TARGETPLATFORM/bridge.tar.bz2" .
RUN           tar -xjf bridge.tar.bz2

RUN           /dist/RoonBridge/check.sh

##########################
# Building image server
##########################
FROM          dubodubonduponey/base:builder                                   AS builder-server

WORKDIR       /dist

# Install dependencies and tools: bridge
RUN           apt-get install -y --no-install-recommends \
                bzip2=1.0.6-9.2~deb10u1 \
                libasound2=1.1.8-1 \
                ffmpeg=7:4.1.4-1~deb10u1 \
                cifs-utils=2:6.8-2 > /dev/null

COPY          "./cache/linux/amd64/server.tar.bz2" .
RUN           tar -xjf server.tar.bz2

RUN           /dist/RoonServer/check.sh
RUN           ln -s /boot/RoonMono/bin/mono-sgen /dist/RoonServer/RoonMono/bin/RAATServer
RUN           ln -s /boot/RoonMono/bin/mono-sgen /dist/RoonServer/RoonMono/bin/RoonAppliance
RUN           ln -s /boot/RoonMono/bin/mono-sgen /dist/RoonServer/RoonMono/bin/RoonServer

#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder         AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/bin/http-health ./cmd/http

RUN           chmod 555 /dist/bin/*

#######################
# Running image bridge
#######################
FROM        dubodubonduponey/base:runtime                                     AS runtime-bridge

USER        root

ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update              > /dev/null && \
            apt-get install -y --no-install-recommends libasound2=1.1.8-1 \
                                        > /dev/null && \
            apt-get -y autoremove       > /dev/null && \
            apt-get -y clean            && \
            rm -rf /var/lib/apt/lists/* && \
            rm -rf /tmp/*               && \
            rm -rf /var/tmp/*

USER        dubo-dubon-duponey

WORKDIR     /boot

COPY        --from=builder-bridge       /dist/RoonBridge .
# COPY        --from=builder-healthcheck  /dist/bin/http-health ./bin/

ENV         ROON_DATAROOT /data
ENV         ROON_ID_DIR /data

EXPOSE      9003/udp
EXPOSE      9100-9110/tcp

VOLUME      /data
VOLUME      /tmp

#######################
# Running image server
#######################
FROM        dubodubonduponey/base:runtime                                     AS runtime-server

USER        root

ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update              > /dev/null && \
            apt-get install -y --no-install-recommends libasound2=1.1.8-1 ffmpeg=7:4.1.4-1~deb10u1 \
                                        > /dev/null && \
            apt-get -y autoremove       > /dev/null && \
            apt-get -y clean            && \
            rm -rf /var/lib/apt/lists/* && \
            rm -rf /tmp/*               && \
            rm -rf /var/tmp/*

USER        dubo-dubon-duponey

WORKDIR     /boot

COPY        --from=builder-server       /dist/RoonServer .
COPY        --from=builder-healthcheck  /dist/bin/http-health ./bin/

ENV         ROON_DATAROOT /data
ENV         ROON_ID_DIR /data

EXPOSE      9003/udp
EXPOSE      9100-9110/tcp

VOLUME      /data
VOLUME      /tmp
VOLUME      /music

ENV         PATH=/boot/bin:$PATH

ENV         HEALTHCHECK_URL=http://127.0.0.1:9100/healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
