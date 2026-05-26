# SHA-keyed git result cache — Crystal port of worktrunk/src/git/repository/sha_cache.rs
#
# Caches results of expensive git operations keyed on commit SHA pairs,
# stored as JSON files under `.git/wt/cache/{kind}/{key}.json`.
# Content-addressed — no TTL, only LRU size bounds.

require "../cache"

module WorkTrees
  module Git
    module ShaCache
      MAX_ENTRIES_PER_KIND = 5000

      KIND_MERGE_TREE_CONFLICTS = "merge-tree-conflicts"
      KIND_MERGE_ADD_PROBE      = "merge-add-probe"
      KIND_IS_ANCESTOR          = "is-ancestor"
      KIND_HAS_ADDED_CHANGES    = "has-added-changes"
      KIND_DIFF_STATS           = "diff-stats"
      KIND_AHEAD_BEHIND         = "ahead-behind"

      ALL_KINDS = [
        KIND_MERGE_TREE_CONFLICTS,
        KIND_MERGE_ADD_PROBE,
        KIND_IS_ANCESTOR,
        KIND_HAS_ADDED_CHANGES,
        KIND_DIFF_STATS,
        KIND_AHEAD_BEHIND,
      ]

      # The cache directory for a given kind under `<repo-common-dir>/wt/cache/`.
      private def self.kind_dir(repo : Repository, kind : String) : String
        File.join(repo.git_common_dir, "wt", "cache", kind)
      end

      # Build a symmetric filename from a SHA pair (order-independent).
      def self.symmetric_key(sha1 : String, sha2 : String) : String
        if sha1 <= sha2
          "#{sha1}-#{sha2}.json"
        else
          "#{sha2}-#{sha1}.json"
        end
      end

      # Build an asymmetric filename from a SHA pair (order preserved).
      def self.asymmetric_key(first : String, second : String) : String
        "#{first}-#{second}.json"
      end

      # Read a cached value. Returns nil on any failure.
      private def self.json_read(path : String) : JSON::Any?
        JSON.parse(File.read(path))
      rescue
        nil
      end

      # Write a value, creating parent directories. Degrades silently.
      private def self.json_write(path : String, value : JSON::Any) : Nil
        dir = File.dirname(path)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)
        File.write(path, value.to_json)
      rescue
        nil
      end

      # Read a cached JSON entry from the SHA cache.
      def self.read(repo : Repository, kind : String, key : String) : JSON::Any?
        path = File.join(kind_dir(repo, kind), key)
        json_read(path)
      end

      # Write a cached value with LRU sweep.
      def self.write_with_lru(repo : Repository, kind : String, key : String, value : JSON::Any) : Nil
        dir = kind_dir(repo, kind)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)
        path = File.join(dir, key)
        json_write(path, value)
        sweep_lru(dir) if Dir.exists?(dir)
      end

      # Remove oldest entries when the cache size exceeds MAX_ENTRIES_PER_KIND.
      private def self.sweep_lru(dir : String) : Nil
        entries = Dir.children(dir)
          .select(&.ends_with?(".json"))
          .map do |file|
            {file, File.info(File.join(dir, file)).modification_time}
          end
        entries.sort_by!(&.[1])
        if entries.size > MAX_ENTRIES_PER_KIND
          entries.take(entries.size - MAX_ENTRIES_PER_KIND).each do |(file_name, _)|
            File.delete(File.join(dir, file_name)) rescue nil
          end
        end
      end
    end
  end
end
