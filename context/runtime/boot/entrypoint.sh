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

helpers::dir::writable "/tmp"

helpers::dir::writable "$XDG_DATA_HOME" create
helpers::dir::writable "$XDG_DATA_DIRS" create

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
    find ./data/ -iname "*log.*.txt" -exec rm {} \;
    sleep "$frequency"
  done
}

log::ingest "$ROON_DATAROOT/RoonServer/Logs/RoonServer_log.txt" &
log::ingest "$ROON_DATAROOT/RoonBridge/Logs/RoonBridge_log.txt" &
log::ingest "$ROON_DATAROOT/RAATServer/Logs/RAATServer_log.txt" &
log::clean 86400 &

if [ ! -e /boot/bin/RoonServer/Server/RoonServer ]; then
  exec /boot/bin/RoonBridge/Bridge/RoonBridge "$@"
  exit
fi

helpers::dir::writable "/certs"
helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "$XDG_STATE_HOME" create
helpers::dir::writable "$XDG_CACHE_HOME" create

# mDNS
[ "${MOD_MDNS_ENABLED:-}" != true ] || {
  _mdns_type="${ADVANCED_MOD_MDNS_TYPE:-_http._tcp}"
  _mdns_port="$([ "${MOD_HTTP_TLS_ENABLED:-}" == true ] && printf "%s" "${ADVANCED_MOD_HTTP_PORT:-443}" || printf "%s" "${ADVANCED_MOD_HTTP_PORT_INSECURE:-80}")"
  [ "${ADVANCED_MOD_MDNS_STATION:-}" != true ] || mdns::records::add "_workstation._tcp" "${MOD_MDNS_HOST}" "${MOD_MDNS_NAME:-}" "$_mdns_port"
  mdns::records::add "$_mdns_type" "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" "$_mdns_port"
  mdns::start::broadcaster
}

# TLS and HTTP
[ "${MOD_HTTP_ENABLED:-}" != true ] || http::start &

# error”, “critical”, “warning”, “message”, “info”, and “debug”
# Looks like ROON ignore these
#MONO_LOG_LEVEL="$(printf "%s" "${LOG_LEVEL:-error}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^(warn)$/warning/')"
#export MONO_LOG_LEVEL

exec /boot/bin/RoonServer/Server/RoonServer "$@"
