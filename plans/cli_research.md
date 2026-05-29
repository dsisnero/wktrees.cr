# CLI Framework Research: clip vs clim

## Summary

This document compares two Crystal CLI frameworks for potential migration of
`wktrees` away from raw `OptionParser` (currently ~2750 LOC in `cli.cr`).

**Recommendation: Do not migrate.** Neither framework provides enough value
over the current OptionParser implementation to justify the migration effort.

## Candidates

| | clip (erdnaxeli/clip) | clim (at-grandpa/clim) |
|---|---|---|
| **Stars** | 19 | 125 |
| **Used by** | 4 | 51 |
| **Deps** | 1 (stdlib-only) | 0 (stdlib-only) |
| **Last activity** | ~5 years ago | ~5 years ago |
| **Paradigm** | Declarative (struct + annotations) | DSL (class + blocks) |
| **Subcommands** | `Clip.add_commands` + abstract structs | `sub "name" do ... end` block DSL |
| **Help gen** | Auto from `@[Clip::Doc]` | Auto, customizable via `help_template` |
| **Error handling** | Raises `Clip::Error`; user handles | Built-in; `--help` auto-printed |
| **Bash completion** | No | Yes (`--bash-completion`) |
| **IO injection** | No; user must manage IO | `start(argv, io: io)` |
| **Version flag** | Manual | `version` macro with optional short |
| **Type support** | All Crystal types via parse | Int8-64, UInt8-64, Float32/64, String, Bool, Array variants |
| **Default values** | Crystal defaults on struct | `default:` kwarg |
| **Required args** | Crystal non-nil types | `required: true` kwarg |
| **Optional args** | `T?` types | `required: false` + `default:` |
| **Arrays/rest** | `Array(T)` with rest annotation | `Array(T)` type on option |
| **Control** | "You are in control" — no side effects | Opinionated — runs block, prints help |

## Worktrees CLI Structure (current)

```
wktrees
├── list      [options]  (--ci, --json, --branch, --all)
├── switch    <target>   (--create/-c, --detach)
├── create    [options]  <name>  (--base/-b, --detach, --force)
├── remove    <treeish>  (--force)
├── add       <path>     (--force, --from)
├── config    (get/set/... sub-subcommands)
├── hook      (sub-subcommands)
├── init      [path]
├── help      [cmd]
└── plugin commands (dispatched to $PATH)
```

## clip Evaluation

### Pros
- **Declarative, type-safe**: Struct fields = CLI params. Compile-time validation.
- **Separation of concerns**: Parse → object. User decides what to do with it.
- **Minimal**: 1 dep, no side effects. Fits the "library, not framework" philosophy.

### Cons for wktrees
- **Subcommand dispatch is awkward**: Requires abstract struct hierarchy and
  `Clip.add_commands`. Each subcommand is a separate struct. This fragments
  what's currently a single cohesive `CLI` module.
- **No `--version` built in**. Must implement manually.
- **No bash completion**.
- **No IO injection**: Must manage stdout/stderr routing manually.
- **No help customization**: Auto-generated only, no programmatic control.
- **Immature**: 19 stars, 4 dependents, very small community.
- **No sub-subcommands**: `wktrees config get` / `wktrees hook install` would
  require nested abstract structs — not supported in clip's model.

### Migration Effort for wktrees
- **High**: Would require restructuring ~2750 LOC of CLI dispatch into many
  separate struct files. Sub-subcommands (config, hook) would need workarounds.
  Plugin dispatch would need custom logic anyway.
- **Estimated: 2-3 weeks** of restructuring and bug-fixing.

## clim Evaluation

### Pros
- **Intuitive DSL**: `main do ... sub "name" do ... end` is readable and
  closely mirrors the command tree.
- **Rich built-ins**: bash completion, `--version`, custom help templates, IO
  injection.
- **Mature**: 125 stars, 51 dependents, widely used in the Crystal ecosystem.
- **Good type system integration**: Supports all numeric types, arrays, booleans.
- **Subcommand naming**: `alias_name` for aliases.
- **Opinionated but flexible**: `help_template` block for full override.

### Cons for wktrees
- **Both projects unmaintained**: Last updated ~5 years ago. Any bugs found
  would need to be fixed in our own fork.
- **No sub-subcommands natively**: `wktrees config get/set` would need
  structural workarounds (though less awkward than clip's approach).
- **DSL lock-in**: clim is a framework — you build your app around it.
  Migration is all-or-nothing.
- **No dynamic subcommands**: Plugin dispatch (`wktrees <plugin>`) would
  require reimplementing the dispatch layer.
- **Help format divergence**: clim generates its own help strings. Our current
  help uses lipgloss styling with custom formatting. We'd lose styling control
  unless we use the `help_template` block — which means customizing help for
  every subcommand.

### Migration Effort for wktrees
- **Medium-High**: The DSL maps well to our command tree, but we'd need to:
  1. Rewrite ~2750 LOC of CLI dispatch as clim blocks
  2. Reimplement plugin dispatch (clim doesn't do this)
  3. Customize help for every subcommand via `help_template` to maintain
     lipgloss styling
  4. Handle sub-subcommands with structural workarounds
  5. Fork clim if we find bugs (both projects unmaintained)
- **Estimated: 1-2 weeks** of migration + indefinite maintenance burden.

## Current OptionParser Assessment

| Feature | OptionParser (current) | clip | clim |
|---|---|---|---|
| Subcommands | Manual dispatch (works perfectly) | Struct hierarchy | DSL `sub` blocks |
| Sub-subcommands | Manual dispatch | Not supported | Awkward nesting |
| Plugin dispatch | Custom logic (already built) | No | No |
| lipgloss styling | Full control | None (raw strings) | Via `help_template` |
| Help messages | Manual (already written) | Auto-generated | Auto + custom |
| Bash completion | Dynamic (already built) | No | Built-in |
| Error handling | Custom, precise | Generic | One-size |
| Maintenance | We own it | Unmaintained | Unmaintained |
| LOC in cli.cr | ~2750 | Would be ~1500+ in structs | Would be ~1200 in blocks |
| Feature parity | Full | Missing version, completion, styling | Missing dynamic plugins, sub-subs |

## Verdict

**Do not migrate.** The current OptionParser implementation:

1. **Already works** — 675 specs pass. All features implemented.
2. **Gives full control** — lipgloss styling, custom error messages, plugin dispatch.
3. **Is maintained** — we own it, no upstream dependency.
4. **Has features neither framework supports** — dynamic plugin subcommands,
   sub-subcommands (config get/set, hook install), lipgloss-styled help.

The migration payoff is negative: 1-3 weeks of work to gain auto-generated
help (which we already have, styled better) at the cost of losing plugin
dispatch, sub-subcommands, and taking a dependency on unmaintained libraries.

If a migration were forced (e.g., for ecosystem alignment), **clim** is the
clear winner due to its DSL proximity to our command tree, bash completion
support, and larger community. But even then, the net value is minimal.

## Research Worktrees

| Worktree | Path | Branch | Purpose |
|---|---|---|---|
| research-clip | `/Users/dominic/dev/research-clip` | `research-clip` | clip testbed (`src/clip_test.cr`) |
| research-clim | `/Users/dominic/dev/research-clim` | `research-clim` | clim testbed (`src/clim_test.cr`) |

Both worktrees contain the full ported codebase plus the respective shard
dependency and a minimal test CLI demonstrating subcommand handling.

## Next Steps

- Delete both research worktrees if migration is rejected
- Keep `plans/cli_research.md` as documentation of the decision
