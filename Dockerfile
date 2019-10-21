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

COPY        --from=builder-bridge /dist/RoonBridge .

ENV         ROON_DATAROOT /data
ENV         ROON_ID_DIR /data

EXPOSE      9003/udp
EXPOSE      9100-9200/tcp

VOLUME      /data

ENTRYPOINT  ["./Bridge/RoonBridge"]


# TODO: healthcheck - check the volume - move to readonly and finally spot the issue with identifiers


# HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD dnsgrpc dev-null.farcloser.world || exit 1
# CMD dig @127.0.0.1 healthcheck.farcloser.world || exit 1

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

COPY        --from=builder-server /dist/RoonServer .

ENV         ROON_DATAROOT /data
ENV         ROON_ID_DIR /data

EXPOSE      9003/udp
EXPOSE      9100-9200/tcp

# TCP/IP Port 52667 / TCP/IP Port 52709 / TCP/IP Ports 63098-63100 and TCP/IP Port 49863
VOLUME      /data
VOLUME      /music

ENTRYPOINT  ["./Server/RoonServer"]
