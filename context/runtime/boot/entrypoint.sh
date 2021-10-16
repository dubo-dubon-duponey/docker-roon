#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

helpers::dir::writable "/tmp"
helpers::dir::writable "/data"
helpers::dir::writable "$ROON_ID_DIR" create
helpers::dir::writable "$ROON_DATAROOT" create

# Get the main logs into stdout, whenever they are created
log::ingest(){
  local fd="$1"
  tail -F "$fd"
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

# mDNS blast if asked to
[ ! "$MDNS_HOST" ] || {
  _mdns_port="$([ "$TLS" != "" ] && printf "%s" "${PORT_HTTPS:-443}" || printf "%s" "${PORT_HTTP:-80}")"
  [ ! "${MDNS_STATION:-}" ] || mdns::add "_workstation._tcp" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::add "${MDNS_TYPE:-_http._tcp}" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::start &
}

# Start the sidecar
start::sidecar &

# error”, “critical”, “warning”, “message”, “info”, and “debug”
# Looks like ROON ignore these
#MONO_LOG_LEVEL="$(printf "%s" "${LOG_LEVEL:-error}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^(warn)$/warning/')"
#export MONO_LOG_LEVEL

exec /boot/bin/RoonServer/Server/RoonServer "$@"
