# Changelog

All notable changes to the Crystal port of Worktrunk will be documented here.

## [0.2.0] — 2026-05-25

### Binary Rename — `work_trees` → `wktrees`

The CLI binary has been renamed from `work_trees` to `wktrees` for faster typing.
All user-facing help text, error messages, and shell wrappers updated. Source code
module name (`WorkTrees`) preserved for backward compatibility.

### Interactive Picker (Phase A+B+D-start)

- **Bubbletea TUI**: Integrated picker using `dsisnero/bubbles` (Bubbles::List + Bubbles::Viewport)
- **5 Preview Modes**: WorkingTree (git diff HEAD), Log (git log --graph), BranchDiff (diff vs default), UpstreamDiff (diff vs upstream), Summary (LLM)
- **Async Loading**: Background preview computation via Tea::Cmd fibers
- **Keyboard**: Enter to select, 1-5 for preview tabs, q/ctrl-c to quit, alt-c to create, alt-r to remove
- **TTY Guard**: Falls back to first worktree in non-TTY environments (pipes, CI)
- **is_current Marker**: Current worktree highlighted with @ prefix

### Styling (lipgloss)

- **Message Symbols**: ◎ ✓ ✗ ▲ ↳ ○ ❯ with terminal-aware truecolor ANSI
- **Message Formatting**: error_message, hint_message, warning_message, success_message, progress_message, info_message, prompt_message, format_heading
- **Gutter Formatting**: format_with_gutter with word-wrap, format_bash_with_gutter
- **TOML Highlighting**: format_toml with section header + key-value styling
- **Terminal Fixes**: fix_dim_after_color_reset for Claude Code compatibility
- **Width Utilities**: visual_width, truncate_visible, StyledLine (width-tracked segments)
- **Inline Helpers**: red, yellow, bold, dim, green, cyan

### Configuration

- **Full Config Sections**: list, merge, commit, remove, switch parsed, merged, env-overridden
- **Env Var Overrides**: WORKTRUNK_WORKTREE_PATH, WORKTRUNK_COMMIT__GENERATION__COMMAND, etc.
- **Deprecation System**: detect_deprecations, migrate_content, check_and_migrate, compute_migrated_content
- **Approvals System**: TOML persistence, legacy config fallback, batch operations, atomic saves
- **ProjectForgeConfig**: forge.platform / forge.hostname with ci_platform detection

### Git Operations

- **Git URL Parsing**: HTTPS, SSH, git@ formats with nested GitLab group support
- **Forge Detection**: github?, gitlab?, gitea?, azure? (including *.dev.azure.com subdomains)
- **RefSnapshot**: Immutable ref state capture with ahead/behind caching
- **ShaCache**: SHA-keyed JSON cache with LRU sweep (6 cache kinds, 5000 entries/kind)
- **LineDiff + DiffStats**: parse_numstat_line, parse_shortstat, format_summary
- **Recovery Module**: CleanupResult tracking, backup path generation, staged fallback

### CI Status

- **Multi-Platform**: GitHub (gh), GitLab (glab), Azure DevOps (az), Gitea (tea)
- **Platform Detection**: Auto-detect from git remote URL
- **Status Symbols**: ✓ (success), ✗ (failure), ○ (pending), ? (unknown)

### LLM Integration

- **Branch Summary**: LLM diff → subject+body summary via configured command
- **Diff Preparation**: prepare_diff with max_chars/max_files/max_lines truncation
- **Shell Wrapping**: shell_wrap_command for metacharacter detection

### Output & Tracing

- **Output Subsystem**: Global verbosity (0/1/2), stdout vs stderr routing, -v/-vv CLI flags
- **Command Tracing**: [wt-trace] records with ts, tid, cmd, dur_us, ok fields
- **Trace::Span**: Block-based auto-timing for config load, template expansion, Cmd.run
- **Command Log**: JSONL audit logging to .git/wt/logs/commands.jsonl with 1MB rotation

### List Improvements

