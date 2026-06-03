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

## 2. Admin user account
- **Existing users in the vault: 1 — `websurfinmurf@gmail.com`** (created 2025-10-02,
  emailVerified: true, enabled, no orgs, no 2FA). This is the developer-side identity.
- **There is NO `administrator@ai-servicers.com` account.** An admin-owned account does
  not yet exist.
- `SIGNUPS_ALLOWED` final state: **on (true)** — left enabled so you can self-register.
- **SMTP is entirely unconfigured** (`SMTP_HOST`/`SMTP_FROM`/etc. all unset). Emailed
  *invites* therefore will NOT work — self-registration is the only viable path, which is
  fine because signups are open.
- **Action needed from you:**
  1. Go to https://bitwarden.ai-servicers.com → **Create account** → register
     `administrator@ai-servicers.com` and set your master password (yours to choose; I did
     not and cannot set it).
  2. Tell me when done, and I'll help you turn signups **off** (security — see §5).

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
  - Collection **`admin-infra`** — admin-only (live IB creds, infra secrets).
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
- Full `bw login`/`unlock`/`get` not possible without your master password — that's the
  end-to-end step for you to run after registering (see "What to test").

## 5. Findings / notes
- **bitwarden.env — recommended additions (NOT changed by me):**
  - After you register, set `SIGNUPS_ALLOWED=false` to stop the public from registering on
    a publicly-exposed vault. It is currently `true` and the vault is internet-facing via
    Traefik — anyone can create an account right now. Close it once your admin account exists.
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
   org `ai-servicers`; collections `admin-infra` and `developers`.

4. **Create the first item:** under `admin-infra`, add a login item named
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
