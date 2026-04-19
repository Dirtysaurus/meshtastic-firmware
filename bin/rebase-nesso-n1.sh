#!/usr/bin/env bash

set -euo pipefail

# Rebase helper for keeping Arduino Nesso N1 branch in sync with meshtastic/firmware.
#
# Usage:
#   bin/rebase-nesso-n1.sh [feature_branch] [upstream_base]
#
# Example:
#   bin/rebase-nesso-n1.sh wip/arduino-nesso-n1 upstream/develop

FEATURE_BRANCH="${1:-wip/arduino-nesso-n1}"
UPSTREAM_BASE="${2:-upstream/develop}"
UPSTREAM_URL="https://github.com/meshtastic/firmware.git"
FORK_URL="https://github.com/fukuen/meshtastic-firmware.git"

ensure_remote() {
    local name="$1"
    local url="$2"

    if git remote get-url "$name" >/dev/null 2>&1; then
        echo "Remote '$name' already exists: $(git remote get-url "$name")"
    else
        echo "Adding remote '$name' -> $url"
        git remote add "$name" "$url"
    fi
}

main() {
    echo "==> Validating repository state"
    git rev-parse --is-inside-work-tree >/dev/null

    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Working tree is dirty. Commit or stash your changes before rebasing."
        exit 1
    fi

    ensure_remote upstream "$UPSTREAM_URL"
    ensure_remote fork "$FORK_URL"

    echo "==> Fetching remotes"
    git fetch --prune upstream
    git fetch --prune fork

    echo "==> Checking out feature branch: $FEATURE_BRANCH"
    git checkout "$FEATURE_BRANCH"

    echo "==> Enabling rerere (records conflict resolutions)"
    git config rerere.enabled true

    echo "==> Rebasing $FEATURE_BRANCH onto $UPSTREAM_BASE"
    set +e
    git rebase "$UPSTREAM_BASE"
    rebase_exit=$?
    set -e

    if [[ $rebase_exit -ne 0 ]]; then
        cat <<'MSG'
Rebase stopped due to conflicts.

Next steps:
  1. Resolve conflicts in each file.
  2. git add <resolved-files>
  3. git rebase --continue

To abort:
  git rebase --abort
MSG
        exit $rebase_exit
    fi

    echo "==> Optional sanity checks"
    echo "Run your target build/tests, for example:"
    echo "  pio run -e nesso_n1"

    echo "==> Done. Push to your fork (force-with-lease required after rebase):"
    echo "  git push --force-with-lease fork $FEATURE_BRANCH"
}

main "$@"
