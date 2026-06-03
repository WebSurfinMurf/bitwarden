# Response — Bitwarden admin CLI integration

*Executor: Claude (administrator session). Date: 2026-06-02.*
*Deployment was reworked to be GitLab-centric first (see `.gitlab-ci.yml` and the
updated Task 1 in `admin-cli-integration.md`); the upgrade below ran through that pipeline.*

## 1. Vaultwarden version
- Before: 1.x (image `vaultwarden/server:latest`, container up ~3 weeks)
- After:  **Vaultwarden 1.36.0** / Web-Vault 2026.4.1
- Data dir intact: **yes** — `/home/administrator/projects/data/bitwarden` is an external
  bind mount; the upgrade is an in-place container recreate, the volume is never touched.
- /admin still works: **yes** — `https://bitwarden.ai-servicers.com/admin` returns 200 and
  the admin API authenticates with the existing `ADMIN_TOKEN`.
- How it was deployed: GitLab pipeline `administrators/bitwarden` (project id 52) →
  `deploy` job ran `./deploy.sh` (compose pull/down/up) → `test` job health-checked. Green.

## 2. Admin user account  — DONE
- **Users in the vault: 2** — `websurfinmurf@gmail.com` (developer-side, pre-existing) and
  **`administrator@ai-servicers.com`** (self-registered by the admin; verified, enabled).
- `SIGNUPS_ALLOWED` final state: **off (false)** — closed after the admin account was
  registered. Verified: container env `SIGNUPS_ALLOWED=false` and the register endpoint now
  returns `400 "Registration not allowed"`. Change was made in `bitwarden.env`
  (backup at `bitwarden.env.bak.20260602`) and deployed via the pipeline.
- **SMTP is entirely unconfigured** (`SMTP_HOST`/`SMTP_FROM`/etc. all unset). Emailed
  *invites* won't work — self-registration was used. To onboard developers later either
  briefly reopen signups or configure SMTP (see §5).

## 2b. Organization / developers-group readiness
- Organizations enabled: **yes** — Vaultwarden 1.36.0 supports orgs.
- `ORG_CREATION_USERS` value: **unset** → any logged-in user may create organizations.
  No restriction blocks you from creating the `ai-servicers` org after first login.
- Existing users who are in the `developers` Linux group (for later invite):
  `websurfinmurf@gmail.com` is the developer-side user. The `developers` Linux group
  (gid 3000) members get invited to the `developers` collection later — NOT done now
  (per your instructions).
- Intended structure (for you to create after first login, as the doc specifies):
  - Org **`ai-servicers`**.
  - Collection **`administrators`** — admin-only (live IB creds, infra secrets).
  - Collection **`developers`** — paper IB creds / dev tooling; invite developers here only.

## 3. CLI install
- Binary path: **`/home/administrator/.local/bin/bw`** (on the administrator PATH).
  - ⚠️ Deviation from the doc's `/usr/local/bin/bw`: that dir is root-owned and sudo here
    requires a password, so I installed to `~/.local/bin` (works immediately, on PATH).
    To promote it system-wide, run: `sudo install ~/.local/bin/bw /usr/local/bin/bw`.
- Version: **2026.5.0** (precompiled standalone binary, no Node dependency)
- Install method: precompiled — `bw-linux-2026.5.0.zip` from
  `github.com/bitwarden/clients/releases/download/cli-v2026.5.0/`
  (sha256 of zip: `5ddbf5383bec9c71613d7b699ffa5249b5e7b68b2a3d15b4c75738ba8a8f9a19`).
  (npm path was available too — node v24.14.1 is installed — but the precompiled binary
  avoids a global npm prefix needing sudo.)
