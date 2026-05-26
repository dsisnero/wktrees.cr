# Shared primitives for the on-disk JSON caches under `.git/wt/cache/`.
#
# Ported from vendor/worktrunk/src/cache.rs
#
# Three callers use these primitives: sha_cache (content-addressed SHA-pair
# results), ci_status cache (branch → CI status with TTL), and summary
# (branch → LLM summary). Each owns its layout, struct shape, and freshness
# rules — this module only owns the filesystem mechanics.
#
# Torn-write semantics: writes use plain File.write, not temp-file-plus-rename.
# A crash mid-write produces a truncated file that read_json rejects as corrupt
# JSON — indistinguishable from a cache miss. Two concurrent writers for the
# same key produce the same value for content-addressed caches (benign) and
# last-writer-wins for TTL-based ones (benign).
#
# Error policy:
# - read_json returns nil on any failure (missing, I/O error, corrupt JSON)
# - write_json degrades silently — a failed write means next access re-computes
# - clear_one and clear_json_files propagate non-NotFound errors

require "json"

module WorkTrees
  module Cache
    # The root directory for a named cache kind.
    # Returns `<git-common-dir>/wt/cache/<kind>/`.
    def self.cache_dir(repo, kind : String) : String
      File.join(repo.wt_dir, "cache", kind)
    end

    # Read and deserialize a JSON cache entry.
    # Returns nil on any failure. Corrupt JSON is logged but treated as a miss.
    def self.read_json(path : String)
      json = File.read(path)
      JSON.parse(json)
    rescue JSON::ParseException
      nil
    rescue File::NotFoundError | IO::Error
      nil
    end

    # Read a JSON entry at `<wt-cache>/<kind>/<key>`.
    # Paired with write_with_lru for the flat-dir "kind + key filename" layout.
    def self.read(repo, kind : String, key : String)
      read_json(File.join(cache_dir(repo, kind), key))
    end

    # Serialize and write a JSON cache entry, creating parent directories.
    # Degrades silently on any failure.
    def self.write_json(path : String, value : JSON::Any)
      dir = File.dirname(path)
      mkdir_p(dir) unless Dir.exists?(dir)
      File.write(path, value.to_json)
    rescue IO::Error | File::NotFoundError
      # Silently degrade — cache is always an optimization
    end

    # Recursive mkdir -p
    private def self.mkdir_p(path : String)
      parent = File.dirname(path)
      unless Dir.exists?(parent)
        mkdir_p(parent)
      end
      Dir.mkdir(path) unless Dir.exists?(path)
    end

    # Write a JSON entry, then sweep the kind directory to hold at most
    # max_entries top-level .json files.
    def self.write_with_lru(repo, kind : String, key : String, value : JSON::Any, max_entries : Int32)
      dir = cache_dir(repo, kind)
      write_json(File.join(dir, key), value)
      sweep_lru(dir, max_entries)
    end

    # Enforce a size bound on dir. If it holds more than max top-level
    # .json entries, delete the oldest-mtime files until count is at max.
    #
    # Fast path: single directory listing and count_json_files — no per-file stat
    # when the cache is under the bound.
    def self.sweep_lru(dir : String, max : Int32)
      return if count_json_files(dir) <= max

      entries = Dir.children(dir)
        .select(&.ends_with?(".json"))
        .map { |name| {File.join(dir, name), File.info(File.join(dir, name)).modification_time} }
        .sort_by! { |_, mtime| mtime }

      excess = entries.size - max
      return if excess <= 0

      entries.first(excess).each do |path, _|
        File.delete(path) rescue nil
      end
    end

    # Remove a single cache entry.
    # Returns true if a file was removed, false if it was already gone.
    # Raises on permission-denied or other non-NotFound errors.
    def self.clear_one(path : String) : Bool
      File.delete(path)
      true
    rescue File::NotFoundError
      false
    end

    # Remove every top-level .json file in dir, returning the count removed.
    # Missing directory returns 0. Non-.json siblings are left in place.
    def self.clear_json_files(dir : String) : Int32
      return 0 unless Dir.exists?(dir)
      cleared = 0
      Dir.children(dir).each do |name|
        next unless name.ends_with?(".json")
        path = File.join(dir, name)
        cleared += 1 if clear_one(path)
      end
      cleared
    end

    # Count top-level .json files in dir, returning 0 when missing.
    def self.count_json_files(dir : String) : Int32
      return 0 unless Dir.exists?(dir)
      Dir.children(dir).count(&.ends_with?(".json"))
    end
  end
end
