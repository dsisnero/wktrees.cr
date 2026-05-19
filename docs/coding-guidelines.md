# Coding Guidelines

- Upstream behavior is the source of truth. Preserve semantics exactly.
- Use explicit numeric widths (`_u8`, `_i32`, etc.) where behavior depends on
  signedness/range.
- Use `Bytes` (`Slice(UInt8)`) for binary semantics; avoid `String` for raw
  byte payloads.
- Preserve boundary semantics exactly (e.g., half-open ranges).
- Follow Crystal conventions: `crystal tool format` for formatting, `ameba`
  for linting.
