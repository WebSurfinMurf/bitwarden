# Bitwarden (Vaultwarden)

Self-hosted password manager compatible with Bitwarden clients.

## Overview

**Vaultwarden** is a lightweight, unofficial Bitwarden server implementation written in Rust. It's fully compatible with official Bitwarden clients (web, desktop, mobile, browser extensions).

## Access

- **Web Vault**: https://bitwarden.ai-servicers.com
- **Admin Panel**: https://bitwarden.ai-servicers.com/admin

## Features

- ✅ Password vault with encryption
- ✅ Secure notes
- ✅ Credit cards & identity storage
- ✅ File attachments (up to 100MB each)
- ✅ Two-factor authentication (TOTP, U2F, Duo)
- ✅ Password generator
- ✅ Browser extensions
- ✅ Mobile apps (iOS/Android)
- ✅ Organization support (teams/sharing)
- ✅ Emergency access
- ✅ Password health reports

## Setup

### Initial Setup

1. **Open the web vault**: https://bitwarden.ai-servicers.com
2. **Create your account** (first user becomes admin)
3. **Install browser extension** (optional but recommended)

### Admin Panel Access

1. Go to: https://bitwarden.ai-servicers.com/admin
2. Enter admin token from `$HOME/projects/secrets/bitwarden.env`
3. Configure server settings

## Configuration

All settings are in: `$HOME/projects/secrets/bitwarden.env`

### Key Settings

- `DOMAIN`: Server URL (must be HTTPS for sync to work)
- `SIGNUPS_ALLOWED`: Enable/disable new user registration
- `INVITATIONS_ALLOWED`: Allow inviting new users
- `ADMIN_TOKEN`: Token for admin panel access

### Optional SMTP (Email)

Configure for:
- User invitations
- 2FA via email
- Emergency access notifications

Uncomment and configure SMTP settings in the env file.

## Client Apps

### Browser Extensions
- Chrome/Edge: Chrome Web Store
- Firefox: Firefox Add-ons
- Safari: App Store

### Desktop Apps
- Windows, macOS, Linux: https://bitwarden.com/download/

### Mobile Apps
- iOS: App Store
- Android: Google Play

**Server URL**: `https://bitwarden.ai-servicers.com`

## Security Best Practices

1. **Use strong master password** - Never forget it (unrecoverable!)
2. **Enable 2FA** - Add TOTP or U2F key
3. **Secure admin token** - Keep `$HOME/projects/secrets/bitwarden.env` safe
4. **Regular backups** - Backup `./data` directory
5. **HTTPS only** - Already configured via Traefik

## Backup & Restore

### Backup
```bash
cd /home/administrator/projects/bitwarden
tar -czf bitwarden-backup-$(date +%Y%m%d).tar.gz data/
```

### Restore
```bash
cd /home/administrator/projects/bitwarden
docker compose down
tar -xzf bitwarden-backup-YYYYMMDD.tar.gz
docker compose up -d
```

## Management

### View logs
```bash
docker compose logs -f
```

### Restart service
```bash
docker compose restart
```

### Update to latest version
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

### Can't login / sync issues
- Verify HTTPS is working: https://bitwarden.ai-servicers.com
- Check `DOMAIN` in env file matches actual URL
- Restart: `docker compose restart`

### Admin panel won't accept token
- Verify token in `$HOME/projects/secrets/bitwarden.env`
- Token must match exactly (no extra spaces)

### Browser extension can't connect
- Self-hosted server URL: `https://bitwarden.ai-servicers.com`
- Must use HTTPS (HTTP won't work)

## Data Location

- **Database**: `./data/db.sqlite3`
- **Attachments**: `./data/attachments/`
- **Icons**: `./data/icon_cache/`

## Important Notes

⚠️ **Master Password Recovery**: Impossible! Keep it safe.
⚠️ **Admin Token**: Required for admin panel access
✅ **HTTPS Required**: Already configured via Traefik
✅ **Compatible**: Works with all official Bitwarden clients

## Resources

- Vaultwarden Wiki: https://github.com/dani-garcia/vaultwarden/wiki
- Bitwarden Clients: https://bitwarden.com/download/
- Community Forum: https://vaultwarden.discourse.group/

---
*Deployed: 2025-10-01*
