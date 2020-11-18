#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

if [ -e /boot/bin/RoonServer/Server/RoonServer ]; then
  exec /boot/bin/RoonServer/Server/RoonServer
else
  exec /boot/bin/RoonBridge/Bridge/RoonBridge
fi
