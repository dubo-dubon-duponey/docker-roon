ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_FETCHER=base:golang-bookworm-2024-03-01
ARG           FROM_IMAGE_BUILDER=base:builder-bookworm-2024-03-01
ARG           FROM_IMAGE_AUDITOR=base:auditor-bookworm-2024-03-01
ARG           FROM_IMAGE_TOOLS=tools:linux-bookworm-2024-03-01
ARG           FROM_IMAGE_RUNTIME=base:runtime-bookworm-2024-03-01

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-caddy

ARG           GIT_REPO=github.com/caddyserver/caddy
# Works until < go1.8
#ARG           GIT_VERSION=v2.4.3
#ARG           GIT_COMMIT=9d4ed3a3236df06e54c80c4f6633b66d68ad3673
# 2.4.5 need tweak to scep (minor version bump), but then the build segfaults
# 2.4.6 segfaults
#ARG           GIT_VERSION=v2.4.6
#ARG           GIT_COMMIT=e7457b43e4703080ae8713ada798ce3e20b83690
#ARG           GIT_VERSION=v2.5.2
#ARG           GIT_COMMIT=ad3a83fb9169899226ce12a61c16b5bf4d03c482
ARG           GIT_VERSION=v2.7.6
ARG           GIT_COMMIT=6d9a83376b5e19b3c0368541ee46044ab284038b

ENV           WITH_BUILD_SOURCE="./cmd/caddy"
ENV           WITH_BUILD_OUTPUT="caddy"

ENV           CGO_ENABLED=1
#ENV           ENABLE_STATIC=true

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

# scep v2.0.0 checksum does not match anymore
# It's unclear whether the rename of the module to v2 is responsible, but one way or the other this
# *critical* module is suspicious
# RUN           echo "replace github.com/micromdm/scep/v2 v2.0.0 => github.com/micromdm/scep/v2 v2.1.0" >> go.mod

ARG           GIT_REPO_REPLACE=github.com/caddyserver/replace-response
#ARG           GIT_VERSION_REPLACE=8fa6a90
#ARG           GIT_COMMIT_REPLACE=8fa6a90147d10fa192ad9fd1df2b97c1844ed322
ARG           GIT_VERSION=a85d4dd
ARG           GIT_COMMIT_REPLACE=a85d4ddc11d635c093074205bd32f56d05fc7811

RUN           echo "require $GIT_REPO_REPLACE $GIT_COMMIT_REPLACE" >> go.mod

# hadolint ignore=DL3045
COPY          build/main.go ./cmd/caddy/main.go

RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=NETRC \
              go mod tidy -compat=1.17; \
              [[ "${GOFLAGS:-}" == *-mod=vendor* ]] || go mod download

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM fetcher-caddy                                                                    AS builder-caddy

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT
ENV           GOOS=$TARGETOS
ENV           GOARCH=$TARGETARCH

ENV           CGO_CFLAGS="${CFLAGS:-} ${ENABLE_PIE:+-fPIE}"
ENV           GOFLAGS="-trimpath ${ENABLE_PIE:+-buildmode=pie} ${GOFLAGS:-}"

RUN           export GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)"; \
              [ "${CGO_ENABLED:-}" != 1 ] || { \
                eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
                export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
                export AR="${DEB_TARGET_GNU_TYPE}-ar"; \
                export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
                export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
                [ ! "${ENABLE_STATIC:-}" ] || { \
                  [ ! "${WITH_CGO_NET:-}" ] || { \
                    ENABLE_STATIC=; \
                    LDFLAGS="${LDFLAGS:-} -static-libgcc -static-libstdc++"; \
                  }; \
                  [ "$GOARCH" == "amd64" ] || [ "$GOARCH" == "arm64" ] || [ "${ENABLE_PIE:-}" != true ] || ENABLE_STATIC=; \
                }; \
                WITH_LDFLAGS="${WITH_LDFLAGS:-} -linkmode=external -extld="$CC" -extldflags \"${LDFLAGS:-} ${ENABLE_STATIC:+-static}${ENABLE_PIE:+-pie}\""; \
                WITH_TAGS="${WITH_TAGS:-} cgo ${ENABLE_STATIC:+static static_build}"; \
              }; \
              go build -ldflags "-s -w -v ${WITH_LDFLAGS:-}" -tags "${WITH_TAGS:-} net${WITH_CGO_NET:+c}go osusergo" -o /dist/boot/bin/"$WITH_BUILD_OUTPUT" "$WITH_BUILD_SOURCE"

