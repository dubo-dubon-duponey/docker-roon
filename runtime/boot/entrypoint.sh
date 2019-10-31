#!/usr/bin/env bash
set -euxo pipefail

if [ -e ./Server/RoonServer ]; then
  exec ./Server/RoonServer
else
  exec ./Bridge/RoonBridge
fi
