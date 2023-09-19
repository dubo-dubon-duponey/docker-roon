#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

readonly _default_mod_mtls_trust="/certs/pki/authorities/local/root.crt"
readonly _default_mod_mtls_mode="verify_if_given"

readonly _default_realm="My Precious Realm"
readonly _default_http_port=80
readonly _default_https_port=443
readonly _default_tls_min="1.3"
readonly _default_server_name="DuboDubonDuponey/1.0 (Caddy/2)"
readonly _default_acme_server="https://acme-v02.api.letsencrypt.org/directory"

http::hash(){
  printf >&2 "Generating password hash\n"
  caddy hash-password -algorithm bcrypt "$@"
}

http::certificate(){
  local tls_mode="$1"
  printf >&2 "Displaying root certificate to trust\n"
  if [ "$tls_mode" == "" ]; then
    printf >&2 "Your container is not configured for TLS termination - there is no local CA in that case."
    exit 1
  fi
  if [ "$tls_mode" != "internal" ]; then
    printf >&2 "Your container uses letsencrypt - there is no local CA in that case."
    exit 1
  fi
  if [ ! -e /certs/pki/authorities/local/root.crt ]; then
    printf >&2 "No root certificate installed or generated. Run the container so that a cert is generated, or provide one at runtime."
    exit 1
  fi
  cat /certs/pki/authorities/local/root.crt
}

http::start(){
  local disable_tls=""
  local disable_mtls=""
  local disable_auth=""

  [ "${MOD_MTLS_ENABLED:-}" == true ] || disable_mtls=true;
  [ "${MOD_BASICAUTH_ENABLED:-}" == true ] || disable_auth=true;

  local secure=s

  [ "$ADVANCED_MOD_HTTP_TLS_ENABLED" != true ] || {
    disable_tls=true
    secure=
  }

  CDY_LOG_LEVEL=${LOG_LEVEL:-warn} \
  CDY_MTLS_DISABLE="$disable_mtls" \
  CDY_MTLS_MODE="${MOD_MTLS_MODE:-$_default_mod_mtls_mode}" \
  CDY_MTLS_TRUST="${ADVANCED_MOD_MTLS_TRUST:-$_default_mod_mtls_trust}" \
  CDY_AUTH_DISABLE="$disable_auth" \
  CDY_AUTH_REALM="${MOD_BASICAUTH_REALM:-$_default_realm}" \
  CDY_AUTH_USERNAME="${MOD_BASICAUTH_USERNAME:-}" \
  CDY_AUTH_PASSWORD="${MOD_BASICAUTH_PASSWORD:-}" \
  CDY_SCHEME="http${secure:-}" \
  CDY_DOMAIN="${DOMAIN:-}" \
  CDY_ADDITIONAL_DOMAINS="${ADVANCED_MOD_HTTP_ADDITIONAL_DOMAINS:-}" \
  CDY_TLS_DISABLE="$disable_tls" \
  CDY_TLS_MODE="${MOD_HTTP_TLS_MODE:-internal}" \
  CDY_TLS_AUTO="${ADVANCED_MOD_HTTP_TLS_AUTO:-disable_redirects}" \
  CDY_HEALTHCHECK_URL="$HEALTHCHECK_URL" \
  CDY_ACME_CA="${ADVANCED_MOD_HTTP_TLS_SERVER:-$_default_acme_server}" \
  CDY_PORT_HTTP="${ADVANCED_MOD_HTTP_PORT_INSECURE:-$_default_http_port}" \
  CDY_PORT_HTTPS="${ADVANCED_MOD_HTTP_PORT:-$_default_https_port}" \
  CDY_TLS_MIN="${ADVANCED_MOD_HTTP_TLS_MIN:-$_default_tls_min}" \
  CDY_SERVER_NAME="${ADVANCED_MOD_HTTP_SERVER_NAME:-$_default_server_name}" \
    caddy run --config /config/caddy/main.conf --adapter caddyfile "$@"
}

