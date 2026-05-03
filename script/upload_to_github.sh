#!/usr/bin/env bash
# Cria o repositório no GitHub (conta pessoal) e faz o push inicial.
# Requer: git, gh (GitHub CLI) autenticado em https://github.com/luisgsilva950.

set -euo pipefail

REPO_NAME="${REPO_NAME:-rails-chatbot-app}"
VISIBILITY="${VISIBILITY:-private}"  # private | public
DESCRIPTION="${DESCRIPTION:-Rails 8 chatbot powered by ruby_llm with ActionCable streaming.}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

cd "$(dirname "$0")/.."

command -v git >/dev/null || { echo "git not found"; exit 1; }
command -v gh  >/dev/null || { echo "gh CLI not found (https://cli.github.com)"; exit 1; }

gh auth status >/dev/null 2>&1 || { echo "gh not authenticated. Run: gh auth login"; exit 1; }

OWNER="$(gh api user --jq .login)"
echo "==> GitHub user: $OWNER"
echo "==> Repository : $OWNER/$REPO_NAME ($VISIBILITY)"

if [ ! -d .git ]; then
  echo "==> Initializing git repo"
  git init -b "$DEFAULT_BRANCH"
fi

git rev-parse --verify HEAD >/dev/null 2>&1 || {
  echo "==> Creating initial commit"
  git add -A
  git commit -m "Initial commit"
}

git symbolic-ref --short HEAD | grep -qx "$DEFAULT_BRANCH" || git branch -M "$DEFAULT_BRANCH"

if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "==> Repo already exists on GitHub"
else
  echo "==> Creating repo on GitHub"
  gh repo create "$OWNER/$REPO_NAME" \
    --"$VISIBILITY" \
    --description "$DESCRIPTION" \
    --source=. \
    --remote=origin \
    --push
  echo "==> Done: https://github.com/$OWNER/$REPO_NAME"
  exit 0
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/$OWNER/$REPO_NAME.git"
else
  git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
fi

echo "==> Pushing $DEFAULT_BRANCH to origin"
git push -u origin "$DEFAULT_BRANCH"

echo "==> Done: https://github.com/$OWNER/$REPO_NAME"
