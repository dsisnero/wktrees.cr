---
name: wt-switch-create
description: Create a new wktrees worktree (optionally in another repo) and switch this session's working directory into it. Use when launching a session that should work in its own worktree (e.g. `/wt-switch-create my-branch -- <task>`, or `/wt-switch-create my-branch ~/workspace/other-repo -- <task>`), or mid-session to move work into a fresh branch.
argument-hint: "<branch-name> [<repo>] [-- task...]"
license: MIT
compatibility: Requires the `wktrees` CLI (Crystal port of worktrunk)
---

Arguments: `$ARGUMENTS`. Grammar: `<branch> [<repo>] [-- <task>]`.

- **branch** — required first token; the branch name for the new worktree.
- **repo** — optional path; create the worktree in this repo instead of the
  session's current one.
- **task** — optional; what to do inside the new worktree. No task means enter
  the worktree and wait.

Without a `--`: a path-shaped second token (absolute, `~`-relative, `./`- or
`../`-relative, or an existing directory) is the repo, and the task starts
after it. Otherwise the task starts at the second token.

```
/wt-switch-create my-feature -- fix the parser bug
/wt-switch-create my-feature ~/workspace/other-repo -- fix the parser bug
/wt-switch-create my-feature
```

## What to do

1. **First action — before reading any files or running any commands:**
   - `wktrees switch --create <branch-name>` — creates or re-enters the worktree
   - `wktrees switch --create` is idempotent: if the branch already exists, this
     just re-enters its worktree.
   - If `wktrees switch --create` fails (not a git repo, invalid branch name, etc.),
     report the error and stop — do not fall back to working in the original
     directory, since that defeats the purpose.

2. After the switch succeeds, do the task in the new worktree. If there was
   no task text, confirm the worktree is ready and wait for the next
   instruction.

## Cleanup

Don't remove the worktree yourself. Run `wktrees remove` (if the
user asks to leave). A worktree with uncommitted
changes won't be auto-removed without confirmation — that's intended.

## Scope

This command authorizes creating/entering ONE worktree — in the named repo, if
one was given — and doing the requested task. Commits, pushes, and merges still
each require explicit user permission.
