# Testing

## Running Tests

```bash
make test
```

## Test Policy

- Upstream Rust tests are ported as Crystal specs in `spec/`.
- Fixtures and golden outputs must be preserved exactly.
- If upstream has no tests, create characterization specs from observable
  behavior and mark inferred behavior explicitly.
- Do not weaken assertions, skip branches, or rewrite expectations to fit
  the current implementation.
