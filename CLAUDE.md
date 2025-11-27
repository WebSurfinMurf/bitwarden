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
Location: `$HOME/secrets/bitwarden.env`
- ADMIN_TOKEN (for /admin access)
- DOMAIN

## Logs
Auto-discovered by Promtail → Loki → Grafana

## Common Commands
```bash
# Deploy
cd /home/administrator/projects/bitwarden && docker compose up -d

# Logs
docker logs bitwarden --tail 50

# Restart
docker compose restart bitwarden
```

---
*See directives.md for standards | Last Updated: 2025-11-27*
