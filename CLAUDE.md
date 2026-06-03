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

- **Source of truth: GitHub** (`github.com:WebSurfinMurf/bitwarden`). GitLab CE has
  no pull mirroring, so a **weekly scheduled pipeline** (Sun 05:00 ET) runs
  `scripts/mirror-from-github.sh` to re-check GitHub's `main` into GitLab
  (`administrators/bitwarden`, project id 52); that push triggers `deploy` → `test`.
- **Deploy now / on demand:** trigger a pipeline on `main` —
  `glab ci run -R administrators/bitwarden -b main` (or GitLab UI "Run pipeline").
- **Runtime:** the `linuxserver-administrator` runner is the `gitlab-runner-admin`
  container (root, host docker.sock + `/home/administrator` mounted). `deploy`
  checks out the GitLab mirror (job token), sources the secrets file, and runs
  `./deploy.sh` against the host docker daemon; `test` runs `scripts/healthcheck.sh`.
- The host clone has two remotes: `origin` (GitHub) and `gitlab` (push target).

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

---
*See directives.md for standards | Last Updated: 2026-06-02*
