# Copy-ignored support: discovery, filtering, and copying of gitignored files.
# Ported from vendor/worktrunk/src/commands/step/shared.rs +
# vendor/worktrunk/src/commands/step/copy_ignored.rs (core behavioral logic)
#
# Divergences (documented):
# - COW/reflink copying: uses plain recursive copy instead of macOS clonefile.
# - Parallelism / thread pool: single-threaded.
# - TTY progress spinner: omitted.
# - I/O priority lowering: omitted.
# - Gitignore pattern matching: simplified relative-path matcher (no full
#   `ignore`-crate semantics; covers anchored, directory-only, glob, and
#   negation patterns).
# - Per-project user-config `[step.copy-ignored]` overrides not yet merged.

require "./cmd"
require "file_utils"

module WorkTrees
  module CopyIgnored
    # Built-in excludes for `wt step copy-ignored`: VCS metadata + tool-state
    # directories. Mirrors upstream BUILTIN_COPY_IGNORED_EXCLUDES.
    BUILTIN_EXCLUDES = [
      ".bzr/", ".conductor/", ".entire/", ".hg/", ".jj/",
      ".pijul/", ".sl/", ".svn/", ".worktrees/",
    ]

    # Parse `git ls-files --ignored --exclude-standard -o --directory` output.
    # Directories are distinguished by trailing slash; stripped in the result.
    def self.parse_ls_files(output : String) : Array({String, Bool})
      output.each_line.compact_map do |line|
        next if line.empty?
        is_dir = line.ends_with?('/')
        path = is_dir ? line.rchop('/') : line
        next if path.empty?
        {path, is_dir}
      end.to_a
    end

    # Run `git ls-files` to discover all gitignored entries in a worktree.
    # Returns `{relative_path, is_dir}` entries.
    def self.list_ignored_entries(worktree_path : String) : Array({String, Bool})
      result = Cmd.new("git")
        .args(["ls-files", "--ignored", "--exclude-standard", "-o", "--directory"])
        .current_dir(worktree_path)
        .run
      unless result.success?
        raise "git ls-files failed in #{worktree_path}: #{result.stderr.try(&.strip)}"
      end
      parse_ls_files(result.stdout)
    end

    # Simplified gitignore-style matcher.
    #
    # Supports:
    # - directory-only patterns (trailing `/`) — only match is_dir entries.
    # - anchored patterns (leading `/` or internal `/`) — match the full (possibly
    #   multi-segment) relative path.
    # - unanchored patterns — match the basename or any single-segment component.
    # - `*`, `?`, `[..]` globs via `File.match?`.
    # - negation patterns (leading `!`) — return false (not supported; documented).
    def self.pattern_matches?(relative : String, is_dir : Bool, pattern : String) : Bool
      return false if pattern.empty?
      return false if pattern.starts_with?('!') # negation: skip

      pattern = pattern.dup

      # Directory-only check
      dir_only = pattern.ends_with?('/')
      pattern = pattern.rchop('/') if dir_only
      return false if dir_only && !is_dir

      # Anchored: leading `/` or internal `/`
      anchored = pattern.starts_with?('/') || pattern.includes?('/')
      pattern = pattern.lstrip('/')

      return false if pattern.empty?

      if anchored
        return true if relative == pattern
        return true if relative.starts_with?("#{pattern}/")
        File.match?(pattern, relative)
      else
        # Match any path segment including the whole relative.
        relative.split('/').any? { |seg| File.match?(pattern, seg) } ||
          File.match?(pattern, relative)
      end
    end

    # Filter discovered gitignored entries through the full pipeline:
    # .worktreeinclude → exclude patterns → built-in dirs → nested worktrees.
    #
    # Parameters:
    # - `entries`  : output of `list_ignored_entries` (relative_path, is_dir).
    # - `worktree_path` : absolute root of the source worktree.
    # - `worktree_paths` : absolute roots of _all_ current worktrees.
    # - `exclude_patterns` : configured `[step.copy-ignored].exclude` patterns.
    # - `include_patterns` : patterns read from `.worktreeinclude` (empty → keep all).
    def self.filter_entries(
      entries : Array({String, Bool}),
      worktree_path : String,
      worktree_paths : Array(String),
      exclude_patterns : Array(String),
      include_patterns : Array(String),
    ) : Array({String, Bool})
      entries.select do |(relative, is_dir)|
        # .worktreeinclude filter
        unless include_patterns.empty?
          next false unless include_patterns.any? { |pattern| pattern_matches?(relative, is_dir, pattern) }
        end

        # Configured excludes
        next false if exclude_patterns.any? { |pattern| pattern_matches?(relative, is_dir, pattern) }

        # Built-in VCS / tool-state directory exclusions (basename match)
        if is_dir
          base = File.basename(relative)
          if BUILTIN_EXCLUDES.any? { |pat| pat.rchop('/') == base }
            next false
          end
        end

        # Nested worktree guard: an entry whose resolved abs path is an
        # ancestor of another worktree is excluded.
        abs = File.expand_path(File.join(worktree_path, relative))
        if worktree_paths.any? { |worktree| worktree != worktree_path && worktree.starts_with?(abs) }
          next false
        end

        true
      end
    end

    # Resolve the full copy-ignored config: built-in defaults merged with
    # optional user and project `[step.copy-ignored]` sections.
    #
    # Order: built-in → project → user (upstream resolve_copy_ignored_config).
    def self.resolve(
      user_step : Config::StepConfig?,
      project_step : Config::StepConfig?,
    ) : Config::CopyIgnoredConfig
      config = Config::CopyIgnoredConfig.new(exclude: BUILTIN_EXCLUDES.dup)
      if ps = project_step
        config = config.merged_with(ps.copy_ignored)
      end
      if us = user_step
        config = config.merged_with(us.copy_ignored)
      end
      config
    end

    # Copy a file, directory, or symlink from `src` to `dest`.
    #
    # Returns the number of leaf entries actually written (files + symlinks).
    # Skips existing destinations unless `force` is true.
    # Preserves symlinks (creates a new symlink pointing to the same target).
    # Directories are copied recursively, preserving all children.
    # Skips sockets, FIFOs, and other non-regular files.
    def self.copy_path(src : String, dest : String, *, force : Bool) : Int32
      if File.symlink?(src)
        return 0 unless should_replace?(dest, force)
        File.delete(dest) if File.exists?(dest) || File.symlink?(dest)
        Dir.mkdir_p(File.dirname(dest))
        File.symlink(File.readlink(src), dest)
        1
      elsif Dir.exists?(src)
        Dir.mkdir_p(dest) unless Dir.exists?(dest)
        count = 0
        Dir.each_child(src) do |child|
          count += copy_path(File.join(src, child), File.join(dest, child), force: force)
        end
        count
      elsif File.exists?(src)
        return 0 unless should_replace?(dest, force)
        Dir.mkdir_p(File.dirname(dest))
        File.copy(src, dest)
        1
      else
        0
      end
    end

    private def self.should_replace?(dest : String, force : Bool) : Bool
      force || (!File.exists?(dest) && !File.symlink?(dest))
    end

    # Copy a file, directory, or symlink from `src` to `dest`, then delete src.
    # Uses `File.rename`; falls back to copy+delete on cross-device moves.
    # Mirrors vendor/worktrunk/src/commands/step/promote.rs `move_entry`.
    def self.move_entry(src : String, dest : String, *, is_dir : Bool)
      Dir.mkdir_p(File.dirname(dest)) unless File.directory?(dest)
      begin
        File.rename(src, dest)
      rescue File::Error
        if is_dir
          copy_path(src, dest, force: true)
          FileUtils.rm_rf(src)
        else
          copy_path(src, dest, force: true)
          File.delete(src)
        end
      end
    end

    # Move gitignored entries from `path_a` and `path_b` into staging
    # subdirectories `staging_dir/a/` and `staging_dir/b/` to protect them
    # from `git checkout` during a branch exchange.
    #
    # Mirrors vendor/worktrunk/src/commands/step/promote.rs `stage_ignored`.
    def self.stage_ignored(
      path_a : String, entries_a : Array({String, Bool}),
      path_b : String, entries_b : Array({String, Bool}),
      staging_dir : String,
    )
      Dir.mkdir_p(staging_dir)
      staging_a = File.join(staging_dir, "a")
      staging_b = File.join(staging_dir, "b")

      entries_a.each do |(relative, is_dir)|
        src = File.join(path_a, relative)
        dst = File.join(staging_a, relative)
        move_entry(src, dst, is_dir: is_dir) if File.exists?(src) || File.symlink?(src)
      end

      entries_b.each do |(relative, is_dir)|
        src = File.join(path_b, relative)
        dst = File.join(staging_b, relative)
        move_entry(src, dst, is_dir: is_dir) if File.exists?(src) || File.symlink?(src)
      end
    end

    # Distribute staged entries back to worktrees after a branch exchange.
    # B's original entries (in staging/b/) go to A's worktree (now on B's branch),
    # and A's original entries (in staging/a/) go to B's worktree (now on A's branch).
    # Removes the staging directory on completion (best-effort).
    #
    # Mirrors vendor/worktrunk/src/commands/step/promote.rs `distribute_staged`.
    def self.distribute_staged(
      staging_dir : String,
      path_a : String, entries_a : Array({String, Bool}),
      path_b : String, entries_b : Array({String, Bool}),
    )
      staging_a = File.join(staging_dir, "a")
      staging_b = File.join(staging_dir, "b")

      entries_b.each do |(relative, is_dir)|
        src = File.join(staging_b, relative)
        dst = File.join(path_a, relative)
        move_entry(src, dst, is_dir: is_dir) if File.exists?(src) || File.symlink?(src)
      end

      entries_a.each do |(relative, is_dir)|
        src = File.join(staging_a, relative)
        dst = File.join(path_b, relative)
        move_entry(src, dst, is_dir: is_dir) if File.exists?(src) || File.symlink?(src)
      end

      FileUtils.rm_rf(staging_dir)
    end
  end
end
