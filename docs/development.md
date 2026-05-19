# Development

## Setup

```bash
make install
```

## Quality Gates

```bash
make format
make lint
make test
```

## Project Structure

- `src/` — Crystal source code
- `spec/` — Crystal specs (tests)
- `vendor/worktrunk/` — Upstream Rust project (git submodule)
- `plans/inventory/` — Parity tracking manifests
