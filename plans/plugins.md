# Plugin Architecture for wktrees (Compiled Crystal CLI)

## Problem

Crystal compiles to native binaries — no runtime `require`, no dynamic dispatch
by default. The upstream Rust worktrunk has plugin-like features (Claude/Codex
plugin manifests, custom subcommands) that need a compiled-language equivalent.

## Scenarios Evaluated

### Scenario 1: Custom Subcommand Binaries (PATH + project-local)

**How it works:** Any executable named `wktrees-<name>` found in
`.work_trees/bin/` (project-local, CWD-relative) or on `$PATH` is
automatically discovered and invoked as `wktrees <name>`. Git itself uses this
pattern (`git-lfs`, `git-flow`).

**Search order:**
1. `.work_trees/bin/wktrees-<name>` — project-local (takes precedence)
2. `$PATH/wktrees-<name>` — system/user-wide

**Crystal implementation:**
```crystal
def find_plugin(name : String) : String?
  # 1. Project-local
  local = File.join(Dir.current, ".work_trees", "bin", "wktrees-#{name}")
  return local if File.executable?(local)
  # 2. PATH
  ENV["PATH"].split(':').each do |dir|
    full = File.join(dir, "wktrees-#{name}")
    return full if File.executable?(full)
  end
  nil
end
```

**Pros:**
- Zero runtime overhead until invoked
- Any language (bash, Python, Rust, Crystal)
- Independent versioning and release cycles
- Already built into wktrees CLI (`dispatch_unknown` calls `run_alias` first)

**Cons:**
- Each plugin is a separate binary (install complexity)
- No shared in-process state
- Cross-platform PATH discovery differences

**Implementation effort:** ~50 LOC. Already partially implemented in
`cli.cr:dispatch_unknown`.

**Verdict:** ✅ **RECOMMENDED — primary plugin mechanism.** Follows git's
proven pattern, matches upstream worktrunk custom subcommand support.

---

### Scenario 2: Shell Script Hooks (stdin/stdout protocol)

**How it works:** Pipeline specs are serialized to JSON and piped to a
subprocess via stdin. The upstream uses this for `wt hook run-pipeline`.
Scripts read JSON context, do work, write JSON back.

**Crystal implementation:**
```crystal
# Serialize pipeline spec, pipe to bash/sh subprocess
def run_pipeline(spec : PipelineSpec)
  json = spec.to_json
  Process.run("sh", ["-c", spec.handler], input: IO::Memory.new(json))
end
```

**Pros:**
- Works with any scripting language
- Low coupling — just JSON in/out
- Already the pattern for hooks and LLM commands

**Cons:**
- Serialization overhead per invocation
- Error handling across process boundary
- No shared state or caching

**Implementation effort:** ~100 LOC. Partially implemented via hook execution.

**Verdict:** ✅ **RECOMMENDED — for hook and pipeline plugins.** Use where
subprocess isolation is desired (security boundary for project config hooks).

---

### Scenario 3: Shared Library Plugins (dlopen/dlsym)

**How it works:** Crystal `.so`/`.dylib` files loaded at runtime via
`LibC.dlopen`. Requires a stable plugin ABI (C-compatible function signatures).

**Crystal implementation:**
```crystal
# plugin API (C ABI)
@[Link(ldflags: "")]
lib PluginAPI
  fun init(context : Void*) : Int32
  fun execute(args : UInt8**) : Int32
  fun destroy : Void
end
```

**Pros:**
- In-process execution (zero IPC overhead)
- Shared memory for caching
- Can share Crystal types with careful ABI management

**Cons:**
- **Crystal has no stable ABI** — plugin must be compiled with exact same
  Crystal version, LLVM version, and compile flags as host binary
- Crash in plugin = crash in host
- Platform-specific (`.so` vs `.dylib` vs `.dll`)
- Memory management across library boundary is error-prone
- Each plugin update requires recompile with matching toolchain

**Implementation effort:** ~300 LOC + ABI stability maintenance burden.

**Verdict:** ❌ **NOT RECOMMENDED.** Crystal's lack of stable ABI makes this
fragile. Suitable only for tightly controlled environments (same build pipeline).

---

### Scenario 4: WebAssembly Plugins (WASM runtime)

