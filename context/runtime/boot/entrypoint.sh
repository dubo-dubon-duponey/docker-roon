#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"
# shellcheck source=/dev/null
. "$root/http.sh"

helpers::dir::writable "$XDG_DATA_HOME" create

helpers::dir::writable "$ROON_ID_DIR" create
helpers::dir::writable "$ROON_DATAROOT" create

case "$LOG_LEVEL" in
  "debug")
    reg="Trace"
  ;;
  "info")
    reg="Trace|Debug"
  ;;
  "warning")
    reg="Trace|Debug|Info"
  ;;
  "error")
    reg="Trace|Debug|Warn"
  ;;
esac
reg="^[0-9/: ]*(?:$reg)"

# Get the main logs into stdout, whenever they are created - and artificially filter out...
log::ingest(){
  local fd="$1"
  # So... hide out whatever
  tail -F "$fd" 2>/dev/null | grep -Pv "$reg"
}

# Get rid of the rotated logs,
log::clean(){
  local frequency="$1"
  while true; do
    find "$XDG_DATA_HOME"/roon/data/ -iname "*log.*.txt" -exec rm {} \;
    sleep "$frequency"
  done
}

log::ingest "$ROON_DATAROOT/RoonServer/Logs/RoonServer_log.txt" &
log::ingest "$ROON_DATAROOT/RoonBridge/Logs/RoonBridge_log.txt" &
log::ingest "$ROON_DATAROOT/RAATServer/Logs/RAATServer_log.txt" &
log::clean 86400 &

if [ ! -e /boot/bin/RoonServer/Server/RoonServer ]; then
  helpers::dir::writable "/tmp"

  exec /boot/bin/RoonBridge/Bridge/RoonBridge "$@"
  exit
fi

# shellcheck disable=SC2015
[ "${MOD_HTTP_ENABLED:-}" != true ] && [ "${MOD_TLS_ENABLED:-}" != true ] || {
  helpers::dir::writable "/certs"
}

helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "$XDG_STATE_HOME" create
helpers::dir::writable "$XDG_CACHE_HOME" create

# HTTP helpers
if [ "$MOD_HTTP_ENABLED" == true ]; then
  case "${1:-}" in
    # Short hand helper to generate password hash
    "hash")
      shift
      http::hash "$@"
      exit
    ;;
    # Helper to get the ca.crt out (once initialized)
    "cert")
      shift
      http::certificate "${MOD_HTTP_TLS_MODE:-internal}" "$@"
      exit
    ;;
  esac
  http::start &
fi

[ "${MOD_MDNS_ENABLED:-}" != true ] || \
  mdns::start::default \
    "${MOD_MDNS_HOST:-}" \
    "${MOD_MDNS_NAME:-}" \
    "${MOD_HTTP_ENABLED:-}" \
    "${MOD_HTTP_TLS_ENABLED:-}" \
    "${MOD_TLS_ENABLED:-}" \
    "${ADVANCED_MOD_MDNS_STATION:-}" \
    "${ADVANCED_MOD_MDNS_TYPE:-}" \
    "${ADVANCED_MOD_HTTP_PORT:-}" \
    "${ADVANCED_MOD_HTTP_PORT_INSECURE:-}" \
    "${ADVANCED_MOD_TLS_PORT:-}"

# Looks like ROON ignore these
#MONO_LOG_LEVEL="$(printf "%s" "${LOG_LEVEL:-error}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^(warn)$/warning/')"
#export MONO_LOG_LEVEL
exec /boot/bin/RoonServer/Server/RoonServer "$@"
