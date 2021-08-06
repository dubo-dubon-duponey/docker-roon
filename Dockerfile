ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-08-01@sha256:f492d8441ddd82cad64889d44fa67cdf3f058ca44ab896de436575045a59604c
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-08-01@sha256:a9adfa210235133d99bf06fab9a631cd6d44ee3aed6b081ad61b342fcc7d189c
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-08-01@sha256:edc80b2c8fd94647f793cbcb7125c87e8db2424f16b9fd0b8e173af850932b48
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-08-01@sha256:87ec12fe94a58ccc95610ee826f79b6e57bcfd91aaeb4b716b0548ab7b2408a7

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

##########################
# Building image bridge
##########################
FROM          $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                                                        AS builder-bridge

ARG           TARGETPLATFORM
ARG           TARGETARCH
ARG           TARGETVARIANT

# Install dependencies and tools: bridge
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.8-4 \
                libasound2=1.2.4-1.1

WORKDIR       /dist/boot/bin
COPY          "./cache/$TARGETPLATFORM/bridge.tar.bz2" .
RUN           tar -xjf bridge.tar.bz2
RUN           rm bridge.tar.bz2
RUN           ./RoonBridge/check.sh

RUN           mkdir -p /dist/boot/lib; \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")")"; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libasound.so.2  /dist/boot/lib

##########################
# Building image server
##########################
# Better solution would be to move to auditor
FROM          $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                                                        AS builder-server

# Install dependencies and tools: bridge
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                bzip2=1.0.8-4 \
                libasound2=1.2.4-1.1 \
                ffmpeg=7:4.3.2-0+deb11u2 \
                cifs-utils=2:6.11-3

WORKDIR       /dist/boot/bin
COPY          "./cache/linux/amd64/server.tar.bz2" .
RUN           tar -xjf server.tar.bz2
RUN           rm server.tar.bz2
RUN           ./RoonServer/check.sh

RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RAATServer
RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonAppliance
RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonServer

# XXX see note in shairport-sync
#WORKDIR       /dist/boot/lib/
#RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

#######################
# Running image bridge
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime-bridge

COPY          --from=builder-bridge /usr/share/alsa /usr/share/alsa
COPY          --from=builder-bridge --chown=$BUILD_UID:root /dist /

ENV           ROON_DATAROOT=/data/data_root
ENV           ROON_ID_DIR=/data/id_dir

VOLUME        /data
VOLUME        /tmp

#######################
# Builder assembly for server
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS builder

COPY          --from=builder-server   /dist/boot/bin           /dist/boot/bin

COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/goello-server  /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image server
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime-server

USER          root

# Removing this will prevent the RoonServer from using audio devices, hence making the use of RaatBridges mandatory (which is fine)
#                libasound2=1.2.4-1.1 \
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                ffmpeg=7:4.3.2-0+deb11u2 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

ENV           ROON_DATAROOT=/data/data_root
ENV           ROON_ID_DIR=/data/id_dir
EXPOSE        9003/udp
VOLUME        /music

ENV           NICK="roon"

COPY          --from=builder --chown=$BUILD_UID:root /dist /

### Front server configuration
# Port to use
ENV           PORT=4443
ENV           PORT_HTTP=80
EXPOSE        4443
EXPOSE        80
# Log verbosity for
ENV           LOG_LEVEL="warn"
# Domain name to serve
ENV           DOMAIN="$NICK.local"
ENV           ADDITIONAL_DOMAINS=""

# Whether the server should behave as a proxy (disallows mTLS)
ENV           SERVER_NAME="DuboDubonDuponey/1.0 (Caddy/2) [$NICK]"

# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           TLS="internal"
# 1.2 or 1.3
ENV           TLS_MIN=1.2
# Either require_and_verify or verify_if_given
ENV           TLS_MTLS_MODE="verify_if_given"
# Issuer name to appear in certificates
#ENV           TLS_ISSUER="Dubo Dubon Duponey"
# Either disable_redirects or ignore_loaded_certs if one wants the redirects
ENV           TLS_AUTO=disable_redirects

ENV           AUTH_ENABLED=false
# Realm in case access is authenticated
ENV           AUTH_REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           AUTH_USERNAME="dubo-dubon-duponey"
ENV           AUTH_PASSWORD="cmVwbGFjZV9tZV93aXRoX3NvbWV0aGluZwo="

### mDNS broadcasting
# Enable/disable mDNS support
ENV           MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MDNS_NAME="$NICK mDNS display name"
# The service will be annonced and reachable at $MDNS_HOST.local
ENV           MDNS_HOST="$NICK"
# Type to advertise
ENV           MDNS_TYPE="_http._tcp"

# Caddy certs will be stored here
VOLUME        /certs

# Caddy uses this
VOLUME        /tmp

# Used by the backend service
VOLUME        /data

ENV           HEALTHCHECK_URL="http://127.0.0.1:10000/?healthcheck"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
