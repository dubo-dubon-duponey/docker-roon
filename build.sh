#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export TITLE="Roon Bridge"
export DESCRIPTION="A dubo image for Roon Bridge"
export IMAGE_NAME="roon-bridge"
export PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7}" # No v6

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh" --target runtime-bridge

export TITLE="Roon Server"
export DESCRIPTION="A dubo image for Roon Server"
export IMAGE_NAME="roon-server"
export PLATFORMS="linux/amd64" # Nothing but AMD64

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh" --target runtime-server
