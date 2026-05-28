# wktrees — Crystal Port Parity Plan

**Upstream:** https://github.com/max-sixty/worktrunk (Rust, v0.51.0)
**Pinned:** `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (`vendor/worktrunk`)
**Status:** 110+ commits, 653 specs, 0 failures, all gates green. All 3 drift checks pass (port inventory: 3703 items, source parity: 1675 API items, test parity: 2028 tests). Phases 0-4 feature-complete. Phase 5 features 5.1-5.9 complete. Interactive picker Phase A+B+D-start done (bubbletea TUI), Phase D finish (alt-c/alt-r/cache) remaining.

**Binary:** `wktrees` (shard: `wktrees`, module: `WorkTrees`)
**Shards:** toml, lipgloss, bubbles (→ bubbletea.cr transitively)
**Skills:** `skills/wktrees/`, `skills/wt-switch-create/`, `plugins/wktrees/`

---

## Phase 0: Foundation ✅ (Complete)

### 0.1 Project Scaffolding ✅
- [x] Git submodule, shard.yml (ameba + toml.cr + lipgloss + bubbles), Makefile, ameba config
- [x] docs/, README/AGENTS, skills/, plugins/wktrees/
- [x] plans/inventory/ parity manifests, plans/interactive_picker.md, scripts/ tooling

### 0.2 Core Types & Errors ✅
- [x] 35 GitError classes, CommandError, WorktrunkError, RefType
- [x] Repository, WorkingTree, Cmd builder, WorktreeInfo
- [x] BranchDeletionMode (Keep/SafeDelete/ForceDelete)
- [x] BranchResolver (^ @ - pr:N mr:N shortcuts)
- [x] Output formatting via lipgloss: Styling module (symbols, messages, gutter, format_toml, fix_dim, truncate, StyledLine)
- [x] Tracing via Trace module: wt-trace records, Span timing, command tracing
- [x] Trace::Span on CLI.run, config.load_default, Template.expand, Cmd.run

### 0.3 Template Engine ✅
- [x] 9 filters — codename parity verified (SHA-256, all 6 upstream vectors)
- [x] Template.expand with {{ var }}, {{ var | filter }}, {{ var | filter(args) }}
- [x] {{ vars.key }} dotted-key lookup (per-branch state from git config)
- [x] Shell wrappers: bash, zsh, fish, nushell, powershell
- [x] TemplateVars builder (from vendor template_vars.rs)
- [ ] ShellArgs alias args handling (intentional divergence)

### 0.4 Config System ✅
- [x] TOML parsing, UserConfig + ProjectConfig with merge
- [x] config show/create/state + project config
- [x] Full sections: [list], [merge], [commit], [remove], [switch]
- [x] [commit.generation] for LLM, [aliases], 10 hook types
- [x] Env var overrides (WORKTRUNK_*)
- [x] Deprecation detection + migrate_content + check_and_migrate
- [x] Approvals system (TOML persistence, legacy fallback, atomic saves, batch ops)
- [x] ProjectForgeConfig (platform/hostname with ci_platform detection)
- [ ] Config plugins → deferred

### 0.5 Git Operations ✅
- [x] git command execution, worktree list/create/remove, branch delete
- [x] diff, staging, commit, rebase, merge, prune
- [x] pr:N/mr:N resolution (gh/glab CLI)
- [x] LineDiff + DiffStats (parse_numstat_line, parse_shortstat, format_summary)
- [x] Integration detection (4 levels: SameCommit, Ancestor, TreeMatch, NoDiff)
- [x] RefSnapshot + ShaCache (branch inventory, immutable ref capture, SHA-keyed cache)
- [x] GitRemoteUrl (HTTPS/SSH/git@ parsing, forge detection, nested GitLab groups)
- [x] Recovery module (backup paths, staged fallback, cleanup results)

---

## Phase 1: Core Commands ✅ (Complete)

### 1.1 `wktrees switch` ✅
- [x] --create, --base, --execute, --path-template
- [x] Path template expansion + ~ expansion
- [x] Switch to existing + branch → path lookup
- [x] Shortcuts: ^ (default), @ (current), - (previous via git config)
- [x] Pre/post-start hooks, pre/post-switch hooks
- [x] cd directive file + --execute directive protocol
- [x] pr:N/mr:N resolution (gh/glab CLI) + fetch + checkout + fork handling
- [x] Interactive picker: Phase A+B+D-start done (bubbletea TUI with list+viewport, 5 preview modes, Enter select, is_current marker, TTY fallback)
- [ ] Interactive picker: Phase D finish (alt-c create, alt-r remove, persistent cache) → see plans/interactive_picker.md

### 1.2 `wktrees list` ✅
- [x] Table rendering: Branch, Worktree, HEAD
- [x] --full: Status, HEAD±, main↕, Remote, Commit columns
- [x] Current worktree marker (@), --format=json output
- [x] CI status (GitHub/GitLab/Azure/Gitea via platform detection)
- [x] Progressive rendering (skeleton rows + incremental update)
- [x] Statusline subcommand (wktrees step statusline)
- [x] Column layout (proportional width allocation, lipgloss StyleTable)
- [x] List render module (compact numbers K/C/∞, diff display, placeholder symbols)
- [x] ListItem model (JSON::Serializable), JsonOutput types, DisplayFields, ListData.statusline

### 1.3 `wktrees remove` ✅
- [x] --force, --force-delete, --no-delete-branch
- [x] Pre/post-remove hooks, SafeDelete/ForceDelete/Keep modes
- [x] Current worktree guard
- [x] Background removal staging (trash rename + background fiber)
- [x] Recovery from partial operations (backup paths, staged fallback, CleanupResult)

---

## Phase 2: Advanced Commands ✅ (Complete)

### 2.1 `wktrees merge` ✅
- [x] 5-step pipeline: auto-commit → squash → rebase → FF merge → cleanup
- [x] --no-commit, --no-squash, --no-rebase, --no-remove, --no-ff
- [x] Pre/post-merge hooks, post-merge cleanup with cd directive

### 2.2 `wktrees step` ✅
- [x] 12 subcommands: commit, diff, squash, rebase, push, for-each, eval, prune, copy-ignored, promote, relocate, tether, statusline

### 2.3 `wktrees hook` ✅
- [x] hook show — display configured hooks (user + project)
- [x] hook run <type> — manually trigger hooks
- [x] Hook source filtering (user:/project: prefix)
- [x] Hook execution pipeline (concurrent via WaitGroup+Channel, sequential with break)
- [ ] hook run-pipeline internal stdin protocol → deferred

### 2.4 `wktrees config` ✅
- [x] config show, create, create --project
- [x] config state vars (set/get/list/clear)
- [x] [aliases] parsed and dispatched
- [x] config shell {install,uninstall}, shell completions
- [x] config show --full (resolved config with defaults)
- [x] config update (deprecation migration)
- [x] config approvals (persistence, legacy fallback, batch, atomic saves)
- [x] config plugins → Tier 2 custom subcommand dispatch + plans/plugins.md

---

## Phase 3: Shell & Integration ✅ (Complete)

### 3.1 Shell Integration ✅
- [x] Shell detection, config path discovery, wrappers (bash/zsh/fish/nu/ps)
- [x] cd directive + --execute directive protocols
- [x] shell install/uninstall/completions
- [x] Invocation module (binary_name, is_git_subcommand?, explicit_path detection)

### 3.2 LLM Integration ✅
- [x] Commit message generation (pipe diff → external LLM)
- [x] Branch-derived conventional commit fallback
- [x] Branch summary generation (LLM diff → subject+body summary)
- [x] [commit.generation] command config, template-append
- [x] LLM helpers: prepare_diff (truncation), shell_wrap_command (metacharacter detection)

### 3.3 Completions ✅
- [x] bash: compgen-based, zsh: compdef, fish: complete
- [x] Dynamic step subcommand completions (bash step_subs variable)

### 3.4 Interactive Picker ✅ (Phase A+B+D-start complete)
- [x] Phase A: PickerItem, PreviewMode, Model (Tea::Model + Bubbles::List + Bubbles::Viewport)
- [x] Phase B: 5 preview modes (WorkingTree, Log, BranchDiff, UpstreamDiff, Summary) with async loading
- [x] Phase D start: Enter select with selected_branch, is_current marker, TTY guard with fallback
- [x] Wired into wktrees switch (no args) flow
- [ ] Phase D finish: alt-c create, alt-r remove, persistent disk cache

---

## Phase 4: Polish & Extras ✅ (Complete)

- [x] Parallel processing (WaitGroup)
- [x] Caching (RefSnapshot, ShaCache)
- [x] Markdown help rendering (headings, bold, inline code, fences, lists, HTML skip)
- [x] Adversarial parity verification (all 3 drift checks pass)
- [x] Path utilities (sanitize_for_filename, format_path_for_display, expand_home)
- [x] Display utilities (format_relative_time_short, truncate_to_width)
- [x] Command log (JSONL audit logging with rotation)
- [ ] Upstream test suite fully ported → deferred

---

## Phase 5: Remaining Features (Prioritized) ✅

### 5.1 ✅ Deprecation Migration Completion — `src/work_trees/config/deprecation.cr`
Detect deprecated patterns, migrate content, check_and_migrate, compute_migrated_content.

### 5.2 ✅ Git URL Parsing — `src/work_trees/git/url.cr`
Parse HTTPS/SSH/git@ URLs, nested GitLab groups, forge detection, parse_owner_repo.

### 5.3 ✅ Column Layout — `src/work_trees/cli.cr`
Proportional column width allocation, lipgloss StyleTable rendering, narrow terminal support.

### 5.4 ✅ Full LLM Integration — `src/work_trees/cli.cr`
Diff truncation (max_chars, max_files, max_lines), shell metacharacter wrapping, summary generation.

### 5.5 ✅ Output Subsystem — `src/work_trees/output.cr`
Global verbosity (0/1/2), stdout vs stderr routing, -v/-vv CLI parsing, command_output gutter.

### 5.6 ✅ Multi-Platform CI Status — `src/work_trees/ci_status.cr`
CiPlatform detection, CiStatus symbols, per-platform fetchers (gh/glab/az/tea), wired into list.

### 5.7 ✅ Full Approvals System — `src/work_trees/config/approvals.cr`
TOML persistence, legacy fallback, batch operations, atomic saves, each_project iteration.

### 5.8 ✅ List Item Model — `src/work_trees/list/item.cr`
ListItem, DisplayFields, ListData with JSON::Serializable, statusline formatting.

### 5.9 ✅ Path Utilities — `src/work_trees/path_util.cr`
sanitize_for_filename, format_path_for_display with Path.home, expand_home.

### 5.10 ⬜ Interactive Picker (Phase D finish remaining)
bubbletea TUI with Bubbles::List + Bubbles::Viewport, 5 preview modes, async loading, TTY guard. Remaining: alt-c create, alt-r remove, persistent cache. → see plans/interactive_picker.md

### 5.11 ❌ Upstream Test Suite (deferred)
2028 upstream tests not yet ported to Crystal specs.

---

## Divergences

| ID | Area | Decision |
|----|------|----------|
| D1 | Template Engine | `Template.expand` (regex-based) instead of minijinja + askama |
| D2 | CLI Framework | Crystal `OptionParser` instead of clap |
| D3 | Concurrency | Crystal fibers + WaitGroup instead of rayon thread pool |
| D4 | TUI Picker | Integrated bubbletea TUI with Bubbles::List instead of shelling out to fzf/skim |
| D5 | CLI Name | Binary renamed to `wktrees` (shorter to type); module namespace is `WorkTrees` |

---

## Truly Remaining (Deferred)

These require major infrastructure, external tools, or are intentionally skipped:

| Item | Reason |
|------|--------|
| Config plugins (Claude/Codex/OpenCode) | Tier 2 custom subcommand dispatch implemented; plugin architecture documented in plans/plugins.md |
| hook run-pipeline stdin protocol | Internal protocol for background pipelines |
| Upstream test suite (2028 tests) | Gradual porting, snapshot/integration tests |
| ShellArgs alias args handling | Different template engine architecture (D1) |
| Interactive picker Phase D finish | Needs real terminal for testing (alt-c, alt-r, cache) |

---

## Implementation Notes

- **2026-05-18**: Codename filter SHA-256 parity verified (all 6 upstream vectors).
- **2026-05-18**: Crystal enum limitation → class hierarchy for GitError (35 variants).
- **2026-05-18**: Struct → Class for WorktreeInfo (needed reference semantics).
- **2026-05-18**: `OptionParser.unknown_args` puts branch names in `before` (not `after`).
- **2026-05-25**: 110+ commits, 653 specs, 0 failures. All 3 drift checks pass. Full port: Phase 0-4 complete, Phase 5.1-5.9 complete, interactive picker Phase A+B+D-start done. 65+ commits this session. Shards: lipgloss, bubbles (→ bubbletea.cr). Binary: `wktrees` v0.2.0.
