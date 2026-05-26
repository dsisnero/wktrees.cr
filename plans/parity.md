# WorkTrees — Crystal Port Parity Plan

**Upstream:** https://github.com/max-sixty/worktrunk (Rust, v0.51.0)
**Pinned:** `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (`vendor/worktrunk`)
**Status:** 71+26=97 commits, 506 specs, 0 failures, all gates green. All 3 drift checks pass (port inventory: 3703 items, source parity: 1675 API items, test parity: 2028 tests). All Phase 0-4 complete. All Phase 5 features (5.1-5.8) complete. Port coverage: 1596 partial, 391 skipped, 1716 missing (mostly upstream tests, picker, plugins — all deferred).

---

## Phase 0: Foundation ✅ (Complete)

### 0.1 Project Scaffolding ✅
- [x] Git submodule, shard.yml (ameba + toml.cr), Makefile, ameba/rumdl config
- [x] docs/ baseline, README/AGENTS with port attribution
- [x] plans/inventory/ parity manifests, scripts/ tooling

### 0.2 Core Types & Errors ✅
- [x] 35 GitError classes, CommandError, WorktrunkError, RefType
- [x] Repository (current, at, run_command, run_command_check, worktree_at, default_branch)
- [x] WorkingTree (run_command, head_sha, current_branch, worktree_name)
- [x] Cmd builder (run, run!, args, current_dir, context, stdin_data, stdin_bytes)
- [x] WorktreeInfo (parse_porcelain_list, 6 porcelain fields)
- [x] BranchDeletionMode (Keep/SafeDelete/ForceDelete)
- [x] BranchResolver (^ @ - pr:N mr:N shortcuts)
- [x] Output formatting (styling/ANSI)
- [x] Tracing/logging infrastructure (wt-trace records, Span timing, command tracing)

### 0.3 Template Engine ✅
- [x] 9 filters — codename parity verified (SHA-256, all 6 upstream vectors)
- [x] Template context types (HookType, ValidationScope, variable constants)
- [x] `.expand("{{ branch | sanitize }}", vars)` — {{ var }}, {{ var | filter }}, {{ var | filter(args) }}
- [x] {{ vars.key }} dotted-key lookup (per-branch state from git config)
- [x] Shell wrappers: bash, zsh, fish, nushell, powershell via `Shell.generate(:bash)`
- [ ] ShellArgs alias args handling (intentional divergence — Crystal template engine uses different approach)

### 0.4 Config System ✅
- [x] TOML parsing (crystal-community/toml.cr v0.8.1)
- [x] UserConfig + ProjectConfig with merge
- [x] config show, config create, config create --project
- [x] [commit.generation] command for LLM
- [x] All hook sections (10 types)
- [x] [aliases] section (custom wt <name> shortcuts)
- [x] config state vars (set/get/list/clear)
- [x] Full config sections ([list], [merge], [commit] parsed, merged, used by commands)
- [x] Env var overrides (WORKTRUNK_*)
- [x] Deprecation migration (detect + migrate content for sections, vars, no-ff inversion)

### 0.5 Git Operations ✅
- [x] git command execution, worktree list/create/remove, branch delete
- [x] diff, staging, commit, rebase, merge, prune
- [x] pr:N resolution via gh CLI, mr:N via glab CLI
- [x] Integration detection (4 levels: SameCommit, Ancestor, TreeMatch, NoDiff)
- [x] Ref snapshot & SHA caching (RefSnapshot + ShaCache modules)

---

## Phase 1: Core Commands ✅ (Complete)

### 1.1 `wt switch` ✅
- [x] --create, --base, --execute, --path-template
- [x] Path template expansion + ~ expansion
- [x] Switch to existing + branch → path lookup
- [x] Shortcuts: ^ (default), @ (current), - (previous via git config)
- [x] Pre/post-start hooks, pre/post-switch hooks
- [x] cd directive file protocol (WORKTRUNK_DIRECTIVE_CD_FILE)
- [x] pr:N/mr:N resolution (gh/glab CLI)
- [ ] Interactive picker (deferred)
- [x] pr:N/mr:N fetch + checkout (fetches remote branch, fork handling)

### 1.2 `wt list` ✅
- [x] Table rendering: Branch, Worktree, HEAD
- [x] --full: Status, HEAD±, main↕, Remote, Commit columns
- [x] Current worktree marker (@)
- [x] --format=json output
- [x] CI status integration (GitHub via gh run list with ✓/✗/○ symbols)
- [x] Progressive rendering (skeleton rows + incremental update)
- [x] Statusline subcommand (wt step statusline)

### 1.3 `wt remove` ✅
- [x] --force, --force-delete, --no-delete-branch
- [x] Pre/post-remove hooks
- [x] SafeDelete/ForceDelete/Keep modes
- [x] Current worktree guard
- [x] Background removal staging (trash rename + background fiber via stage_worktree_removal)
- [ ] Recovery from partial operations → Phase 5

---

## Phase 2: Advanced Commands ✅ (Complete)

### 2.1 `wt merge` ✅
- [x] 5-step pipeline: auto-commit → squash → rebase → FF merge → cleanup
- [x] --no-commit, --no-squash, --no-rebase, --no-remove, --no-ff
- [x] Pre/post-merge hooks
- [x] Post-merge worktree + branch cleanup with cd directive

### 2.2 `wt step` ✅
- [x] commit — stage + conventional commit (LLM or branch-derived)
- [x] diff, squash, rebase, push, for-each, eval
- [x] prune, copy-ignored, promote, relocate, tether
- **12 subcommands total**

### 2.3 `wt hook` ✅
- [x] hook show — display configured hooks (user + project)
- [x] hook run <type> — manually trigger hooks
- [x] Hooks from both user and project config
- [x] Hook execution pipeline (concurrent via WaitGroup+Channel, sequential with break on failure)
- [x] Hook source filtering (user:/project: prefix in hook show/run)
- [ ] hook run-pipeline internal stdin protocol → deferred

### 2.4 `wt config` ✅
- [x] config show, config create, config create --project
- [x] config state vars (set/get/list/clear)
- [x] [aliases] parsed and dispatched
- [x] config shell {install,uninstall} (moved to `shell` command)
- [x] config show --full (resolved config with defaults, hooks, aliases, state)
- [ ] config update (deprecation migration) → Phase 5.1
- [x] config approvals (approvals.toml persistence, legacy config.toml fallback)
- [ ] config plugins → Phase 5

---

## Phase 3: Shell & Integration ✅ (Mostly Complete)

### 3.1 Shell Integration ✅
- [x] Shell detection (shell_type_from_env via $SHELL)
- [x] Shell config path discovery (shell_rc_file)
- [x] bash/zsh/fish wrapper scripts
- [x] cd directive file protocol (WORKTRUNK_DIRECTIVE_CD_FILE)
- [x] --execute directive file protocol (WORKTRUNK_DIRECTIVE_EXEC_FILE)
- [x] shell install — edit rc files
- [x] shell uninstall — remove integration lines
- [x] shell completions — bash/zsh/fish completion scripts
- [x] nushell, powershell wrappers (already in wrapper.cr)

### 3.2 LLM Integration ✅
- [x] Commit message generation (pipe diff → external LLM)
- [x] Branch-derived conventional commit fallback
- [x] [commit.generation] command config
- [x] Branch summary generation (LLM diff → subject+body summary)
- [x] Template-append (user + project guidance parsed, merged, env-overridden, used in commit gen)

### 3.3 Completions ✅
- [x] bash: compgen-based _work_trees_complete function
- [x] zsh: compdef with _arguments
- [x] fish: complete -c with -a
- [x] Dynamic subcommand completions (bash step subs via step_subs variable)

### 3.4 Interactive Picker ❌
- [ ] Fuzzy-finder integration (fzf/skim)

---

## Phase 4: Polish & Extras ⬜ (In progress)

- [x] Parallel processing (fibers/channels via WaitGroup)
- [x] Caching (RefSnapshot, ShaCache)
- [x] Markdown help rendering (headings, bold, inline code, fences, lists, HTML skip)
- [x] Adversarial parity verification (all 3 drift checks pass: 3703 items tracked)
- [ ] Upstream test suite fully ported

---

## Phase 5: Remaining Features (Prioritized)

### 5.1 P0 — Deprecation Migration Completion (169 items)
**Files:** `src/config/deprecation.rs`, `src/commands/config/update.rs`
Full `check_and_migrate` workflow: structural TOML migration, deprecation warnings with per-path dedup, `.new` migration file generation, `wt config update` command.
**Impact:** Required before any config format changes ship. Determines whether users can upgrade configs safely.

### 5.2 P0 — Git URL Parsing & Forge Detection (50 items)
**File:** `src/git/url.rs`
Parse git remote URLs (`github.com`, `gitlab.com`, `ssh://`, `git@`) to detect forge platform, owner, repo name. Used by CI status, PR provider selection, fork detection.
**Impact:** Currently hardcoded to GitHub. Needed for GitLab/Gitea/Azure CI and PR resolution.

