#!/usr/bin/env bash
# Non-interactive Bitwarden session for a machine identity.
#
# Usage:
#   eval "$(./scripts/bw-service-session.sh <secrets-env-file>)"
#   bw get password "some-item"        # BW_SESSION is now exported
#
# The env file must define BW_HOST, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD and
# BITWARDENCLI_APPDATA_DIR. The appdata dir MUST be unique per identity — sharing
# it with the default ~/.config/Bitwarden\ CLI would clobber the administrator
# login that start.gateway.live.sh depends on.
#
# Prints `export BW_SESSION=...` on stdout; diagnostics go to stderr.
set -euo pipefail

ENV_FILE=${1:?usage: bw-service-session.sh <secrets-env-file>}
[ -r "$ENV_FILE" ] || { echo "cannot read $ENV_FILE" >&2; exit 1; }

set -a; . "$ENV_FILE"; set +a
: "${BW_HOST:?}" "${BW_CLIENTID:?}" "${BW_CLIENTSECRET:?}" "${BW_PASSWORD:?}"
: "${BITWARDENCLI_APPDATA_DIR:?}"
export BITWARDENCLI_APPDATA_DIR BW_CLIENTID BW_CLIENTSECRET

BW=${BW_BIN:-$HOME/.local/bin/bw}
mkdir -p "$BITWARDENCLI_APPDATA_DIR"

status=$("$BW" status | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])')
if [ "$status" = unauthenticated ]; then
  "$BW" config server "$BW_HOST" >/dev/null
  "$BW" login --apikey --quiet
fi

# --passwordenv avoids the interactive prompt and keeps the password off argv.
BW_SESSION=$(BW_PASSWORD="$BW_PASSWORD" "$BW" unlock --passwordenv BW_PASSWORD --raw)
export BW_SESSION
"$BW" sync >/dev/null

printf 'export BW_SESSION=%q\n' "$BW_SESSION"
