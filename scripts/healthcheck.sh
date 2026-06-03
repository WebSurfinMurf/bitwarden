#!/bin/bash
# Post-deploy health check for Vaultwarden.
#
# After a recreate the container's Docker healthcheck sits in "starting" for a
# bit, and Traefik only routes to *healthy* backends — so the public URL 404s
# until the container goes healthy. Poll with retries rather than failing fast.
set -euo pipefail

URL="${BITWARDEN_URL:-https://bitwarden.ai-servicers.com}"
RETRIES="${HEALTHCHECK_RETRIES:-30}"
INTERVAL="${HEALTHCHECK_INTERVAL:-6}"

check() {
    curl -fsS --max-time 10 "${URL}${1}" >/dev/null
}

echo "Waiting for ${URL}/alive (up to $((RETRIES * INTERVAL))s) ..."
for i in $(seq 1 "$RETRIES"); do
    if check /alive; then
        echo "alive OK after ${i} attempt(s)"
        break
    fi
    if [ "$i" -eq "$RETRIES" ]; then
        echo "ERROR: ${URL}/alive never came up" >&2
        exit 1
    fi
    sleep "$INTERVAL"
done

echo "Checking ${URL}/api/version ..."
curl -fsS --max-time 10 "${URL}/api/version"
echo

echo "Healthcheck OK"
