#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

helpers::dir::writable(){
  local path="$1"
  local create="${2:-}"
  # shellcheck disable=SC2015
  ( [ ! "$create" ] || mkdir -p "$path" 2>/dev/null ) && [ -w "$path" ] && [ -d "$path" ] || {
    printf >&2 "%s does not exist, is not writable, or cannot be created. Check your mount permissions.\n" "$path"
    exit 1
  }
}

run::hash(){
  printf >&2 "Generating password hash\n"
  caddy hash-password -algorithm bcrypt "$@"
}

run::certificate(){
  local tls_mode="$1"
  printf >&2 "Displaying root certificate to trust\n"
  if [ "$tls_mode" == "" ]; then
    printf >&2 "Your container is not configured for TLS termination - there is no local CA in that case."
    exit 1
  fi
  if [ "$tls_mode" != "internal" ]; then
    printf >&2 "Your container uses letsencrypt - there is no local CA in that case."
    exit 1
  fi
  if [ ! -e /certs/pki/authorities/local/root.crt ]; then
    printf >&2 "No root certificate installed or generated. Run the container so that a cert is generated, or provide one at runtime."
    exit 1
  fi
  cat /certs/pki/authorities/local/root.crt
}

start::sidecar(){
  local disable_tls=""
  local disable_mtls=""
  local disable_auth=""

  AUTH="${AUTH:-}"
  TLS="${TLS:-}"
  MTLS="${MTLS:-}"

  local secure=s

  [ "$MTLS" != "" ] || disable_mtls=true;
  [ "$AUTH" != "" ] || disable_auth=true;
  [ "$TLS" != "" ] || {
    disable_tls=true
    secure=
  }

  XDG_CONFIG_HOME=/tmp \
  CDY_SERVER_NAME=${SERVER_NAME:-DuboDubonDuponey/1.0} \
  CDY_LOG_LEVEL=${LOG_LEVEL:-error} \
  CDY_SCHEME="http${secure:-}" \
  CDY_DOMAIN="${DOMAIN:-}" \
  CDY_ADDITIONAL_DOMAINS="${ADDITIONAL_DOMAINS:-}" \
  CDY_AUTH_DISABLE="$disable_auth" \
  CDY_AUTH_REALM="$AUTH" \
  CDY_AUTH_USERNAME="${AUTH_USERNAME:-}" \
  CDY_AUTH_PASSWORD="${AUTH_PASSWORD:-}" \
  CDY_TLS_DISABLE="$disable_tls" \
  CDY_TLS_MODE="$TLS" \
  CDY_TLS_MIN="${TLS_MIN:-1.3}" \
  CDY_TLS_AUTO="${TLS_AUTO:-disable_redirects}" \
  CDY_MTLS_DISABLE="$disable_mtls" \
  CDY_MTLS_MODE="$MTLS" \
  CDY_MTLS_TRUST="${MTLS_TRUST:-}" \
  CDY_HEALTHCHECK_URL="$HEALTHCHECK_URL" \
  CDY_PORT_HTTP="$PORT_HTTP" \
  CDY_PORT_HTTPS="$PORT_HTTPS" \
    caddy run -config /config/caddy/main.conf --adapter caddyfile "$@"
}

# Helpers
case "${1:-}" in
  # Short hand helper to generate password hash
  "hash")
    shift
    run::hash "$@"
    exit
  ;;
  # Helper to get the ca.crt out (once initialized)
  "cert")
    shift
    run::certificate "${TLS:-}" "$@"
    exit
  ;;
esac