- **Column Layout**: Proportional width allocation with terminal-width awareness
- **Compact Numbers**: K (thousands), C (hundreds), ∞ (10K+) for diff/commit counts
- **List Render**: Skeleton rows, placeholder symbols (·), bold headers
- **ListItem Model**: JSON::Serializable structs (ListItem, DisplayFields, ListData)
- **JsonOutput**: Structured JSON types (JsonItem, JsonCommit, JsonWorkingTree, JsonCi, etc.)

### Plugin System

- **Tier 1 (Config)**: Hooks, aliases, templates, LLM commands (already built-in)
- **Tier 2 (Custom Subcommands)**: `wktrees-<name>` binaries on PATH or `.work_trees/bin/`
- **Project-Local Plugins**: `.work_trees/bin/` searched before system PATH
- **Architecture**: plans/plugins.md documents 5 scenarios evaluated

### Shell & Completions

- **All 5 Shells**: bash, zsh, fish, nushell, powershell wrappers
- **Dynamic Completions**: bash step subcommand completion
- **Hook Source Filtering**: user:/project: prefix in hook show/run

### New Modules

| Module | File | Source |
|--------|------|--------|
| Styling | `src/work_trees/styling.cr` | lipgloss-powered |
| Output | `src/work_trees/output.cr` | verbosity + routing |
| Trace | `src/work_trees/trace.cr` | wt-trace records |
| CommandLog | `src/work_trees/command_log.cr` | JSONL audit log |
| DisplayUtil | `src/work_trees/display_util.cr` | time + truncation |
| PathUtil | `src/work_trees/path_util.cr` | sanitize + expand |
| Invocation | `src/work_trees/invocation.cr` | binary name detection |
| GitRemoteUrl | `src/work_trees/git/url.cr` | URL parsing + forge |
| CiPlatform/CiStatus | `src/work_trees/ci_status.cr` | multi-platform CI |
| RefSnapshot | `src/work_trees/git/ref_snapshot.cr` | immutable ref capture |
| ShaCache | `src/work_trees/git/sha_cache.cr` | SHA-keyed JSON cache |
| LineDiff/DiffStats | `src/work_trees/git/diff.cr` | diff statistics |
| Recovery | `src/work_trees/git/recovery.cr` | partial op recovery |
| PrResolver | `src/work_trees/git/pr_resolver.cr` | PR/MR fetch+checkout |
| LocalBranch/RemoteBranch | `src/work_trees/git/branches.cr` | branch inventory |
| Config Sections | `src/work_trees/config/sections.cr` | RemoveConfig, SwitchConfig, etc. |
| Approvals | `src/work_trees/config/approvals.cr` | TOML persistence |
| Deprecation | `src/work_trees/config/deprecation.cr` | detect + migrate |
| JsonOutput | `src/work_trees/list/json_output.cr` | JSON::Serializable types |
| ListItem | `src/work_trees/list/item.cr` | structured list model |
| ListRender | `src/work_trees/list/render.cr` | compact numbers + skeleton |
| Picker | `src/work_trees/picker.cr` | bubbletea TUI picker |
| TemplateVars | `src/work_trees/template_vars.cr` | hook variable builder |
| Markdown Help | `src/work_trees/cli.cr` | render_markdown |
| Column Layout | `src/work_trees/cli.cr` | calculate_column_widths |
| LLM Helpers | `src/work_trees/cli.cr` | prepare_diff, shell_wrap |

### Divergences Updated

- **D4**: TUI picker now uses integrated bubbletea TUI instead of fzf binary
- **D5**: Binary renamed to `wktrees` (shorter to type)

### Dependencies Added

- `dsisnero/lipgloss` — terminal styling (ANSI, borders, tables)
- `dsisnero/bubbles` — TUI components (List, Viewport, TextInput, etc.)

### Skills & Plugin Layout

- `skills/wktrees/SKILL.md` — AI agent guidance for config, hooks, workflows
- `skills/wt-switch-create/SKILL.md` — worktree creation workflow
- `plugins/wktrees/` — Claude/Codex plugin manifest with activity hooks

---

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
  - bubbletea TUI interactive picker when run without arguments (Phases A+B+D complete)
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
