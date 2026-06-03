#!/bin/bash
# Post-deploy health check for Vaultwarden.
# Verifies the public endpoint is alive and reports the running version.
set -euo pipefail

URL="${BITWARDEN_URL:-https://bitwarden.ai-servicers.com}"

echo "Checking ${URL}/alive ..."
curl -fsS --max-time 15 "${URL}/alive"
echo

echo "Checking ${URL}/api/version ..."
curl -fsS --max-time 15 "${URL}/api/version"
echo

echo "Healthcheck OK"
