#!/usr/bin/env bash
# Cross-platform wrapper for the wktrees CLI.
# If WORKTREES_BIN is set, uses that path exclusively.
# Otherwise uses wktrees from PATH.
# Usage: wt.sh [args...]

if [[ -n "$WORKTREES_BIN" ]]; then
    if ! command -v "$WORKTREES_BIN" >/dev/null 2>&1; then
        echo "wktrees: WORKTREES_BIN is set to '$WORKTREES_BIN' but it was not found" >&2
        exit 1
    fi
    WT="$WORKTREES_BIN"
else
    WT=wktrees
fi

if [[ -z "$WT" ]] || ! command -v "$WT" >/dev/null 2>&1; then
    echo "wktrees: could not find 'wktrees' in PATH" >&2
    exit 1
fi

"$WT" "$@"
