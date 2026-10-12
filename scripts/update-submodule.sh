#!/usr/bin/env bash
# ==============================================================================
# update-submodule.sh: Updates the Joplin submodule to the latest release branch
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOPLIN_DIR="${REPO_ROOT}/joplin"

echo "==> Ensuring submodule is initialized..."
if [ ! -d "${JOPLIN_DIR}/.git" ] && [ ! -f "${JOPLIN_DIR}/.git" ]; then
  git -C "${REPO_ROOT}" submodule update --init --recursive joplin
fi

echo "==> Fetching branches and tags from upstream Joplin..."
cd "${JOPLIN_DIR}"
git fetch origin --depth=1 'refs/heads/release-*:refs/remotes/origin/release-*'

# Find the latest release branch
ALL_BRANCHES="$(git for-each-ref --format '%(refname:short)' 'refs/remotes/origin/release-*' | sed 's;origin/;;')"
RELEASE_BRANCHES="$(echo "$ALL_BRANCHES" | grep -P '^release-[0-9]+\.[0-9]+$' || true)"

if [ -z "$RELEASE_BRANCHES" ]; then
  echo "Error: No release branches found." >&2
  exit 1
fi

LATEST_RELEASE="release-$(echo "$RELEASE_BRANCHES" \
    | sed 's/^release-//' \
    | sort --version-sort \
    | tail -n1)"

echo "==> Latest detected release branch: ${LATEST_RELEASE}"

# Checkout the branch
if git show-ref --verify --quiet "refs/heads/${LATEST_RELEASE}"; then
  git checkout "${LATEST_RELEASE}"
  git pull origin "${LATEST_RELEASE}" || true
else
  git checkout -b "${LATEST_RELEASE}" "origin/${LATEST_RELEASE}"
fi

cd "${REPO_ROOT}"
# Update .gitmodules branch reference
git config -f .gitmodules submodule.joplin.branch "${LATEST_RELEASE}"

echo "==> Submodule successfully updated to ${LATEST_RELEASE} at commit $(git -C "${JOPLIN_DIR}" rev-parse --short HEAD)."
