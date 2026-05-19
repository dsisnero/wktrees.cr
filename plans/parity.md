# WorkTrees — Crystal Port Parity Plan

**Upstream:** https://github.com/max-sixty/worktrunk (Rust, v0.51.0)
**Pinned:** `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (`vendor/worktrunk`)
**Inventory:** `plans/inventory/rust_port_inventory.tsv` (3703 items, 1675 API, 2028 tests)

---

## Phase 0: Foundation

### 0.1 Project Scaffolding
- [x] Git submodule (`vendor/worktrunk`, pinned at 8c6ed7e)
- [x] `shard.yml` with ameba dev dependency
- [x] `Makefile` (install, update, format, lint, test, clean)
- [x] `.ameba.yml`, `.rumdl.toml`
- [x] `docs/` baseline stubs
- [x] `README.md` + `AGENTS.md` with port attribution
- [x] `plans/inventory/` parity manifests
- [x] `scripts/` parity tooling bootstrapped
- [ ] `shard.yml` runtime dependencies decided

### 0.2 Core Types & Errors
- [x] Error hierarchy (`GitError`, `CommandError`, `WorktrunkError`, `Diagnostic` trait)
  - 35 GitError classes, 14 specs — commit 4781ae4
- [x] Repository type (`src/work_trees/git/repository.cr`, 9 specs)
  - `Repository.current`, `.at(path)`, `run_command`, `run_command_check`, `worktree_at`, `default_branch`
- [x] WorkingTree type (`src/work_trees/git/repository.cr`)
  - `run_command`, `head_sha`, `current_branch`, `worktree_name`
- [x] `Cmd` builder (`src/work_trees/cmd.cr`, 7 specs)
- [ ] Worktree list parsing (`git worktree list --porcelain`)
- [ ] Output formatting (`src/output/`, `src/styling/`)
- [ ] Tracing/logging infrastructure

### 0.3 Template Engine (ECR divergence)
- [x] Custom filters ported: `sanitize`, `sanitize_db`, `sanitize_hash`, `hash`, `hash_port`, `dirname`, `basename`, `codename`, `redact_credentials`
  - `src/work_trees/template/filters.cr` — 27 specs, all passing
  - `src/work_trees/template/codename.cr` — 9 specs, all passing
  - **Codename parity verified:** SHA-256 output matches upstream for all 6 test vectors
- [x] Template variable types & context structs
  - `src/work_trees/template/context.cr` — 7 specs, all passing
  - `HookType`, `ValidationScope`, `ACTIVE_VARS`, `REPO_VARS`, etc.
- [ ] Shell template generation (bash, zsh, fish, nushell, powershell) via ECR
- [ ] Runtime template expansion for user/project config templates
- [ ] `ShellArgs` equivalent for alias args handling

### 0.4 Config System
- [ ] TOML parsing (user config `~/.config/worktrunk/config.toml`)
- [ ] Project config (`.config/wt.toml`)
- [ ] Config deserialization (`UserConfig`, `ProjectConfig` structs)
- [ ] Config merging (user + project + env overrides)
- [ ] Config deprecation & migration
- [ ] Config state management (vars, markers, hints, CI cache, logs)
- [ ] Unknown key detection/warnings

### 0.5 Git Operations
- [ ] Git command execution wrapper
- [ ] Worktree list parsing (`git worktree list --porcelain`)
- [ ] Worktree creation (`git worktree add`)
- [ ] Worktree removal with cleanup
- [ ] Branch operations (list, delete, upstream)
- [ ] Integration detection (same-commit, ancestor, no-added-changes, trees-match, merge-adds-nothing, patch-id-match)
- [ ] Remote/PR resolution (GitHub, GitLab, Gitea, Azure DevOps)
- [ ] Diff computation & parsing
- [ ] Ref snapshot & SHA caching

---

## Phase 1: Core Commands (Minimum Viable)

### 1.1 `wt switch`
- [ ] CLI args (`SwitchArgs`: --create, --base, --execute, --clobber, --no-cd, --no-hooks)
- [ ] Branch resolution (shortcuts: `^`, `-`, `@`, `pr:N`, `mr:N`)
- [ ] Worktree creation with path template expansion
- [ ] Pre/post switch hooks
- [ ] `--execute` support
- [ ] Interactive picker (skim/TUI)
- [ ] Tests: `tests/switch.rs`, `tests/switch_interactive.rs`

### 1.2 `wt list`
- [ ] CLI args (`ListArgs`: --full, --branches, --remotes, --format)
- [ ] Table rendering (columns: Branch, Status, HEAD±, main↕, Remote⇅, Commit, Age, Message)
- [ ] JSON output format
- [ ] Progressive rendering (fast data first, slow data updates)
- [ ] CI status integration (GitHub, GitLab, Gitea, Azure)
- [ ] LLM branch summaries
- [ ] Statusline subcommand (PS1 prompt)
- [ ] Tests: `tests/list.rs`, `tests/branches.rs`, `tests/remotes.rs`

### 1.3 `wt remove`
- [ ] CLI args (`RemoveArgs`: --force, --force-delete, --foreground, --no-delete-branch, --no-hooks)
- [ ] Worktree removal pipeline (rename→trash→prune→delete)
- [ ] Branch deletion (with integration check)
- [ ] Pre/post remove hooks
- [ ] Recovery from partial operations
- [ ] Tests: `tests/remove.rs`

---

## Phase 2: Advanced Commands

### 2.1 `wt merge`
- [ ] CLI args (`MergeArgs`: --no-squash, --no-commit, --no-rebase, --no-remove, --no-ff, --no-hooks, --stage)
- [ ] Commit generation (LLM prompt rendering)
- [ ] Squash since branching
- [ ] Rebase onto target
- [ ] Fast-forward merge
- [ ] Post-merge cleanup (remove worktree)
- [ ] Pre/post merge hooks
- [ ] Tests: `tests/merge.rs`

### 2.2 `wt step`
- [ ] `step commit` — Stage + LLM commit
- [ ] `step squash` — Squash commits since branch
- [ ] `step rebase` — Rebase onto target
- [ ] `step push` — Fast-forward target to current
- [ ] `step diff` — Show all changes since branching
- [ ] `step copy-ignored` — Copy gitignored files between worktrees
- [ ] `step eval` — Evaluate a template expression
- [ ] `step for-each` — Run command in every worktree
- [ ] `step promote` — Swap branch into main worktree
- [ ] `step prune` — Remove merged worktrees/branches
- [ ] `step relocate` — Move worktrees to expected paths
- [ ] `step tether` — Run command, kill on remove

### 2.3 `wt hook`
- [ ] Hook loading & configuration (TOML parsing)
- [ ] Hook execution pipeline (single, concurrent, sequential)
- [ ] Hook filtering (user:/project: prefix)
- [ ] Hook types: pre/post-switch, pre/post-start, pre/post-commit, pre/post-merge, pre/post-remove
- [ ] `hook show` — Display configured hooks
- [ ] `hook run` — Execute hooks of specified type
- [ ] `hook run-pipeline` — Internal stdin protocol
- [ ] Tests: `tests/hooks.rs`

### 2.4 `wt config`
- [ ] `config shell {init,install,uninstall,show-theme,completions}`
- [ ] `config create [--project]`
- [ ] `config show [--full]`
- [ ] `config update` — Deprecation migration
- [ ] `config approvals {add,clear}`
- [ ] `config alias {show,dry-run}`
- [ ] `config plugins {claude,codex,opencode} {install,uninstall}`
- [ ] `config state *` — All state subcommands
- [ ] Shell integration wrapper (bash, zsh, fish, nushell, powershell)

---

## Phase 3: Shell & Integration

### 3.1 Shell Integration
- [ ] Shell detection (`current_shell()`)
- [ ] Shell config path discovery
- [ ] Shell wrapper scripts (bash, zsh, fish, nushell, powershell)
- [ ] `cd` and `--execute` directive file protocol
- [ ] Completion passthrough
- [ ] `config shell install` — Edit rc files
- [ ] `config shell uninstall` — Remove integration lines
- [ ] Tests: `tests/shell.rs`

### 3.2 LLM Integration
- [ ] Commit message generation (prompt building + LLM invocation)
- [ ] Squash message generation
- [ ] Branch summary generation
- [ ] Template-append (user + project guidance)
- [ ] Tests: `tests/llm.rs`

### 3.3 Completions
- [ ] Dynamic shell completions (bash, zsh, fish)
- [ ] Static completion generation (`clap_complete` equivalent)
- [ ] `src/completion.rs` (1050 lines)

### 3.4 Interactive Picker (TUI)
- [ ] Fuzzy-finder integration (skim equivalent in Crystal)
- [ ] Preview pane (diff, log)
- [ ] Progressive handler
- [ ] Pager configuration

---

## Phase 4: Polish & Extras

### 4.1 Cross-Platform Support
- [ ] Signal forwarding (Unix)
- [ ] Platform-specific path handling
- [ ] Windows support considerations

### 4.2 Performance
- [ ] Parallel processing (rayon → Crystal fibers/channels)
- [ ] Caching (RepoCache, SHA cache)
- [ ] Concurrency control (semaphores)

### 4.3 Documentation & Quality
- [ ] Markdown help rendering
- [ ] CLI help text ported
- [ ] Adversarial parity verification pass
- [ ] Upstream test suite fully ported

---

## Divergences

### D1: Template Engine — ECR instead of minijinja + askama

**Upstream:** Two template engines:
- `minijinja` (v2.19) — Runtime template expansion for config/hooks/LLM prompts
- `askama` (v0.16) — Compile-time templates for shell wrapper scripts

**Crystal:** ECR (Embedded Crystal) for all template needs.

**Approach:**
1. **Shell wrapper templates** — Direct ECR port. Each shell template becomes an `ecr/` template file.
2. **Runtime template expansion** — For user-provided template strings in config (e.g., `worktree-path = "~/repo.{{ branch }}"`), implement a lightweight variable substitution engine (simple `{{ var }}` replacement + filters).
3. **Custom filters** — Port all 8 minijinja filters (`sanitize`, `sanitize_db`, `sanitize_hash`, `hash`, `hash_port`, `dirname`, `basename`, `codename`) as Crystal methods/modules.
4. **ShellArgs** — Implement as a Crystal struct with iteration and indexing support.
5. **Built-in filters** — Jinja2 builtins (`upper`, `lower`, `default`, `length`, `trim`, etc.) as needed, implemented as filter functions.
6. **LLM prompt templates** — Compile-time ECR templates with variable interpolation.

**Impact:** The template expansion system (`src/config/expansion.rs`, 2495 lines) is the largest single-file port. Splitting into ECR (compile-time) + variable substitution (runtime) reduces complexity.

### D2: CLI Framework — OptionParser instead of clap

**Upstream:** `clap` 4.x with derive macros for CLI argument parsing.

**Crystal:** `OptionParser` (stdlib) or a CLI shard. Decision TBD after evaluating Crystal CLI options.

### D3: Concurrency Model

**Upstream:** `rayon` for parallel iteration, `crossbeam-channel` for messaging, `dashmap` for concurrent maps.

**Crystal:** Native fibers and channels, `Concurrent::HashMap` or Crystal's `Channel(T)`.

### D4: TUI Picker

**Upstream:** `skim` (Rust fuzzy-finder) for interactive worktree picker.

**Crystal:** No direct skim equivalent. Options:
- Use Crystal's TUI libraries (e.g., `termbox` bindings)
- Shell out to `fzf`/`skim` binary
- Defer; the picker is a Phase 3/4 item

---

## Implementation Notes

<!-- Add notes here as porting progresses. Record decisions, blockers, and rationale for deviations. -->

### Notes

- **2026-05-18**: Project initialized. Submodule pinned at `8c6ed7e`. Parity manifests: 3703 items total.
- **2026-05-18**: ECR chosen as template engine. See Divergence D1 for details.
- **2026-05-18**: The upstream is **very large** (~120K lines, ~100 source files). Phased approach essential.
- **2026-05-18**: Core commands (switch, list, remove) should be the first target — they deliver 80% of user value.
- **2026-05-18**: Template filters ported. 36 specs passing. Codename filter verified byte-identical with upstream (SHA-256 determinism across languages). Petname v3.0.0 medium wordlists embedded at compile time via macros.
- **2026-05-18**: Repository + WorkingTree types ported (commit e9c925e). Basic git command execution working. 74 total specs.
- **2026-05-18**: Error types ported (commit 4781ae4). Crystal enum limitation required class-based approach for GitError variants.
- **2026-05-18**: OpenSSL used for SHA-256 in codename — dependency added implicitly via Crystal stdlib.