##########################
# Bridge: builder
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
                bzip2=1.0.8-5+b1 \
                libasound2=1.2.8-1+b1
              # \
#                libicu67=67.1-7

WORKDIR       /dist/boot/bin
COPY          "./cache/$TARGETPLATFORM/bridge.tar.bz2" .
RUN           tar -xjf bridge.tar.bz2
RUN           rm bridge.tar.bz2
RUN           ./RoonBridge/check.sh

RUN           sed -i "s/\-\-debug//g" RoonBridge/Bridge/RAATServer
RUN           sed -i "s/\-\-debug//g" RoonBridge/Bridge/RoonBridgeHelper
RUN           sed -i "s/\-\-debug//g" RoonBridge/Bridge/RoonBridge

# XXX do we NEED libasound?
RUN           mkdir -p /dist/boot/lib; \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libasound.so.2  /dist/boot/lib

#######################
# Bridge: assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly-bridge

COPY          --from=builder-bridge /dist/boot      /dist/boot
COPY          --from=builder-bridge /usr/share/alsa /dist/usr/share/alsa

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Bridge: runtime
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime-bridge

COPY          --from=assembly-bridge --chown=$BUILD_UID:root  /dist /

# XXX LD_LIBRARY_PATH are a liability when mixed with caps - so, watch out
# Alternative is rpathing, but what exactly?
ENV           LD_LIBRARY_PATH=/boot/lib

ENV           ROON_DATAROOT=/data/data_root
ENV           ROON_ID_DIR=/data/id_dir

VOLUME        /data
VOLUME        /tmp

##########################
# Building image server
##########################
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
                bzip2=1.0.8-5+b1 \
                libasound2=1.2.8-1+b1 \
                ffmpeg=7:5.1.4-0+deb12u1 \
                cifs-utils=2:7.0-2

WORKDIR       /dist/boot/bin
COPY          "./cache/linux/amd64/server.tar.bz2" .
RUN           tar -xjf server.tar.bz2
RUN           rm server.tar.bz2

RUN           ln -s dotnet /dist/boot/bin/RoonServer/RoonDotnet/RoonServer
RUN           ln -s dotnet /dist/boot/bin/RoonServer/RoonDotnet/RoonAppliance
RUN           ln -s dotnet /dist/boot/bin/RoonServer/RoonDotnet/RAATServer

RUN           ./RoonServer/check.sh
#RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RAATServer
#RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonAppliance
#RUN           ln -s mono-sgen /dist/boot/bin/RoonServer/RoonMono/bin/RoonServer

#######################
# Builder assembly for server
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly

ARG           TARGETARCH

COPY          --from=builder-server /dist/boot              /dist/boot

COPY          --from=builder-caddy  /dist/boot/bin/caddy    /dist/boot/bin
#COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/goello-server-ng /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health   /dist/boot/bin

RUN           setcap 'cap_net_bind_service+ep'              /dist/boot/bin/caddy

# XXX dubo-check currently does not avoid directories - fixed upstream
RUN           RUNNING=true \
                dubo-check validate /dist/boot/bin/caddy; \
                dubo-check validate /dist/boot/bin/goello-server-ng; \
                dubo-check validate /dist/boot/bin/http-health

RUN           STATIC=true \
                dubo-check validate /dist/boot/bin/goello-server-ng; \
                dubo-check validate /dist/boot/bin/http-health

RUN           RO_RELOCATIONS=true \
                dubo-check validate /dist/boot/bin/caddy

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image server
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME                                                                        AS runtime-server

USER          root

# Removing this will prevent the RoonServer from using audio devices, hence making the use of RaatBridges mandatory (which is fine)
#                libasound2=1.2.8-1+b1 \
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                ffmpeg=7:5.1.4-0+deb12u1 \
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

