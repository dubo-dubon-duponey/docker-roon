#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

[ -w /data ] || {
  printf >&2 "/data is not writable. Check your mount permissions.\n"
  exit 1
}

mkdir -p "$ROON_ID_DIR"

# Just a dirty little trick. First, ensure the directories are here.
mkdir -p "$ROON_DATAROOT/RAATServer/Logs"
mkdir -p "$ROON_DATAROOT/RoonServer/Logs"
# Now, touch the logs
touch "$ROON_DATAROOT/RoonServer/Logs/RoonServer_log.txt"
touch "$ROON_DATAROOT/RAATServer/Logs/RAATServer_log.txt"
# Kill write permissions on the directory, preventing Roon to rotate the files out
#chmod a-w "$ROON_DATAROOT/RAATServer/Logs"
#chmod a-w "$ROON_DATAROOT/RoonServer/Logs"
# Now it"s safe to slurp them back in stdout, but watch for rotate
tail -F "$ROON_DATAROOT/RoonServer/Logs/RoonServer_log.txt" &
tail -F "$ROON_DATAROOT/RAATServer/Logs/RAATServer_log.txt" &

# There are at least unique identifiers stored in data
# Looks like logs end up there too so, maybe some cleanup needed
if [ ! -e /boot/bin/RoonServer/Server/RoonServer ]; then
  exec /boot/bin/RoonBridge/Bridge/RoonBridge
fi

[ -w /certs ] || {
  printf >&2 "/certs is not writable. Check your mount permissions.\n"
  exit 1
}

[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

# Helpers
case "${1:-run}" in
# Short hand helper to generate password hash
"hash")
  shift
  printf >&2 "Generating password hash\n"
  caddy hash-password -algorithm bcrypt "$@"
  exit
  ;;
  # Helper to get the ca.crt out (once initialized)
"cert")
  if [ "${TLS:-}" == "" ]; then
    printf >&2 "Your container is not configured for TLS termination - there is no local CA in that case."
    exit 1
  fi
  if [ "${TLS:-}" != "internal" ]; then
    printf >&2 "Your container uses letsencrypt - there is no local CA in that case."
    exit 1
  fi
  if [ ! -e /certs/pki/authorities/local/root.crt ]; then
    printf >&2 "No root certificate installed or generated. Run the container so that a cert is generated, or provide one at runtime."
    exit 1
  fi
  cat /certs/pki/authorities/local/root.crt
  exit
  ;;
"run")
  # Bonjour the container if asked to. While the PORT is no guaranteed to be mapped on the host in bridge, this does not matter since mDNS will not work at all in bridge mode.
  if [ "${MDNS_ENABLED:-}" == true ]; then
    goello-server -json "$(printf '[{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": {}}]' "$MDNS_TYPE" "$MDNS_NAME" "$MDNS_HOST" "$PORT")" &
  fi

  # If we want TLS and authentication, start caddy in the background
  if [ "${TLS:-}" ]; then
    HOME=/tmp/caddy-home caddy run -config /config/caddy/main.conf --adapter caddyfile &
  fi
  ;;
esac

exec /boot/bin/RoonServer/Server/RoonServer
