# AGENTS.md

## Source of Truth

This repository is a Crystal port of [Worktrunk](https://github.com/max-sixty/worktrunk), a Rust
CLI for Git worktree management.

- **Upstream URL:** https://github.com/max-sixty/worktrunk
- **Pinned upstream ref:** `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (submodule at `vendor/worktrunk`)
- **Upstream version:** v0.51.0

Upstream behavior is the source of truth. Port behavior first, then express it
with Crystal idioms. Do not change semantics to be "more idiomatic."

## Parity Tracking

Parity inventory is tracked in `plans/inventory/`. See
`plans/inventory/rust_port_inventory.tsv` for the current port status.

## Contributor Workflow

1. Lock source-of-truth: pin upstream via submodule.
2. Build/refresh parity checklist: use `porting-to-crystal` and
   `cross-language-crystal-parity` skills.
3. Translate behavior: preserve parameter order, edge cases, and error outcomes.
4. Port tests as first-class work: upstream tests → Crystal specs.
5. Verify continuously:
   ```
   make format
   make lint
   make test
   ```

## Quality Gates

All changes must pass:
- `crystal tool format --check src spec`
- `ameba src spec`
- `crystal spec`
- Cross-language parity checks (see `cross-language-crystal-parity` skill)

## Language Mapping (Rust → Crystal)

| Rust | Crystal |
|---|---|
| `mod foo` | `module Foo` |
| `const X: u8 = 1;` | `X = 1_u8` |
| `enum` | `enum` or tagged `struct`/union pattern |
| `Result<T, E>` | exception, union, or explicit result type |
| `Option<T>` | `T?` |
| `#[test]` | `it` blocks in Crystal specs |
