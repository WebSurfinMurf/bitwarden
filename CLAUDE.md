# Bitwarden (Vaultwarden)

## Overview
Self-hosted password manager using Vaultwarden (lightweight Bitwarden-compatible server).

## Quick Reference
| Property | Value |
|----------|-------|
| Container | bitwarden |
| Port | 80 (internal), 3012 (websocket) |
| URL | https://bitwarden.ai-servicers.com |
| Admin | https://bitwarden.ai-servicers.com/admin |
| Image | vaultwarden/server:latest |
| Status | Running |

## Networks
- traefik-net (172.25.0.12)

## Dependencies
- Traefik (reverse proxy, SSL)

## Data
- Volume: `/home/administrator/projects/data/bitwarden`

## Secrets
Location: `$HOME/projects/secrets/bitwarden.env`
- ADMIN_TOKEN (for /admin access)
- DOMAIN

## Logs
Auto-discovered by Promtail → Loki → Grafana

## Deployment (GitLab CI — do NOT run `docker compose` by hand)

Deploys go through the GitLab pipeline (`.gitlab-ci.yml`), not manual compose.

- **Source of truth: GitLab** (`administrators/bitwarden`, project id 52).
  Push to `main` triggers `deploy` → `test` → `mirror` (backup push to GitHub).
- **GitHub backup:** After successful deploy+test, `scripts/mirror-to-github.sh`
  pushes main + tags to `github.com:WebSurfinMurf/bitwarden` as a backup mirror.
  Mirror failure is `allow_failure: true` — it won't block deploys.
- **Deploy now / on demand:** trigger a pipeline on `main` —
  `glab ci run -R administrators/bitwarden -b main` (or GitLab UI "Run pipeline").
- **Runtime:** the `linuxserver-administrator` runner is the `gitlab-runner-admin`
  container (root, host docker.sock + `/home/administrator` mounted). `deploy`
  checks out GitLab (job token), sources the secrets file, and runs
  `./deploy.sh` against the host docker daemon; `test` runs `scripts/healthcheck.sh`.
- The host clone has two remotes: `origin` (GitLab) and `github` (backup).

## Common Commands
```bash
# Trigger a deploy (preferred)
glab ci run -R administrators/bitwarden -b main

# Logs
docker logs bitwarden --tail 50

# Manual fallback ONLY if GitLab is unavailable:
#   cd /home/administrator/projects/bitwarden
#   set -a; . $HOME/projects/secrets/bitwarden.env; set +a
#   ./deploy.sh
```

## Service Accounts (machine identities)

No Secrets Manager here — a machine identity is an ordinary Vaultwarden user scoped to one
collection. Pattern: **one collection + one account per app/environment.**

| Account | Collection | Role / permission |
|---------|------------|-------------------|
| `fireflyiii-model@ai-servicers.com` | `fireflyiii-model-server` | User / Can view |

Non-interactive read:
```bash
eval "$(./scripts/bw-service-session.sh $HOME/projects/secrets/fireflyiii-model-bw.env)"
bw get password "firefly_iii_access_token"
```

Gotchas:
- Every identity MUST set its own `BITWARDENCLI_APPDATA_DIR`. The default
  `~/.config/Bitwarden CLI` belongs to `administrator` (IB gateway flow) — sharing it
  clobbers that login.
- Creating an account needs a **signup window**, not an invite. SMTP is unconfigured, and an
  admin-panel invite creates a user row that makes the web vault show *login* instead of
  *register* (empty password hash → "Invalid master password"). Correct sequence: delete any
  stale row, set `SIGNUPS_ALLOWED=true` + `SIGNUPS_DOMAINS_WHITELIST=ai-servicers.com`,
  deploy, register at `/#/signup`, then set `SIGNUPS_ALLOWED=false` and deploy again.
- Admin API is rate-limited to ~3 auth attempts per 5 minutes.
- Collection nesting is display-only — access is never inherited from a parent collection.

---
*See directives.md for standards | Last Updated: 2026-07-25*