ENV           _SERVICE_NICK="roon"
ENV           _SERVICE_TYPE="_http._tcp"

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

#####
# Global
#####
# Log verbosity (debug, info, warn, error, fatal)
ENV           LOG_LEVEL="warn"

#####
# Mod mDNS
#####
# Whether to disable mDNS broadcasting or not
ENV           MOD_MDNS_ENABLED=true
# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="$_SERVICE_NICK display name"
# The service will be annonced and reachable at MOD_MDNS_HOST.local
ENV           MOD_MDNS_HOST="$_SERVICE_NICK"

#####
# Mod mTLS
#####
# Whether to enable client certificate validation or not
ENV           MOD_MTLS_ENABLED=false
# Either require_and_verify or verify_if_given
ENV           MOD_MTLS_MODE="verify_if_given"

#####
# Mod Basic Auth
#####
# Whether to enable basic auth
ENV           MOD_BASICAUTH_ENABLED=false
# Realm displayed for auth
ENV           MOD_BASICAUTH_REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           MOD_BASICAUTH_USERNAME="dubo-dubon-duponey"
ENV           MOD_BASICAUTH_PASSWORD="cmVwbGFjZV9tZV93aXRoX3NvbWV0aGluZwo="

#####
# Mod HTTP
#####
# Whether to disable the HTTP mod altogether
ENV           MOD_HTTP_ENABLED=true
# Domain name to serve
ENV           DOMAIN="$_SERVICE_NICK.local"
# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           MOD_HTTP_TLS_MODE="internal"

#####
# Advanced settings
#####
# Service type
ENV           ADVANCED_MOD_MDNS_TYPE="$_SERVICE_TYPE"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           ADVANCED_MOD_MDNS_STATION=true
# Root certificate to trust for client cert verification
ENV           ADVANCED_MOD_MTLS_TRUST="/certs/pki/authorities/local/root.crt"
# Ports for http and https - recent changes in docker make it no longer necessary to have caps, plus we have our NET_BIND_SERVICE cap set anyhow - it's 2021, there is no reason to keep on venerating privileged ports
ENV           ADVANCED_MOD_HTTP_PORT=443
ENV           ADVANCED_MOD_HTTP_PORT_INSECURE=80
# By default, tls should be restricted to 1.3 - you may downgrade to 1.2+ for compatibility with older clients (webdav client on macos, older browsers)
ENV           ADVANCED_MOD_HTTP_TLS_MIN=1.3
# Name advertised by Caddy in the server http header
ENV           ADVANCED_MOD_HTTP_SERVER_NAME="DuboDubonDuponey/1.0 (Caddy/2)"
# ACME server to use (for testing)
# Staging
# https://acme-staging-v02.api.letsencrypt.org/directory
# Plain
# https://acme-v02.api.letsencrypt.org/directory
# PKI
# https://pki.local
ENV           ADVANCED_MOD_HTTP_TLS_SERVER="https://acme-v02.api.letsencrypt.org/directory"
# Either disable_redirects or ignore_loaded_certs if one wants the redirects
ENV           ADVANCED_MOD_HTTP_TLS_AUTO=disable_redirects
# Whether to disable TLS and serve only plain old http
ENV           ADVANCED_MOD_HTTP_TLS_ENABLED=true
# Additional domains aliases
ENV           ADVANCED_MOD_HTTP_ADDITIONAL_DOMAINS=""

#####
# Wrap-up
#####
EXPOSE        443
EXPOSE        80

# Caddy certs will be stored here
VOLUME        /certs
# Caddy uses this
VOLUME        /tmp
# Used by the backend service
VOLUME        /data

ENV           HEALTHCHECK_URL="http://127.0.0.1:10000/?healthcheck"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1


# Roon is moving to MS
# See https://docs.microsoft.com/en-us/dotnet/core/install/linux-debian
# https://help.roonlabs.com/portal/en/kb/articles/linux-performance-improvements#Join_the_beta

# We may be missing:
#libgcc1
#libgssapi-krb5-2