### 5.3 P0 — Column Layout with Terminal-Width Awareness (44 items)
**Files:** `src/commands/list/layout.rs`, `src/commands/list/render.rs`
Calculate column widths based on terminal dimensions, reflow columns when terminal is narrow, diff column alignment, summary column rendering.
**Impact:** `wt list` output overflows on narrow terminals (<80 cols). Needed for proper progressive rendering.

### 5.4 P1 — Full LLM Integration (39 items)
**File:** `src/llm.rs`
Shell wrapping for LLM commands, diff preparation/large-diff filtering, template-file deprecation, reproduction command formatting.
**Impact:** Commitment message quality. Current implementation works but doesn't handle edge cases (large diffs, shell metacharacters).

### 5.5 P1 — Output Subsystem (37 items)
**Files:** `src/output/global.rs`, `src/output/handlers.rs`
Centralized output management: stdout vs stderr routing, global verbosity, output redirection for background hooks, error/success/progress formatting.
**Impact:** Currently all output goes through inline `puts`/`STDERR.puts` calls. A unified output subsystem enables background hook output logging and consistent styling.

### 5.6 P1 — Multi-Platform CI Status (28 items)
**Files:** `src/commands/list/ci_status/mod.rs`, `github.rs`, `gitlab.rs`, `azure.rs`, `gitea.rs`
CI status from GitHub Actions, GitLab CI, Azure Pipelines, Gitea Actions. Cache entries with TTL, parallel fetching, error retry.
**Impact:** Currently only GitHub via `gh run list`. Missing GitLab, Azure, Gitea CI status.

