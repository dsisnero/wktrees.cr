# Changelog

All notable changes to the Crystal port of Worktrunk will be documented here.

## [0.1.0] — 2026-05-19

### Initial Release — Crystal Port of Worktrunk v0.51.0

Ported from [max-sixty/worktrunk](https://github.com/max-sixty/worktrunk) (Rust v0.51.0, pinned at `8c6ed7e`).

### Commands

- **list** — List worktrees with branch info, compact/full/JSON formats
  - `--full`: Status, HEAD±, main↕, Remote, Commit, CI columns
  - `--format=json`: JSON array output
  - Skeleton-first progressive rendering
- **switch** — Switch to or create worktrees
  - `--create`: Create new branch + worktree
  - `--base`: Specify base branch
  - `--execute`: Run command after switching
  - `--path-template`: Customize worktree path
  - `--no-hooks`: Skip hook execution
  - Shortcuts: `^` (default), `@` (current), `-` (previous), `pr:N`, `mr:N`
  - fzf interactive picker when run without arguments
  - Shell cd directive protocol
- **remove** — Remove worktrees and optionally branches
  - `--force`/`-f`: Force removal of dirty worktree
  - `--force-delete`/`-D`: Force delete unmerged branch
  - `--no-delete-branch`: Keep branch after removal
  - Staged background removal with trash rename
- **step** — Individual operations (13 subcommands)
  - `commit`: Stage + conventional commit (LLM or branch-derived)
  - `diff`: Show staged + unstaged diff
  - `squash`: Soft-reset to merge-base
  - `rebase`: Rebase onto target
  - `push`: Fast-forward merge into target
  - `for-each`: Run command in every worktree
  - `eval`: Evaluate template expression
  - `prune`: Remove merged worktrees/branches
  - `copy-ignored`: Copy gitignored files between worktrees
  - `promote`: Swap branch into primary worktree
  - `relocate`: Move worktrees to config-computed paths
  - `tether`: Run command, kill on worktree removal
  - `statusline`: Compact PS1 prompt segment
- **merge** — 5-step pipeline: auto-commit → squash → rebase → FF merge → cleanup
  - `--no-commit`, `--no-squash`, `--no-rebase`, `--no-remove`, `--no-ff`
- **hook** — Show or run configured hooks
  - `show`: Display hooks from user + project config
  - `run <type>`: Manually trigger hooks
- **config** — Manage configuration
  - `show`: Display config file
  - `show --full`: Resolved config with defaults
  - `create`: Scaffold config file
  - `create --project`: Scaffold project config (`.config/wt.toml`)
  - `state vars`: Per-branch variables (set/get/list/clear)
  - `[aliases]`: Custom `wt <name>` shortcuts
- **shell** — Shell integration
  - `init [bash|zsh|fish|nu|ps]`: Generate wrapper script (auto-detects)
  - `install`: Install into shell rc file
  - `uninstall`: Remove from shell rc file
  - `completions [bash|zsh|fish]`: Generate completion scripts

### Global Flags

- `--yes`/`-y`: Skip prompts, reduce output
- `--version`/`-V`: Print version
- `--help`/`-h`: Print help

### Hooks

All 10 hook types: pre/post-start, pre/post-switch, pre/post-commit, pre/post-merge, pre/post-remove.
- **Concurrent**: `[section]` named hooks run in parallel via WaitGroup
- **Pipeline**: `[[section]]` array-of-tables run sequentially, stop on failure

### Templates

9 filters: `sanitize`, `sanitize_db`, `sanitize_hash`, `hash`, `hash_port`, `dirname`, `basename`, `codename`, `redact_credentials`.
- **Codename parity**: SHA-256 output matches upstream for all 6 test vectors
- `{{ vars.key }}`: Per-branch state variable interpolation
- `{{ var | filter(args) }}`: Full filter pipeline syntax

### Configuration

- User config: `~/.config/worktrees/config.toml` (TOML)
- Project config: `.config/wt.toml` (TOML, shared with team)
- Config merge: project overrides user for path template
- LLM: `[commit.generation]` with `command`, `template`, `template-append`

### Shell Integration

- 5 shell wrappers: bash, zsh, fish, nushell, powershell
- cd directive protocol via `WORKTRUNK_DIRECTIVE_CD_FILE`
- exec directive protocol via `WORKTRUNK_DIRECTIVE_EXEC_FILE`
- Completions for bash, zsh (context-aware subcommands), fish

### Concurrency

- Parallel list stats via Crystal fibers + WaitGroup + Mutex
- Parallel hook execution via WaitGroup + Channel
- Background removal staging via spawn

### Error Handling

35 typed error classes with graceful fallback for missing executables.

### Dependencies

- Crystal >= 1.20.2
- [crystal-community/toml.cr](https://github.com/crystal-community/toml.cr) v0.8.1

### Divergences from Upstream

- **D1**: Template engine — Crystal `Template.expand` (regex-based) instead of minijinja + askama
- **D2**: CLI framework — Crystal `OptionParser` instead of clap
- **D3**: Concurrency — Crystal fibers/WaitGroup/Channel instead of rayon/crossbeam
- **D4**: TUI picker — fzf binary integration instead of skim
