#!/usr/bin/env bash

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
  printf "http://download.roonlabs.com/builds/RoonBridge_linux$url.tar.bz2"
}

for platform in linux/amd64 linux/arm64 linux/arm/v7; do
  mkdir -p ./cache/"$platform"
  if ! curl -fsSL -o ./cache/"$platform"/bridge.tar.bz2 "$(geturl "${platform}")"; then
    rm -f ./cache/"$platform"/bridge.tar.bz2
    >&2 printf "Failed to download bits!\n"
    exit 1
  fi
done

mkdir -p ./cache/linux/amd64
if ! curl -fsSL -o ./cache/linux/amd64/server.tar.bz2 "http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2"; then
  rm -f ./cache/linux/amd64/server.tar.bz2
  >&2 printf "Failed to download bits!\n"
  exit 1
fi
