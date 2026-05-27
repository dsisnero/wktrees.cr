#!/usr/bin/env bash
# Cross-platform wrapper for the work_trees CLI.
# If WORKTREES_BIN is set, uses that path exclusively.
# Otherwise uses work_trees from PATH.
# Usage: wt.sh [args...]

if [[ -n "$WORKTREES_BIN" ]]; then
    if ! command -v "$WORKTREES_BIN" >/dev/null 2>&1; then
        echo "work_trees: WORKTREES_BIN is set to '$WORKTREES_BIN' but it was not found" >&2
        exit 1
    fi
    WT="$WORKTREES_BIN"
else
    WT=work_trees
fi

if [[ -z "$WT" ]] || ! command -v "$WT" >/dev/null 2>&1; then
    echo "work_trees: could not find 'work_trees' in PATH" >&2
    exit 1
fi

"$WT" "$@"
