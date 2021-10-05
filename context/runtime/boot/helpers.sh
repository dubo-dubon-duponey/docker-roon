#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

ensure::writable(){
  local dir="$1"
  printf >&2 "Verifying that %s is writable\n" "$dir"
  [ -w "$dir" ] || {
    printf >&2 "%s is not writable. Check your mount permissions.\n" "$dir"
    exit 1
  }
}

ensure::writable "/certs"
ensure::writable "/data"
ensure::writable "/tmp"
mkdir -p "$XDG_RUNTIME_DIR"
mkdir -p "$XDG_STATE_HOME"
mkdir -p "$XDG_CACHE_HOME"

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

start::mdns(){
  local type="$1"
  local name="$2"
  local host="$3"
  local port="$4"
  local workstation="${5:-true}"
  local text="${6:-}"
  [ "$text" ] || text="{}"

  local records

  if [ "$workstation" == true ]; then
    records="$(printf \
      '[{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": %s},
      {"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": %s}]' \
      "_workstation._tcp" "$name" "$host" "$port" "$text" \
      "$type"             "$name" "$host" "$port" "$text" \
    )"
  else
    records="$(printf \
      '[{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": %s}]' \
      "$type"             "$name" "$host" "$port" "$text" \
    )"
  fi

  goello-server -json "$records" &
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

  HOME=/tmp/caddy-home \
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
    caddy run -config /config/caddy/main.conf --adapter caddyfile &
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

# Bonjour the container if asked to
[ "${MDNS:-}" == "" ] || \
  start::mdns \
    "${MDNS:-_http._tcp}" \
    "${MDNS_NAME:-service}" \
    "${MDNS_HOST:-service}" \
    "$([ "$TLS" != "" ] && printf "%s" "${PORT_HTTPS:-443}" || printf "%s" "${PORT_HTTP:-80}")"
    "${MDNS_STATION:-true}"

# Start the sidecar
start::sidecar
