#!/bin/bash
# Manual test: Bitwarden CLI round-trip (unlock -> sync -> get item).
# Reads the master password ONCE (no echo) and passes it via --passwordenv, which
# avoids the interactive double-prompt where a typo shows up as the misleading
# "decryption operation failed" crypto error.
#
# Usage:
#   ./scripts/test-bw-roundtrip.sh                 # masks the retrieved password
#   ./scripts/test-bw-roundtrip.sh reveal          # prints the actual password
#
# Nothing is written to disk or shell history. Run as the administrator user.
set -u

ITEM="ib-gateway-live"
REVEAL="${1:-}"
export PATH="$HOME/.local/bin:$PATH"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }

command -v bw >/dev/null || { red "bw not found on PATH"; exit 1; }
echo "bw: $(command -v bw)  ($(bw --version 2>/dev/null))"

# --- 1. account state -------------------------------------------------------
STATUS=$(bw status 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin).get("status","?"))' 2>/dev/null)
echo "status: $STATUS"
if [ "$STATUS" = "unauthenticated" ]; then
    red "Not logged in. Run first:  bw login administrator@ai-servicers.com"
    exit 1
fi

# --- 2. read master password once (no echo) ---------------------------------
printf 'Master password: '
read -rs MP; echo
[ -n "$MP" ] || { red "empty password"; exit 1; }

# --- 3. unlock --------------------------------------------------------------
ERR=$(mktemp)
SESSION=$(BW_PW="$MP" bw unlock --passwordenv BW_PW --raw 2>"$ERR")
RC=$?
MP=""   # clear from memory
if [ $RC -ne 0 ] || [ -z "$SESSION" ]; then
    red "UNLOCK FAILED"
    if grep -qi 'decryption operation failed\|invalid master password' "$ERR"; then
        ylw "  -> wrong master password (the password that decrypts the vault is the one you"
        ylw "     set when you registered administrator@ai-servicers.com). Re-run and retype."
    else
        echo "  bw said:"; sed 's/^/    /' "$ERR"
    fi
    rm -f "$ERR"; exit 1
fi
rm -f "$ERR"
grn "unlock OK (session acquired)"

# --- 4. sync ----------------------------------------------------------------
if bw sync --session "$SESSION" >/dev/null 2>&1; then
    grn "sync OK"
else
    ylw "sync reported an issue (continuing)"
fi

# --- 5. fetch the item ------------------------------------------------------
ERR=$(mktemp)
PW=$(bw get password "$ITEM" --session "$SESSION" 2>"$ERR")
RC=$?
if [ $RC -ne 0 ] || [ -z "$PW" ]; then
    red "COULD NOT GET '$ITEM'"
    if grep -qi 'not found' "$ERR"; then
        ylw "  -> item '$ITEM' not found in your synced vault."
        ylw "     Check it exists and the name is exact:"
        bw list items --search "$ITEM" --session "$SESSION" 2>/dev/null \
          | python3 -c 'import sys,json
items=json.load(sys.stdin)
print(f"     matches for \"'"$ITEM"'\": {len(items)}")
for i in items: print("      -", repr(i.get("name")), "| collections:", i.get("collectionIds"))' 2>/dev/null \
          || ylw "     (no matches)"
    elif grep -qi 'more than one' "$ERR"; then
        ylw "  -> the name '$ITEM' is ambiguous (multiple items). Use a unique name or item ID."
    else
        sed 's/^/    /' "$ERR"
    fi
    rm -f "$ERR"; exit 1
fi
rm -f "$ERR"

# --- 6. success -------------------------------------------------------------
grn "GET OK — retrieved password for '$ITEM'"
if [ "$REVEAL" = "reveal" ]; then
    echo "  password: $PW"
else
    echo "  password: [${#PW} chars, starts '${PW:0:2}…'] — re-run with 'reveal' to print it"
fi
PW=""
echo
grn "ROUND-TRIP PASSED — the Bitwarden -> CLI chain works."
echo "In a deploy script you'd use:"
echo '  export BW_SESSION=$(bw unlock --passwordenv BW_PW --raw)'
echo '  export TWS_PASSWORD=$(bw get password "'"$ITEM"'")'
