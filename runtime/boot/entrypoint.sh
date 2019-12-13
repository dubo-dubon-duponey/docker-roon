#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

if [ -e /boot/bin/Server/RoonServer ]; then
  exec /boot/bin/RoonServer/Server
else
  exec /boot/bin/RoonBridge/Bridge
fi
