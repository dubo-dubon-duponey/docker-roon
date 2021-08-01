#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# This will re-download fresh versions of RoonBridge and Server
# The purpose of this "cache" is to allow for reproducible builds with the exact same Roon software versions

geturl(){
  local url
  case "$1" in
    "linux/amd64")
      url="x64"
    ;;
    "linux/arm64")
      url="armv8"
    ;;
    "linux/arm/v7")
      url="armv7hf"
    ;;
  esac
  printf "https://download.roonlabs.com/builds/RoonBridge_linux%s.tar.bz2" "$url"
}

for platform in linux/amd64 linux/arm64 linux/arm/v7; do
  mkdir -p ./context/cache/"$platform"
  if ! curl --proto '=https' --tlsv1.2 -sSfL -o ./context/cache/"$platform"/bridge.tar.bz2 "$(geturl "${platform}")"; then
    rm -f ./context/cache/"$platform"/bridge.tar.bz2
    printf >&2 "Failed to download bits!\n"
    exit 1
  fi
done

mkdir -p ./context/cache/linux/amd64
if ! curl --proto '=https' --tlsv1.2 -sSfL -o ./context/cache/linux/amd64/server.tar.bz2 "https://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2"; then
  rm -f ./context/cache/linux/amd64/server.tar.bz2
  printf >&2 "Failed to download bits!\n"
  exit 1
fi