**How it works:** Plugins compiled to `.wasm`, loaded and executed by an
embedded WASM runtime (e.g., `wasmtime-crystal`, `wasmer`).

**Crystal implementation:**
```crystal
require "wasmtime"  # hypothetical shard

engine = Wasmtime::Engine.new
module = Wasmtime::Module.from_file(engine, "plugin.wasm")
instance = Wasmtime::Instance.new(module)
result = instance.call("execute", args)
```

**Pros:**
- Sandboxed execution (safe even for untrusted plugins)
- Language-agnostic (any language → WASM)
- Stable ABI (WASI standard)

**Cons:**
- WASM runtime dependency (~2-5MB binary size increase)
- Limited system access (no filesystem, network unless granted via WASI)
- Crystal → WASM compilation is immature (no official target)
- Performance overhead (interpreted/JIT vs native)

**Implementation effort:** ~500 LOC + external runtime dependency.

**Verdict:** ⬜ **FUTURE.** Viable long-term but Crystal WASM toolchain isn't
mature enough. Revisit when `crystal build --target wasm32-wasi` is stable.

---

### Scenario 5: Configuration-Based Extensibility (No Code Plugins)

**How it works:** Users extend behavior through configuration, not code:
- **[aliases]**: Custom `wktrees <name>` shortcuts mapping to built-in commands
- **[hooks]**: Shell commands at lifecycle events (pre/post-start, merge, etc.)
- **[commit.generation]**: External LLM command for commit messages
- **Template variables**: `{{ var | filter }}` expansion in all commands

**Crystal implementation:** Already fully implemented.

**Pros:**
- Zero security risk (no arbitrary code execution by default)
- Already built and tested (Phase 0-4 complete)
- Approval system gates project-defined commands
- Covers ~90% of real-world extensibility needs

**Cons:**
- Can't add new git operations
- Can't modify internal logic
- Limited to what's built into the binary

**Implementation effort:** ✅ Already complete.

**Verdict:** ✅ **PRIMARY — covers most use cases.** Combined with Scenario 1
(custom subcommands) for the remaining 10%.

---

## Recommendation

### Two-Tier Plugin Architecture

| Tier | Mechanism | Use Case | Status |
|------|-----------|----------|--------|
| **Tier 1** | Config-based extensibility | Hooks, aliases, templates, LLM | ✅ Done |
| **Tier 2** | Custom subcommand binaries (`wktrees-*`) | New operations, tool integration | ⬜ ~50 LOC |

**Tier 1** covers 90% of needs: hooks at lifecycle events, custom command
aliases, per-worktree state variables, LLM commit message generation.

**Tier 2** covers the remaining 10%: users who need custom git operations or
tool-specific workflows drop a `wktrees-myplugin` binary on their PATH and
get `wktrees myplugin` for free. Same pattern as `git-lfs`, `git-flow`.

### What NOT to build

- ❌ Shared library plugins (fragile, unstable ABI)
- ❌ WASM plugins (immature Crystal WASM toolchain)
- ❌ Lua/Python embedding (adds runtime dependency for niche use case)

### Implementation plan for Tier 2

1. Add `CompletionCmd` to `src/work_trees/completion.cr`:
   - `discover_custom_subcommands`: scan PATH for `wktrees-*` executables
   - Cache results per process
2. Update `dispatch_unknown` in `cli.cr`:
   - After alias resolution fails, try custom subcommand
   - If found: `exec` the binary with remaining args
   - If not found: show error with suggestions
3. Add completions:
   - Bash/zsh/fish: dynamically list discovered `wktrees-*` subcommands
4. Specs:
   - Mock PATH to verify discovery
   - Test custom subcommand invocation with test binary
   - Test fallback when no matching binary found

## Upstream parity

The vendor's "config plugins" feature (Claude/Codex plugin manifests,
`wt config plugins <tool> install`) is tool-specific and not portable as
a general plugin system. It installs plugin files to Claude/Codex config
directories — more of an installer script than a plugin framework.

For the Crystal port, the Claude plugin integration is already handled
by `plugins/wktrees/plugin.json` (the plugin manifest that Claude reads).
The `wt config plugins claude install` command from upstream would copy
this manifest to the user's Claude config directory. This can be added
as a simple file-copy operation if needed.
