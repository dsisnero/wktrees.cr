# WorkTrees — Crystal Port Parity Plan

**Upstream:** https://github.com/max-sixty/worktrunk (Rust, v0.51.0)
**Pinned:** `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (`vendor/worktrunk`)
**Inventory:** `plans/inventory/rust_port_inventory.tsv` (3703 items, 1675 API, 2028 tests)
**Status:** 16 commits, 126 specs, 0 failures

---

## Phase 0: Foundation ✅

### 0.1 Project Scaffolding
- [x] Git submodule (`vendor/worktrunk`, pinned at 8c6ed7e)
- [x] `shard.yml` with ameba + toml.cr dependencies
- [x] `Makefile` (install, update, format, lint, test, clean)
- [x] `.ameba.yml`, `.rumdl.toml`
- [x] `docs/` baseline stubs
- [x] `README.md` + `AGENTS.md` with port attribution
- [x] `plans/inventory/` parity manifests
- [x] `scripts/` parity tooling bootstrapped

### 0.2 Core Types & Errors
- [x] Error hierarchy: 35 GitError classes, CommandError, WorktrunkError, RefType
- [x] Repository type: current, at(path), run_command, run_command_check, worktree_at, default_branch
- [x] WorkingTree type: run_command, head_sha, current_branch, worktree_name
- [x] Cmd builder: run, run!, args, current_dir, context, stdin_data, stdin_bytes
- [x] WorktreeInfo: parse_porcelain_list, all 6 porcelain fields
- [x] BranchDeletionMode: Keep, SafeDelete, ForceDelete
- [x] BranchResolver: ^, @ shortcuts
- [ ] Output formatting (styling/ANSI module)
- [ ] Tracing/logging infrastructure

### 0.3 Template Engine (ECR divergence)
- [x] 9 filters: sanitize, sanitize_db, sanitize_hash, hash, hash_port, dirname, basename, codename, redact_credentials
  - **Codename parity verified:** SHA-256 output matches upstream for all 6 test vectors
- [x] Template context types: HookType, ValidationScope, variable constants
- [x] Runtime template expansion: `Template.expand("{{ branch | sanitize }}", vars)`
  - Supports `{{ var }}`, `{{ var | filter }}`, `{{ var | filter(args) }}`
- [x] Shell template generation: bash, zsh, fish wrappers via `Shell.generate(:bash)`
- [ ] nushell, powershell shell wrappers
- [ ] ShellArgs alias args handling

### 0.4 Config System
- [x] TOML parsing (crystal-community/toml.cr v0.8.1)
- [x] UserConfig: worktree_path_template, llm_command
- [x] Config.load_user / parse_user / load_default
- [x] `config show` — display current config
- [x] `config create` — scaffold config file
- [x] Nested config: `[commit.generation] command` for LLM
- [x] `[pre-start]`, `[post-start]`, etc. hook sections
- [ ] Project config (`.config/wt.toml`)
- [ ] Full config sections (list, merge, remove, switch settings beyond path)
- [ ] Env var overrides (`WORKTRUNK_*`)
- [ ] Deprecation migration

### 0.5 Git Operations
- [x] Git command execution via Cmd builder + Repository.run_command
- [x] Worktree list parsing (`git worktree list --porcelain`)
- [x] Worktree creation (`git worktree add -b <branch> <path> <base>`)
- [x] Worktree removal (`git worktree remove`)
- [x] Branch deletion (`git branch -d/-D`)
- [x] Diff (`git diff --stat`)
- [x] Staging (`git add -u/-A`)
- [x] Commit (`git commit -m`)
- [x] Rebase (`git rebase <target>`)
- [x] Merge (`git merge --ff-only`)
- [ ] Integration detection (6 levels: SameCommit, Ancestor, etc.)
- [ ] Remote/PR resolution (GitHub/GitLab/Gitea/Azure DevOps via gh/glab)
- [ ] Ref snapshot & SHA caching

---

## Phase 1: Core Commands ✅

### 1.1 `wt switch`
- [x] CLI args: --create, --base, --execute, --path-template
- [x] Worktree creation with path template expansion + ~ expansion
- [x] Switch to existing worktree (branch → path lookup)
- [x] Branch shortcuts (^ for default, @ for current)
- [x] Pre/post-start hooks (for --create)
- [x] Pre/post-switch hooks (for existing switch)
- [ ] `-` shortcut (previous branch — needs state tracking)
- [ ] `pr:N` / `mr:N` PR/MR resolution
- [ ] Interactive picker (deferred to Phase 3/4)
- [ ] Shell integration `cd` via directive files

### 1.2 `wt list`
- [x] Table rendering: Branch, Worktree, HEAD columns
- [x] --full/-f flag for detailed view (bare, full SHA)
- [x] Current worktree marker (@)
- [x] OptionParser argument parsing
- [ ] CI status integration (GitHub/GitLab/Gitea/Azure)
- [ ] Diff stats (commits ahead/behind, changes ±)
- [ ] JSON output format (`--format=json`)
- [ ] Progressive rendering
- [ ] Statusline subcommand (PS1 prompt)

### 1.3 `wt remove`
- [x] CLI args: --force, --force-delete, --no-delete-branch
- [x] Worktree removal via `git worktree remove`
- [x] Branch deletion with SafeDelete/ForceDelete/Keep modes
- [x] Guards: prevents removing current worktree
- [x] Pre/post-remove hooks
- [ ] Background removal staging (trash directory rename)
- [ ] Recovery from partial operations

---

## Phase 2: Advanced Commands (partial)

### 2.1 `wt merge`
- [x] Basic merge: rebase onto target, fast-forward merge
- [x] Pre/post-merge hooks
- [x] OptionParser args plus unknown_args for target branch
- [ ] --no-squash, --no-commit, --no-rebase, --no-remove, --no-ff flags
- [ ] Auto-commit before merge (LLM commit)
- [ ] Post-merge cleanup (remove worktree)
- [ ] Squash commits since branching
- [ ] Verbose merge output (files changed, etc.)

### 2.2 `wt step`
- [x] `step commit` — stage + commit with message generation
  - [x] LLM commit if `[commit.generation] command` configured
  - [x] Branch-derived conventional commit fallback
  - [x] Pre/post-commit hooks
  - [x] -m/--message and -a/--all flags
- [x] `step diff` — show staged+unstaged diff
- [ ] `step squash` — Squash commits since branch
- [ ] `step rebase` — Rebase onto target
- [ ] `step push` — Fast-forward target to current
- [ ] `step copy-ignored` — Copy gitignored files between worktrees
- [ ] `step eval` — Evaluate template expression
- [ ] `step for-each` — Run command in every worktree
- [ ] `step promote` — Swap branch into main worktree
- [ ] `step prune` — Remove merged worktrees/branches
- [ ] `step relocate` — Move worktrees to expected paths
- [ ] `step tether` — Run command, kill on remove

### 2.3 `wt hook`
- [ ] Dedicated `hook` command (show/run)
- [ ] Hook execution pipeline (single, concurrent, sequential)
- [ ] Hook filtering (user:/project: prefix)
- [ ] `hook run-pipeline` internal stdin protocol

### 2.4 `wt config`
- [x] `config show` — display current config
- [x] `config create` — scaffold config file
- [ ] `config shell {init,install,uninstall}` — shell integration install
- [ ] `config show --full` — resolved config with defaults
- [ ] `config update` — deprecation migration
- [ ] `config approvals` — command approval management
- [ ] `config alias` — inspect aliases
- [ ] `config plugins` — agent plugin installation
- [ ] `config state *` — state subcommands (vars, markers, hints, etc.)

---

## Phase 3: Shell & Integration (not started)

### 3.1 Shell Integration
- [ ] Shell detection (`current_shell()`)
- [ ] Shell config path discovery
- [ ] `cd` and `--execute` directive file protocol
- [ ] Completion passthrough
- [ ] `config shell install` — Edit rc files
- [ ] `config shell uninstall` — Remove integration lines

### 3.2 LLM Integration
- [x] Commit message generation (prompt building via pipe to LLM)
- [ ] Squash message generation
- [ ] Branch summary generation
- [ ] Template-append (user + project guidance fragments)

### 3.3 Completions
- [ ] Dynamic shell completions (bash, zsh, fish)

### 3.4 Interactive Picker (TUI)
- [ ] Fuzzy-finder integration

---

## Phase 4: Polish & Extras (not started)

---

## Divergences

### D1: Template Engine — ECR instead of minijinja + askama
- Shell wrappers use `Template.expand` (runtime) instead of askama (compile-time)
- Config templates use `Template.expand` with regex-based `{{ var | filter }}` parsing
- All 9 custom filters ported and verified (codename: SHA-256 parity)
- No jinja2 built-in filters yet (upper, lower, default, length, trim)

### D2: CLI Framework — OptionParser instead of clap
- Crystal stdlib `OptionParser` with manual command dispatch
- clap's derive macros and subcommand nesting not needed for CLI tool

### D3: Concurrency Model  
- Deferred. Crystal fibers/channels available when needed for parallel operations.

### D4: TUI Picker
- Deferred. Will shell out to `fzf` or `skim` binary when implemented.

---

## Implementation Notes

- **2026-05-18**: Project initialized. Parity manifests: 3703 items total.
- **2026-05-18**: Codename filter: SHA-256 parity verified across languages.
- **2026-05-18**: Crystal enum limitation → class hierarchy for GitError (35 variants).
- **2026-05-18**: Struct → Class for WorktreeInfo: structs are value types, needed reference semantics for in-place parsing.
- **2026-05-18**: Crystal `do` block in `OptionParser.parse` closures prevent variable narrowing; used `if/else` to extract non-nil Strings.
- **2026-05-18**: Crystal regex captures typed as `Char|String` for `\w` patterns; used `"#{match[n]}"` interpolation to force `String`.
- **2026-05-18**: `OptionParser.unknown_args` puts branch names in `before` (not `after`) — Crystal API quirk.
- **2026-05-18**: All 10 hook types implemented: pre/post-start, pre/post-switch, pre/post-commit, pre/post-merge, pre/post-remove.
- **2026-05-18**: 16 commits, 126 specs, all gates green.
