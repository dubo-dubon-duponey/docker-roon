#!/usr/bin/env bash

# This will re-download fresh versions of RoonBridge and Server
# The purpose of this "cache" is to allow for reproducible builds with the exact same Roon software versions

toroon(){
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
  echo "$url"
}

for platform in linux/amd64 linux/arm64 linux/arm/v7; do
  mkdir -p roon-bits-cache/"$platform"
  curl -fsSL -o roon-bits-cache/"$platform"/bridge.tar.bz2 "http://download.roonlabs.com/builds/RoonBridge_linux$(toroon "${platform}").tar.bz2"
done

mkdir -p roon-bits-cache/linux/amd64
curl -fsSL -o roon-bits-cache/linux/amd64/server.tar.bz2 "http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2"