- Config: `~/.config/Bitwarden CLI/data.json` (server set to https://bitwarden.ai-servicers.com)
- `bw status` output:
  `{"serverUrl":"https://bitwarden.ai-servicers.com","lastSync":null,"status":"unauthenticated"}`

## 4. Round-trip sanity check
- `curl /api/version` → `"1.36.0"`
- `bw status` → server URL correct, `unauthenticated` (expected — no master password yet)
- `bw login --help` → runs (CLI wired up)
- **Full end-to-end round-trip VERIFIED (2026-06-02):** `bw login` →
  `bw unlock` → `bw sync` → `bw get password "ib-gateway-live"` returns the live
  credential on this host. KDF is PBKDF2-SHA256 / 600k (standard). The whole
  Bitwarden→CLI chain works; `export TWS_PASSWORD=$(bw get password "ib-gateway-live")`
  is ready to use in `start.gateway.live.sh`.
  - Helper: `scripts/test-bw-roundtrip.sh` reads the master password via `--passwordenv`
    to avoid the interactive double-prompt that otherwise surfaces a typo as a misleading
    `decryption operation failed` error. Run `./scripts/test-bw-roundtrip.sh [reveal]`.

## 5. Findings / notes
- **bitwarden.env:**
  - `SIGNUPS_ALLOWED` set to **false** (done — see §2). Backup: `bitwarden.env.bak.20260602`.
  - `SMTP_*` is unset. If you ever want invites (e.g. to onboard the `developers` group
    without self-registration) you'll need `SMTP_HOST`, `SMTP_FROM`, `SMTP_PORT`,
    `SMTP_SECURITY`, `SMTP_USERNAME`, `SMTP_PASSWORD`. Not required for the self-register flow.
  - `ADMIN_TOKEN` is stored as **plaintext** (64 chars). Vaultwarden recommends an
    Argon2 PHC hash (`vaultwarden hash`) so the token isn't usable verbatim if the file
    leaks. Optional hardening.
- **Compose file:** removed the obsolete `version:` attribute (was emitting a warning).
  Otherwise healthy. Container has a built-in healthcheck; note Traefik only routes to
  *healthy* backends, so the public URL 404s for a few seconds after every recreate
  (the CI healthcheck polls/retries to handle this).
- **Could not do (and why):**
  - Install to `/usr/local/bin` — needs sudo/password; used `~/.local/bin` instead (one-liner above to promote).
  - Create the admin account / set master password — yours by design.
  - Create org/collections/items, invite developers — yours to do after first login.

---
## What to test (your end-to-end verification)

1. **Register the admin account:** open https://bitwarden.ai-servicers.com, click
   **Create account**, register `administrator@ai-servicers.com`, set + remember your
   master password. (Optional: log into `/admin` with the ADMIN_TOKEN to confirm the new
   user appears.)

2. **Tell me to close signups** (or do it yourself): set `SIGNUPS_ALLOWED=false` in
   `~/projects/secrets/bitwarden.env`, then redeploy via the pipeline
   (`glab ci run -R administrators/bitwarden -b main`). Re-test that
   https://bitwarden.ai-servicers.com no longer offers "Create account".

3. **Create the org + collections** (web vault, logged in as administrator):
   org `ai-servicers`; collections `administrators` and `developers`.

4. **Create the first item:** under `administrators`, add a login item named
   `ib-gateway-live` with the live IB username/password.

5. **CLI round-trip from this host** (the whole point):
   ```bash
   export PATH="$HOME/.local/bin:$PATH"   # or use /usr/local/bin/bw if you promoted it
   bw login administrator@ai-servicers.com      # prompts for master password
   export BW_SESSION=$(bw unlock --raw)         # prompts, returns a session key
   bw sync
   bw get password "ib-gateway-live"            # should print the live password
   ```
   If that last line prints the password, the full Bitwarden-→-CLI path works and you can
   wire `export TWS_PASSWORD=$(bw get password "ib-gateway-live")` into
   `start.gateway.live.sh`.

6. **Confirm the weekly deploy mirror** (optional): the GitLab schedule (Sun 05:00 ET)
   runs the GitHub→GitLab mirror; pushing to GitHub then deploys within a week, or run
   `glab ci run -R administrators/bitwarden -b main` to deploy on demand.
