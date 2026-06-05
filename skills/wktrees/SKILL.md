---
name: wktrees
description: Guidance for wktrees (the `wktrees` CLI) — git worktree management, hooks, and config. Load when editing .config/wt.toml or ~/.config/worktrees/config.toml; adding, modifying, or debugging hooks; configuring commit message generation or command aliases; or troubleshooting wktrees behavior.
license: MIT
compatibility: Requires the `wktrees` CLI (Crystal port of worktrunk)
---

# wktrees

Help users work with wktrees, a CLI tool for managing git worktrees.
Crystal port of [worktrunk](https://github.com/max-sixty/worktrunk) (Rust, v0.51.0).

## Available Documentation

Reference files are maintained in this repository:

- **plans/parity.md**: Port status and feature parity tracking
- **plans/interactive_picker.md**: Bubbletea TUI interactive picker architecture
- **plans/plugins.md**: Plugin system architecture (two-tier: config hooks + custom subcommands)
- **plans/cli_research.md**: clip vs clim CLI framework comparison (conclusion: keep OptionParser)
- **docs/architecture.md**: Source tree layout, design decisions, divergences
- **docs/development.md**: Development workflow, coding guidelines

## Two Types of Configuration

wktrees uses two separate config files with different scopes and behaviors:

### User Config (`~/.config/worktrees/config.toml`)
- **Scope**: Personal preferences for the individual developer
- **Location**: `~/.config/worktrees/config.toml` (never checked into git)
- **Contains**: LLM integration, worktree path templates, command settings, user hooks, approved commands
- **Permission model**: Always propose changes and get consent before editing

### Project Config (`.config/wt.toml`)
- **Scope**: Team-wide automation shared by all developers
- **Location**: `<repo>/.config/wt.toml` (checked into git)
- **Contains**: Hooks for worktree lifecycle (pre-start, pre-merge, etc.)
- **Permission model**: Proactive (create directly, changes are reversible via git)

## Determining Which Config to Use

When a user asks for configuration help, determine which type based on:

**User config indicators**:
- "set up LLM" or "configure commit generation"
- "change where worktrees are created"
- "customize commit message templates"
- Affects only their environment

**Project config indicators**:
- "set up hooks for this project"
- "automate npm install"
- "run tests before merge"
- Affects the entire team

**Both configs may be needed**: For example, setting up commit message generation requires user config, but automating quality checks requires project config.

## Core Workflows

### Setting Up Commit Message Generation (User Config)

1. **Detect available tools**
   ```bash
   which claude codex llm aichat 2>/dev/null
   ```

2. **If none installed, recommend Claude Code** (already available in Claude Code sessions)

3. **Propose config change**
   ```toml
   [commit.generation]
   command = "llm -m haiku"  # or claude, codex, etc.
   ```
   Ask: "Should I add this to your config?"

4. **After approval, apply**
   - Check if config exists: `wktrees config show`
   - If not, guide through `wktrees config create`
   - Read, modify, write preserving structure

5. **Suggest testing**
   ```bash
   wktrees step commit --show-prompt  # verify prompt builds
   ```

### Setting Up Project Hooks (Project Config)

Common request for workflow automation. Follow discovery process:

1. **Detect project type**
   ```bash
   ls package.json Cargo.toml pyproject.toml
   ```

2. **Identify available commands**
   - For npm: Read `package.json` scripts
   - For Rust: Common cargo commands
   - For Python: Check pyproject.toml

3. **Design appropriate hooks** (10 hook types available)
   - Dependencies (fast, must complete) → `pre-start`
   - Tests/linting (must pass) → `pre-commit` or `pre-merge`
   - Long builds, dev servers → `post-start`
   - Terminal/IDE updates → `post-switch`
   - Deployment → `post-merge`
   - Cleanup tasks → `pre-remove`

4. **Validate commands work**
   ```bash
   npm run lint  # verify exists
   which cargo   # verify tool exists
   ```

5. **Create `.config/wt.toml`**
   ```toml
   # Install dependencies when creating worktrees
   pre-start = "npm install"

   # Validate code quality before committing
   [pre-commit]
   lint = "npm run lint"
   typecheck = "npm run typecheck"

   # Run tests before merging
   pre-merge = "npm test"
   ```

6. **Add comments explaining choices**

7. **Suggest testing**
   ```bash
   wktrees switch --create test-hooks
   ```

### Adding Hooks to Existing Config

When users want to add automation to an existing project:

1. **Read existing config**: `cat .config/wt.toml`

2. **Determine hook type** - When should this run?
   - Creating worktree (blocking) → `pre-start`
   - Creating worktree (background) → `post-start`
   - Every switch → `post-switch`
   - Before committing → `pre-commit`
   - Before merging → `pre-merge`
   - After merging → `post-merge`
   - Before removal → `pre-remove`

3. **Handle format conversion if needed**

   Single command to named table:
   ```toml
   # Before
   pre-start = "npm install"

   # After (adding migrate)
   [pre-start]
   install = "npm install"
   migrate = "npm run db:migrate"
   ```

4. **Preserve existing structure and comments**

### Validation Before Adding Commands

Before adding hooks, validate:

```bash
# Verify command exists
which npm
which cargo

# For npm, verify script exists
npm run lint --dry-run

# For shell commands, check syntax
bash -n -c "if [ true ]; then echo ok; fi"
```

**Dangerous patterns** — Warn users before creating hooks with:
- Destructive commands: `rm -rf`, `DROP TABLE`
- External dependencies: `curl http://...`
- Privilege escalation: `sudo`

## Permission Models

### User Config: Conservative
- **Never edit without consent** - Always show proposed change and wait for approval
- **Never install tools** - Provide commands for users to run themselves
- **Preserve structure** - Keep existing comments and organization
- **Validate first** - Ensure TOML is valid before writing

### Project Config: Proactive
- **Create directly** - Changes are versioned, easily reversible
- **Validate commands** - Check commands exist before adding
- **Explain choices** - Add comments documenting why hooks exist
- **Warn on danger** - Flag destructive operations before adding

## Key Commands

```bash
# View all configuration
wktrees config show
wktrees config create
wktrees --help
wktrees list --full
wktrees switch <branch>
wktrees switch --create <branch>
wktrees merge
wktrees hook run <type>
wktrees step commit
wktrees step diff
wktrees step for-each '<command>'
```

## Hook Approvals in Non-Interactive Sessions

Project hooks and project aliases prompt for approval on first run, so an untrusted `.config/wt.toml` can't silently execute arbitrary commands. Agents running `wktrees merge`, `wktrees switch`, or other commands that trigger hooks will hit an error like:

```
▲ cargo-difftest needs approval to execute 1 command:
○ post-merge install:
  cargo install --path .
✗ Cannot prompt for approval in non-interactive environment
↳ To skip prompts in CI/CD, add --yes; to pre-approve commands, run wktrees config approvals add
```

Two resolutions exist — pick based on who the agent is running for:

- **`wktrees config approvals add`** — interactive prompt that stores approvals to `~/.config/worktrees/approvals.toml`. Run once per project; persists across invocations until the command template changes or the project moves. This is the right choice when the human owns the trust decision.
- **`--yes`** / `-y` — bypasses approval for a single invocation. Appropriate for CI/CD where hook contents are controlled by the pipeline itself.

**When invoked as an agent, stop and escalate to the user** — pre-approval is a security decision about whether this project's hooks should be trusted to run arbitrary commands on their machine. Tell the user to run `wktrees config approvals add` (or review and re-run with `--yes` if they accept the CI-style one-shot bypass). Don't reach for `--yes` on the user's behalf just to unblock the command.

## Advanced: Agent Handoffs

When the user requests spawning a worktree with an agent in a background session ("spawn a worktree for...", "hand off to another agent"), use the appropriate pattern for their terminal multiplexer. Substitute `<agent-cli>` with the CLI you are running as: `claude` for Claude Code, `'opencode run'` for OpenCode.

**tmux** (check `$TMUX` env var):
```bash
tmux new-session -d -s <branch-name> "wktrees switch --create <branch-name> -x <agent-cli> -- '<task description>'"
```

**Zellij** (check `$ZELLIJ` env var):
```bash
zellij run -- wktrees switch --create <branch-name> -x <agent-cli> -- '<task description>'
```

**Requirements** (all must be true):
- User explicitly requests spawning/handoff
- User is in a supported multiplexer (tmux or Zellij)
- The user's project instructions (`CLAUDE.md` or `AGENTS.md`) or an explicit prompt authorize this pattern

**Do not use this pattern** for normal worktree operations.

Example (tmux, Claude Code):
```bash
tmux new-session -d -s fix-auth-bug "wktrees switch --create fix-auth-bug -x claude -- \
  'The login session expires after 5 minutes. Find the session timeout config and extend it to 24 hours.'"
```

### Parallel sub-Agents (single Claude Code session)

To spawn multiple sub-Agents that each work in their own worktree from one Claude Code session — no terminal multiplexer, no human in the other pane — pre-create each worktree from the parent and pass the path into the sub-Agent prompt:

```bash
wktrees switch --create <branch> --no-cd --no-hooks
```

Then call the `Agent` tool **without** `isolation: "worktree"`, naming the path in the prompt:

```
You are working in /abs/path/to/worktrunk.<branch> on branch `<branch>`.
All edits must stay in that worktree.
```

`--no-cd` skips the shell-integration cd script the parent can't consume; `--no-hooks` is appropriate when each sub-Agent will run its own build/test step and you don't need post-start setup repeated per worktree.

**Do not** use `Agent { isolation: "worktree" }` for this. Pre-creating with `wktrees switch --create` keeps path, branch, and hook target aligned.