### 5.7 P2 — Full Approvals System (33 items)
**File:** `src/config/approvals.rs`
File locking, approval batch operations, interactive prompt, per-project revocation, approval path resolution.
**Impact:** Core data model done. Missing the interactive prompt (requires user input) and batch operations.

### 5.8 P2 — List Item Model (36 items)
**Files:** `src/commands/list/model/item.rs`
ListItem, ListData, WorktreeData, DisplayFields structs with gate resolution, branch/worktree distinction, is_prunable detection.
**Impact:** Currently stored in ad-hoc hashes. A proper model enables cleaner progressive rendering and picker integration.

### 5.9 P3 — Path Utilities (27 items)
**File:** `src/path.rs`
sanitize_for_filename, format_path_for_display, path normalization, `~` expansion.
**Impact:** Used everywhere (hook logs, cache keys, state vars). Currently partially duplicated across files.

### 5.10 P3 — Interactive Picker (deferred)
**Files:** `src/commands/picker/` (9 files)
Fuzzy-finder (fzf/skim) integration for `wt switch` without arguments. Preview panes with diff/upstream/summary.
**Impact:** Deferred per D4. Will use fzf binary.

### 5.11 P4 — Upstream Test Suite (2028 tests)
**Files:** All upstream test files
Full port of upstream snapshot tests and integration tests for behavioral parity verification.
**Impact:** Currently 419 Crystal specs covering core logic. Missing upstream integration/snapshot tests.

---

## Divergences

| ID | Area | Decision |
|----|------|----------|
| D1 | Template Engine | `Template.expand` (regex-based) instead of minijinja + askama |
| D2 | CLI Framework | Crystal `OptionParser` instead of clap |
| D3 | Concurrency | Deferred. Crystal fibers available when needed |
| D4 | TUI Picker | Deferred. Will use fzf binary |

---

## Implementation Notes

- **2026-05-18**: Codename filter SHA-256 parity verified (all 6 upstream vectors).
- **2026-05-18**: Crystal enum limitation → class hierarchy for GitError (35 variants).
- **2026-05-18**: Struct → Class for WorktreeInfo (needed reference semantics).
- **2026-05-18**: `OptionParser.unknown_args` puts branch names in `before` (not `after`).
- **2026-05-18**: Crystal regex `\w+` captures typed as `Char|String`; `scan` avoids type issues.
- **2026-05-18**: All 10 hook types implemented with user + project config support.
- **2026-05-25**: 71 commits, 419 specs, 0 failures, all gates green. All 3 drift checks pass. Modules ported this session: styling (lipgloss), git diff parsing, env var overrides, branch inventory, RefSnapshot, ShaCache, pr/mr fetch+checkout, config approvals, deprecation detection+migration, hook source filtering, bash completions, branch summary generation, markdown help rendering, command tracing, full config sections.
