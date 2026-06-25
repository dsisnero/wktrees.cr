# wktrees

A CLI for Git worktree management, designed for parallel AI agent workflows.
Crystal port of [worktrunk](https://github.com/max-sixty/worktrunk) (Rust, v0.51.0).

The binary is installed as `wktrees`.

```
wktrees switch <branch>         # switch to a worktree
wktrees switch --create <name>  # create and switch
wktrees switch                   # interactive TUI picker (bubbletea)
wktrees list                     # list worktrees with status
wktrees list --full              # full status with diffs + CI
wktrees list --format=json       # machine-readable JSON
wktrees remove <branch>          # cleanup worktrees
wktrees merge                    # commit, squash, rebase, FF merge
wktrees step commit              # conventional commit with LLM
wktrees step copy-ignored        # copy gitignored files between worktrees
wktrees step for-each 'cmd'      # run command on every worktree
wktrees config show              # view configuration
wktrees config show --full       # resolved config with defaults
wktrees config approvals add     # pre-approve project hooks
wktrees shell install            # shell integration (bash/zsh/fish/nu/ps)
wktrees -vv list                 # trace all git commands for debugging
wktrees hook show                # display configured hooks
wktrees hook run <type>          # manually trigger hooks
```

## Features

- **Interactive Picker**: Bubbletea TUI with 5 preview modes (diff, log, summary)
- **10 Hook Types**: pre/post-start, pre/post-switch, pre/post-commit, pre/post-merge, pre/post-remove
- **LLM Integration**: Commit messages via Claude/Codex/LLM, branch summaries
- **Copy-Ignored**: Share gitignored files (build caches, `.env`, `node_modules/`) between worktrees via `wktrees step copy-ignored` with `.worktreeinclude` filtering, `[step.copy-ignored]` exclude config, and built-in VCS/tool-dir exclusions
- **CI Status**: GitHub Actions, GitLab CI, Azure Pipelines, Gitea (auto-detected)
- **Config System**: User + project TOML with env var overrides and deprecation migration
- **Plugin System**: Custom subcommands via `wktrees-<name>` on PATH or `.work_trees/bin/`
- **Approvals**: Per-project command approval with persistent state
- **Shell Integration**: 5 shells, cd directive protocol, completions
- **Verbose Tracing**: `-vv` shows [wt-trace] records with microsecond timing
- **Template Engine**: 9 filters with `{{ var | filter(args) }}` syntax

## Installation

```bash
# Clone and build
git clone https://github.com/dsisnero/wktrees.git
cd wktrees
make install    # shards install
make build      # → bin/wktrees

# Optional: install to PATH
cp bin/wktrees /usr/local/bin/
```

## Shell Integration

```bash
# Install (adds wrapper function to your shell rc file)
wktrees shell install

# Restart your shell or source the rc file
source ~/.zshrc   # or ~/.bashrc
```

## Development

```bash
make install       # install dependencies (shards install)
make update        # update dependencies (shards update)
make build         # compile binary → bin/wktrees
make format        # format code
make lint          # lint code (ameba)
make test          # run specs (892 examples)
make clean         # remove build artifacts
```

Tests: 892 specs, 0 failures. Requires Crystal >= 1.20.2.

### Dependencies

- [crystal-community/toml.cr](https://github.com/crystal-community/toml.cr) — TOML config parsing
- [dsisnero/lipgloss](https://github.com/dsisnero/lipgloss) — Terminal styling (ANSI, borders, tables)
- [dsisnero/bubbles](https://github.com/dsisnero/bubbles) — TUI components (bubbletea framework)

## Contributing

1. Fork it (<https://github.com/dsisnero/wktrees/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
