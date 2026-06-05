# Architecture

wktrees is a Crystal port of [worktrunk](https://github.com/max-sixty/worktrunk) (Rust v0.51.0).

## Directory Layout

```
src/
├── cli.cr                  # Binary entry point
├── work_trees.cr           # Module root + requires
└── work_trees/
    ├── cli.cr              # CLI dispatch + all commands (~2750 LOC)
    ├── cmd.cr              # External command execution (Cmd builder)
    ├── cache.cr            # JSON cache primitives (read/write/LRU)
    ├── sync.cr             # Semaphore via Channel
    ├── styling.cr          # Terminal output (lipgloss-powered)
    ├── output.cr           # Verbosity + stdout/stderr routing
    ├── trace.cr            # [wt-trace] command tracing
    ├── command_log.cr       # JSONL audit logging
    ├── display_util.cr      # Relative time + visual-width truncation
    ├── path_util.cr         # sanitize + expand + display
    ├── invocation.cr        # Binary name detection
    ├── template_vars.cr     # Hook variable builder
    ├── picker.cr            # Bubbletea TUI picker
    ├── ci_status.cr         # Multi-platform CI status
    ├── config/
    │   ├── config.cr        # UserConfig + ProjectConfig + merge
    │   ├── hook.cr          # Hook parsing + HookSource/ParsedFilter
    │   ├── sections.cr      # Config section structs (5 types)
    │   ├── approvals.cr     # TOML-based command approval
    │   └── deprecation.cr   # Detection + migration
    ├── git/
    │   ├── error.cr         # 35 GitError types
    │   ├── repository.cr    # Repository + WorkingTree
    │   ├── worktree_info.cr # Worktree porcelain parsing
    │   ├── remove.cr        # Branch deletion + trash staging
    │   ├── branch_resolver.cr # Shortcut resolution (^ @ - pr:N mr:N)
    │   ├── integration.cr   # Branch integration detection (4 levels)
    │   ├── diff.cr          # LineDiff + DiffStats
    │   ├── url.cr           # GitRemoteUrl parsing + forge detection
    │   ├── branches.cr      # LocalBranch, RemoteBranch inventory
    │   ├── ref_snapshot.cr  # Immutable ref state capture
    │   ├── sha_cache.cr     # SHA-keyed JSON cache (6 kinds)
    │   ├── pr_resolver.cr   # PR/MR fetch + checkout
    │   └── recovery.cr      # Cleanup result tracking
    ├── list/
    │   ├── model.cr         # State enums (Divergence, MainState, etc.)
    │   ├── columns.cr       # ColumnKind registry
    │   ├── item.cr          # ListItem, DisplayFields, ListData (JSON::Serializable)
    │   ├── json_output.cr   # Structured JSON output types
    │   └── render.cr        # Compact numbers + skeleton rows
    ├── shell/
    │   └── wrapper.cr       # Shell wrapper templates (5 shells)
    └── template/
        ├── filters.cr       # 9 template filters
        ├── codename.cr      # SHA-256 codename generation
        ├── context.cr       # Template variable context
        └── expansion.cr     # Runtime `{{ var | filter }}` expansion
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Monolithic CLI module | OptionParser consolidation is simpler than clap's derive pattern |
| lipgloss for styling | Crystal port of Charmbracelet lipgloss, truecolor support |
| bubbles for TUI | Bubbles::List + Bubbles::Viewport instead of external fzf binary |
| JSON::Serializable | Crystal's built-in serialization for type-safe JSON output |
| Trace::Span blocks | Block-based auto-timing instead of RAII structs (Crystal limitation) |
| PATH + project-local plugins | Tier 2 plugin system: `.work_trees/bin/` then `$PATH` |

## Divergences from Upstream

| ID | Area | Decision |
|----|------|----------|
| D1 | Template Engine | `Template.expand` (regex-based) instead of minijinja + askama |
| D2 | CLI Framework | Crystal `OptionParser` instead of clap |
| D3 | Concurrency | Crystal fibers + WaitGroup instead of rayon thread pool |
| D4 | TUI Picker | Integrated bubbletea TUI instead of fzf/skim binary |
| D5 | CLI Name | `wktrees` binary, `WorkTrees` module namespace |
| D6 | Preview Protocol | Tea messages via fibers instead of temp-file state and skim heartbeat |
| D7 | Items/List | `Bubbles::List::DefaultItem` instead of `SkimItem` trait |
| D8 | Preview Cache | SHA-256-keyed JSON files instead of Rust DashMap/disk cache |

## Implementation Notes

- **2026-06-05**: Binary renamed to `wktrees` (D5). Interactive picker uses bubbletea TUI with Bubbles::List + Viewport (D4). PreviewCache uses SHA-256 for content-addressed disk cache (D8). 837 specs, 0 failures.
