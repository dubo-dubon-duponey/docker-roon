#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

TEST_DOES_NOT_BUILD=${TEST_DOES_NOT_BUILD:-}

if ! hadolint ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

if [ ! "$TEST_DOES_NOT_BUILD" ]; then
  [ ! -e "./refresh.sh" ] || ./refresh.sh
  if ! ./hack/cue-bake bridge --inject platforms=linux/arm64; then
    >&2 printf "Failed building bridge image\n"
    exit 1
  fi
  if ! ./hack/cue-bake server; then
    >&2 printf "Failed building server image\n"
    exit 1
  fi
fi
