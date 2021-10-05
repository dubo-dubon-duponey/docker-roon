#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"

mkdir -p "$ROON_ID_DIR"

# Just a dirty little trick. First, ensure the directories are here.
#mkdir -p "$ROON_DATAROOT/RoonServer/Logs"
#mkdir -p "$ROON_DATAROOT/RoonBridge/Logs"
#mkdir -p "$ROON_DATAROOT/RAATServer/Logs"
tail -F "$ROON_DATAROOT/RoonServer/Logs/RoonServer_log.txt" &
tail -F "$ROON_DATAROOT/RoonBridge/Logs/RoonBridge_log.txt" &
tail -F "$ROON_DATAROOT/RAATServer/Logs/RAATServer_log.txt" &

# error”, “critical”, “warning”, “message”, “info”, and “debug”
# Looks like ROON ignore these
#MONO_LOG_LEVEL="$(printf "%s" "${LOG_LEVEL:-error}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^(warn)$/warning/')"
#export MONO_LOG_LEVEL

if [ ! -e /boot/bin/RoonServer/Server/RoonServer ]; then
  exec /boot/bin/RoonBridge/Bridge/RoonBridge
  exit
fi

exec /boot/bin/RoonServer/Server/RoonServer
