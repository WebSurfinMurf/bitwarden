#!/bin/bash
# Poor-man's pull mirror: GitHub (source of truth) -> GitLab (CI mirror).
#
# GitLab Community Edition has no pull mirroring (Premium-only), so a weekly
# scheduled pipeline calls this script to re-check GitHub's `main` into GitLab.
# That push to GitLab then triggers the deploy pipeline (see .gitlab-ci.yml).
#
# Runs as the `administrator` user (the CI shell runner is root and hops here
# via `ssh administrator@localhost`, so administrator's SSH keys — which reach
# both GitHub and GitLab — are the ones in play). Operates on a dedicated
# scratch clone, never the live project working dir.
set -euo pipefail

MIRROR_DIR="$HOME/ci-mirror/bitwarden"
GITHUB_URL="git@github.com:WebSurfinMurf/bitwarden.git"
GITLAB_URL="ssh://git@gitlab.ai-servicers.com:2222/administrators/bitwarden.git"

if [ ! -d "$MIRROR_DIR/.git" ]; then
    echo "Creating scratch mirror clone at $MIRROR_DIR"
    mkdir -p "$(dirname "$MIRROR_DIR")"
    git clone --origin github "$GITHUB_URL" "$MIRROR_DIR"
fi

cd "$MIRROR_DIR"

# Ensure both remotes point where we expect (idempotent).
git remote set-url github "$GITHUB_URL" 2>/dev/null || git remote add github "$GITHUB_URL"
git remote set-url gitlab "$GITLAB_URL" 2>/dev/null || git remote add gitlab "$GITLAB_URL"

echo "Fetching github/main ..."
git fetch --prune github main

echo "Pushing github/main -> gitlab/main ..."
git push gitlab "refs/remotes/github/main:refs/heads/main"

echo "Mirror complete: github/main -> gitlab/main"
