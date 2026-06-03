# Bitwarden / Vaultwarden — admin CLI integration setup

**Requestor:** administrator (me, asking via this doc)
**Executor:** another AI on this host (you, reading this)
**Goal:** prepare the existing Vaultwarden install for headless / interactive CLI use by the human administrator, so I can use it as the credential medium for live IB Gateway secrets (and other admin secrets later).

## Why this matters

I'm replacing the current `~/projects/secrets/*.env` model for sensitive credentials (specifically the live IB brokerage account creds I'm about to provision) with a Bitwarden vault lookup at runtime. The goal pattern is:

```bash
# Admin types master password once at gateway start, then:
export TWS_PASSWORD=$(bw get password "ib-gateway-live")
```

For this to work, the Vaultwarden server has to be (a) on a current version, (b) reachable from the host, (c) have an admin-owned user account ready, and (d) have the standard Bitwarden CLI installed somewhere on the host where I can call it. None of that has been touched before.

## Current state (what I already know — verify before doing anything)

- Container `bitwarden` running image `vaultwarden/server:latest` on `traefik-net` (172.25.0.12). Up 3 weeks healthy.
- URL: `https://bitwarden.ai-servicers.com`
- Admin endpoint: `https://bitwarden.ai-servicers.com/admin` (gated by `ADMIN_TOKEN` from `~/projects/secrets/bitwarden.env`)
- Compose: `~/projects/bitwarden/docker-compose.yml`
- Data volume: `/home/administrator/projects/data/bitwarden`
- Bitwarden CLI (`bw`) is **not** currently installed on the host (verify with `which bw`).
- This is Vaultwarden, **not** official Bitwarden Server. That matters for one thing: **Bitwarden Secrets Manager (BWS) is enterprise-only and not supported by Vaultwarden.** Don't try to set up BWS — use the regular `bw` CLI with master password / API key auth instead.

## Tasks (in order)

### 1. Verify + update Vaultwarden to latest — via GitLab CI, NOT manual `docker compose`

**Deployment is GitLab-centric.** Do **not** run `docker compose` by hand. The deploy
runs through the GitLab pipeline (`.gitlab-ci.yml`): the `deploy` job sshes to
`administrator@localhost` and runs `./deploy.sh` (which does the `docker compose
pull/down/up`), then a `test` job health-checks the result. Mechanism:

- **Source of truth is GitHub** (`git@github.com:WebSurfinMurf/bitwarden.git`). GitLab
  CE has no pull mirroring, so a **weekly scheduled pipeline** (Sunday 05:00
  America/New_York) runs `scripts/mirror-from-github.sh` to re-check GitHub's `main`
  into GitLab (`administrators/bitwarden`); that push triggers `deploy` → `test`.
- To upgrade Vaultwarden, you therefore either (a) wait for the Sunday sync, or
  (b) **trigger a pipeline now** — a manual run on `main` (GitLab UI "Run pipeline",
  or `glab ci run -b main`) fires `deploy` + `test` immediately. `deploy.sh` already
  pulls `vaultwarden/server:latest` and recreates the container in place.

Verification (the `test` job does the first two automatically; confirm the rest):

