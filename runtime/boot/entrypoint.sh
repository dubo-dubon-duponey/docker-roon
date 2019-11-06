#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

if [ -e ./Server/RoonServer ]; then
  exec ./Server/RoonServer
else
  exec ./Bridge/RoonBridge
fi
