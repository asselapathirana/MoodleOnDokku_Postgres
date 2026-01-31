#!/usr/bin/env bash
set -euo pipefail

# Run custom entrypoint scripts before handing off to the base image
if [ -d /docker-entrypoint.d ]; then
  for f in /docker-entrypoint.d/*.sh; do
    if [ -f "$f" ]; then
      # shellcheck disable=SC1090
      . "$f"
    fi
  done
fi

exec /usr/local/bin/docker-php-entrypoint "$@"