- `test` job hits `https://bitwarden.ai-servicers.com/alive` and `/api/version`.
- Confirm version bump via `docker logs bitwarden 2>&1 | grep -i version | head` or `/api/version`.
- Verify data volume `~/projects/data/bitwarden/` survived (don't recreate the volume; the migration is in-place).
- Confirm `/admin` page still loads with the existing `ADMIN_TOKEN`.
- **Report**: old version → new version (commit/tag), that the data dir is intact, and the pipeline URL.

### 2. Confirm or create the administrator user account

- Log into `/admin` with `ADMIN_TOKEN` and check the user list.
- If a user with email `administrator@ai-servicers.com` (or whatever email is set in `bitwarden.env`'s `SMTP_FROM`/contact field) exists → fine, note its email and verified status.
- If no admin user exists → create one. Preferred path:
  - If `SIGNUPS_ALLOWED=true` is currently set, the human admin can self-register at `https://bitwarden.ai-servicers.com`. If that's the case, **leave signup enabled briefly, tell me, and I'll register myself**. Then turn signup off again.
  - If `SIGNUPS_ALLOWED=false`, use the `/admin` UI's "Invite User" function to send an invite to `administrator@ai-servicers.com`. Verify the SMTP config is working first (Vaultwarden logs will show send attempts).
- **Do not** set the master password for the admin account yourself — that's mine to choose and remember. You only ensure the account *exists* and is invitable / registerable.
- **Report**: admin user email, account status (active / invited / needs-self-register), and whether `SIGNUPS_ALLOWED` was left on or off after.

### 2b. Set up the structure for the `developers` Linux group (recommended)

Look ahead: the developer side of the house (websurfinmurf and anyone else in the `developers` Linux group on this host, `gid 3000`) will need their own Bitwarden access to mirror this pattern for **paper** trading creds. Get the structure ready now even if we don't invite anyone yet.

Preferred structure inside Vaultwarden:

- **Organization**: `ai-servicers` (single org for the household; Vaultwarden organizations are how you share items across users).
- **Collections within the org**:
  - `admin-infra` — admin-only items (live IB creds, root passwords, infra secrets). Only the administrator user has access.
  - `developers` — developer-side items (paper IB creds, dev tooling). Members of the `developers` Linux group get invited as Bitwarden members with access to this collection only.
- The administrator's **personal vault** (not in the org) can also hold admin-only items — either approach is fine. The collection split inside the org is what actually enforces dev/admin separation.

What to do in this task:
- Do NOT create the organization yet — that requires my logged-in user. **Note in your response** that this structure is intended and that I should create it after first login.
- Verify the Vaultwarden install supports organizations (it does in current versions, but confirm — older configs sometimes had `ORG_CREATION_USERS` restrictions).
- Check the existing `~/projects/secrets/bitwarden.env` for `ORG_CREATION_USERS`. If it's set to a specific email and not mine, flag it. If unset, organizations can be created by any user — fine.
- **Report**: confirmation that org creation is enabled, current setting of `ORG_CREATION_USERS`.

### 3. Install Bitwarden CLI on the host

- Target binary: official Bitwarden CLI `bw` (npm or precompiled). Install at `/usr/local/bin/bw` so it's on PATH for the `administrator` user. Either:
  - Download the precompiled Linux binary from `https://bitwarden.com/download/?app=cli&platform=linux` (preferred — no Node.js dependency), `chmod +x`, drop in `/usr/local/bin/`.
  - Or `npm install -g @bitwarden/cli` (only if Node is already installed system-wide; don't install Node just for this).
- Pin the version installed (record what you put).
- Configure CLI to point at our self-hosted server:
  ```
  bw config server https://bitwarden.ai-servicers.com
  ```
  This writes config under `~administrator/.config/Bitwarden CLI/data.json` (or similar). Run as the `administrator` user, not root.
- Verify with `bw status` (should report `unauthenticated` + the correct server URL).
- **Report**: install method, version, `bw status` output, config file path.

### 4. Sanity-check the round-trip (without my master password)

You can't log in as me (you don't have my master password), but you can verify the plumbing works at the layer below that:

- From the host as `administrator` user: `curl -fs https://bitwarden.ai-servicers.com/api/version` (should return JSON with version).
- `bw login --help` should run (CLI is wired up).
- `bw status` should report the server URL correctly.
- If you have a throwaway test account credentials you can use (or one provisioned for testing), `bw login --apikey` flow and a single `bw sync` would be useful. Otherwise skip.
- **Report**: the outputs.

### 5. Document anything you discovered

- If you found that the existing `bitwarden.env` is missing a setting that should be added for CLI flows (e.g., `SIGNUPS_ALLOWED`, `DOMAIN`, SMTP config), flag it but do not modify `~/projects/secrets/bitwarden.env` yourself. Just describe what's missing and what value it should be.
- If anything about the compose file (`~/projects/bitwarden/docker-compose.yml`) blocked the upgrade or surfaced as suboptimal during the recreate, note it.
- If the upgrade revealed new env-var requirements in this Vaultwarden version, list them.

## What I do NOT want you to do

- Do not create any vault items, organizations, or collections — that's mine to set up once I'm logged in. (You can recommend the structure for me to follow; that's task 2b.)
- Do not invite websurfinmurf or anyone in the `developers` Linux group to Bitwarden yet — that step waits until I've created the org and the `developers` collection. Just identify *who* would be invited.
- Do not store any credentials in `bitwarden.env` you find during this work.
- Do not modify `~/projects/secrets/*`.
- Do not enable / disable `SIGNUPS_ALLOWED` permanently without telling me; toggle is fine, but report the final state.
- Do not change the data volume location or path.
- Do not switch from Vaultwarden to official Bitwarden Server.

## Deliverable (what to report back)

Write your findings to `~/projects/bitwarden/docs/admin-cli-integration.response.md` with these sections, even if a section is short:

```markdown
# Response — Bitwarden admin CLI integration

## 1. Vaultwarden version
- Before: vX.Y.Z
- After:  vX.Y.Z
- Data dir intact: yes/no
- /admin still works: yes/no

## 2. Admin user account
- Email: administrator@ai-servicers.com (or actual)
- Status: active / invited / needs-self-register
- SIGNUPS_ALLOWED final state: on / off
- Action needed from me: e.g. "go to https://bitwarden.ai-servicers.com and click Create Account before I turn signup off"

## 2b. Organization / developers-group readiness
- Organizations enabled: yes / no
- ORG_CREATION_USERS value: [paste or "unset"]
- Existing users in /admin who are in the `developers` Linux group (for later invite): [list emails]
- Notes:

## 3. CLI install
- Binary path: /usr/local/bin/bw
- Version: vA.B.C
- Install method: precompiled / npm
- Config: ~administrator/.config/Bitwarden CLI/data.json
- bw status output: [paste]

## 4. Round-trip sanity check
- curl /api/version output: [paste]
- bw status output: [paste]

## 5. Findings / notes
- Anything missing in bitwarden.env that should be added (describe, don't change)
- Anything about the compose file worth knowing
- Anything you couldn't do and why
```

Once I have that file, I'll: (a) self-register or accept the invite, (b) set my master password, (c) create the `ai-servicers` org + `admin-infra` and `developers` collections per the structure in task 2b, (d) create the first vault item (`ib-gateway-live` username/password) under `admin-infra`, (e) verify `bw login && bw unlock && bw get password "ib-gateway-live"` works end-to-end from this host, then (f) write the `start.gateway.live.sh` that uses it.

A follow-up doc will cover **the mirror for the developers group**: getting websurfinmurf (and any other `developers`-group user) onto Bitwarden, scoped to the `developers` collection only, so they can do the same Bitwarden-→-CLI pattern for paper trading creds in their own image build. That doc isn't your responsibility — but the structure you set up here (org + two collections) is what makes it possible without later rework.
