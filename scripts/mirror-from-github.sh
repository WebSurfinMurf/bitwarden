#!/bin/bash
# Poor-man's pull mirror: GitHub (source of truth) -> GitLab (CI mirror).
#
# GitLab Community Edition has no pull mirroring (Premium-only), so a weekly
# scheduled pipeline calls this to re-check GitHub's `main` into GitLab
# (administrators/bitwarden). That push then triggers the deploy pipeline.
#
# Runs as root inside the gitlab-runner-admin container. The administrator's SSH
# keys are bind-mounted at /home/administrator/.ssh but $HOME is not honored by
# ssh in that context (it falls back to /root/.ssh), so keys are passed with
# absolute paths via GIT_SSH_COMMAND. GitHub uses id_ed25519; GitLab uses
# id_ed25519_gitlab on port 2222 (see administrator's ~/.ssh/config).
set -euo pipefail

MIRROR_DIR="${MIRROR_DIR:-/root/ci-mirror/bitwarden}"
GITHUB_URL="git@github.com:WebSurfinMurf/bitwarden.git"
GITLAB_URL="ssh://git@gitlab.ai-servicers.com:2222/administrators/bitwarden.git"

KEYDIR="/home/administrator/.ssh"
GH_SSH="ssh -i ${KEYDIR}/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
GL_SSH="ssh -i ${KEYDIR}/id_ed25519_gitlab -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

mkdir -p "$(dirname "$MIRROR_DIR")"
if [ ! -d "$MIRROR_DIR/.git" ]; then
    echo "Creating scratch mirror clone at $MIRROR_DIR"
    GIT_SSH_COMMAND="$GH_SSH" git clone --origin github "$GITHUB_URL" "$MIRROR_DIR"
fi

cd "$MIRROR_DIR"

# Ensure both remotes point where we expect (idempotent).
git remote set-url github "$GITHUB_URL" 2>/dev/null || git remote add github "$GITHUB_URL"
git remote set-url gitlab "$GITLAB_URL" 2>/dev/null || git remote add gitlab "$GITLAB_URL"

echo "Fetching github/main ..."
GIT_SSH_COMMAND="$GH_SSH" git fetch --prune github main

echo "Pushing github/main -> gitlab/main ..."
GIT_SSH_COMMAND="$GL_SSH" git push gitlab "refs/remotes/github/main:refs/heads/main"

echo "Mirror complete: github/main -> gitlab/main"
