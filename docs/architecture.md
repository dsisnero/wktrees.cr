# Architecture

TODO: Document the high-level architecture of work_trees.

The upstream Rust project is organized as follows (from `vendor/worktrunk/src/`):

- CLI entry point and command dispatch
- Worktree management (create, switch, list, remove)
- Git operations (worktree, branch, merge)
- Configuration and hooks
- Agent integration (Claude Code, etc.)
