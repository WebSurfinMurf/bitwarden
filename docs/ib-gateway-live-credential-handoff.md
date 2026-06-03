# Handoff — live IB Gateway credentials via Bitwarden (for the stocktrader-live admin)

**From:** administrator session (Bitwarden/Vaultwarden side fully prepared 2026-06-02)
**To:** the admin managing **stocktrader-live**
**Purpose:** the live IB brokerage credentials are now stored in the Bitwarden vault, not
in a `~/projects/secrets/*.env` file. Your job is to wire `start.gateway.live.sh` (or the
equivalent live-gateway launcher) to pull them from the vault at start time.

---

## 1. What is already done (you do not need to redo any of this)

- **Vaultwarden** `https://bitwarden.ai-servicers.com` is on 1.36.0, deployed via the GitLab
  pipeline (`administrators/bitwarden`). Signups are closed.
- **`bw` CLI** `2026.5.0` is installed at `/home/administrator/.local/bin/bw` (on the
  `administrator` PATH) and already configured to the self-hosted server
  (`bw config server https://bitwarden.ai-servicers.com`).
- **Account:** `administrator@ai-servicers.com` exists. Its **master password is held by the
  human administrator** — it is not stored anywhere on disk, and unlocking the vault requires
  it to be supplied at runtime.
- **The secret:** a Login item named exactly **`ib-gateway-live`** lives in org
  `ai-servicers`, collection **`administrators`** (admin-only). Its *username* and *password*
  fields hold the live IB account credentials.
- **Round-trip is verified** on this host: `bw unlock` → `bw sync` →
  `bw get password "ib-gateway-live"` returns the live password. KDF is PBKDF2-SHA256 / 600k.
- A diagnostic helper exists: **`~/projects/bitwarden/scripts/test-bw-roundtrip.sh`**
  (`./scripts/test-bw-roundtrip.sh [reveal]`).

## 2. The retrieval pattern

```bash
export PATH="$HOME/.local/bin:$PATH"

# One-time per host/user (persists in ~/.config/Bitwarden CLI/data.json):
bw login administrator@ai-servicers.com      # already done on this host

# Every gateway start (vault is LOCKED at rest; master password derives the key):
export BW_SESSION="$(bw unlock --raw)"        # prompts for master password
bw sync                                        # pull latest item state
export TWS_USERNAME="$(bw get username "ib-gateway-live" --session "$BW_SESSION")"
export TWS_PASSWORD="$(bw get password "ib-gateway-live" --session "$BW_SESSION")"
```

After the gateway is up you should **`bw lock`** (or `unset BW_SESSION`) so the vault key
isn't left unlocked in a long-running environment.

## 3. What you need to build

`start.gateway.live.sh` (in the IB Gateway / stocktrader-live deploy, wherever the live
launcher lives) should:

1. Ensure `bw` is on PATH and the host is logged in as `administrator@ai-servicers.com`
   (fail loudly with instructions if `bw status` is `unauthenticated`).
2. Acquire a session (`bw unlock`) — see §4 for *how the master password gets in*.
3. `bw sync`, then read `TWS_USERNAME` / `TWS_PASSWORD` from `ib-gateway-live`.
4. Launch IB Gateway with those env vars (replace the current `~/projects/secrets/*.env`
   source for the live account).
5. Scrub the secrets from the environment / `bw lock` once the gateway has consumed them.
6. Never echo the password, never write it to a file, never commit it.

## 4. The one real design decision: how the master password is supplied

`bw` cannot unlock headlessly — it always needs the master password (or a still-valid
`BW_SESSION`) at start. Pick the model that fits how live trading is started:

- **Attended start (recommended, and what the original spec assumed).** The admin types the
  master password once when launching the live gateway; the script unlocks, pulls the creds,
  starts the gateway, then locks. Most secure, no secret material at rest. Downside: a human
  must be present at each live start / restart.
- **Session reuse.** Admin unlocks once (`export BW_SESSION=$(bw unlock --raw)`), and the
  launcher reuses that session for subsequent restarts until it locks/expires. Less typing,
  but a live session key sits in the environment.
- **API key for *login* only.** A Bitwarden personal API key (`bw login --apikey`,
  `BW_CLIENTID`/`BW_CLIENTSECRET`) removes the interactive *login*, but **unlock still needs
  the master password** — so it does not make the flow fully unattended. Useful only if you
  want to avoid storing the account email/password for the login step.
- ⚠️ **Fully unattended** would require parking the master password (or a long-lived session)
  somewhere on disk — which defeats the entire point of moving off `*.env`. Don't do this for
  the *live* account without an explicit decision from the human administrator.

**Confirm with the human administrator which model live trading should use before coding it.**

## 5. Gotchas (learned the hard way this session)

- A **mistyped master password at the `bw unlock` prompt** does NOT say "invalid password" —
  the newer Rust CLI reports `bitwarden_crypto::keys::master_key: The decryption operation
  failed`. If you see that, retype the password; it's almost never a real crypto bug.
  `bw login` and `bw unlock` prompt *separately*, so the typo hides on the second prompt.
- `bw get password "<name>"` matches by **item name and must be unambiguous**. Keep
  `ib-gateway-live` unique across the vault + org, or fetch by item ID
  (`bw list items --search ib-gateway-live`).
- **Which user runs the gateway matters.** The `bw login` state and config live under the
  user that ran it (here: `administrator`, `~/.config/Bitwarden CLI/`). If the live gateway
  runs as a *different* service user, that user must either run `bw login` as an account with
  access to the `administrators` collection, or you run the launcher as `administrator`.
- Always `bw sync` before `bw get` after the item is created/edited, or you may read stale
  or "not found".

## 6. Quick verification before you build anything

```bash
cd ~/projects/bitwarden
./scripts/test-bw-roundtrip.sh        # confirms unlock -> sync -> get works for you
```
Green `ROUND-TRIP PASSED` means the vault side is ready and you only need to wrap it in the
launcher per §3–§4.

---
*Vault-side reference: `~/projects/bitwarden/docs/admin-cli-integration.response.md`.*
