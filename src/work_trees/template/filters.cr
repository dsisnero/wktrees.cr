# Ported from vendor/worktrunk/src/config/expansion.rs
# Template filter functions used by worktree-path templates and hook commands.
#
# All filters are implemented as module-level functions so they can be called
# from ECR templates and from the runtime template expansion engine.

module WorkTrees
  module Template
    # Base-36 character set for short_hash encoding.
    private BASE36_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"

    # Replace path separators with dashes for filesystem-safe paths.
    #
    # Port of `sanitize_branch_name` (expansion.rs:390).
    #
    # ```
    # WorkTrees::Template.sanitize("feature/foo")   # => "feature-foo"
    # WorkTrees::Template.sanitize("user\\task")    # => "user-task"
    # WorkTrees::Template.sanitize("simple-branch") # => "simple-branch"
    # ```
    def self.sanitize(value : String) : String
      value.gsub(/[\/\\]/, "-")
    end

    # Generate a 3-character base-36 hash suffix from a string.
    #
    # Port of `short_hash` (expansion.rs:472).
    # Uses Crystal's stdlib hash for portability across architectures.
    #
    # ```
    # WorkTrees::Template.short_hash("feature/auth") # => "abc" (3 chars, deterministic)
    # ```
    def self.short_hash(s : String) : String
      h = s.hash.to_u64!
      c0 = BASE36_CHARS[(h % 36).to_i]
      c1 = BASE36_CHARS[((h // 36) % 36).to_i]
      c2 = BASE36_CHARS[((h // 1296) % 36).to_i]
      String.build(3) { |io| io << c0 << c1 << c2 }
    end

    # Sanitize a string for use as a database identifier.
    #
    # Port of `sanitize_db` (expansion.rs:428).
    # Produces identifiers compatible with PostgreSQL (max 48 chars).
    #
    # Transformation rules (applied in order):
    # 1. Convert to lowercase
    # 2. Replace non-alphanumeric characters with `_`
    # 3. Collapse consecutive underscores
    # 4. Add `_` prefix if starts with digit
    # 5. Append 3-char hash suffix
    # 6. Truncate to 48 characters total
    #
    # ```
    # WorkTrees::Template.sanitize_db("feature/auth").starts_with?("feature_auth_")    # => true
    # WorkTrees::Template.sanitize_db("123-bug-fix").starts_with?("_123_bug_fix_")     # => true
    # WorkTrees::Template.sanitize_db("a-b") != WorkTrees::Template.sanitize_db("a_b") # => true
    # ```
    def self.sanitize_db(s : String) : String
      return "" if s.empty?

      result = String.build(s.size + 4) do |io|
        prev_underscore = false
        s.each_char do |char|
          if char.ascii_alphanumeric?
            io << char.downcase
            prev_underscore = false
          elsif !prev_underscore
            io << '_'
            prev_underscore = true
          end
        end
      end

      # Prefix with underscore if starts with digit
      if result[0]?.try(&.ascii_number?)
        result = "_#{result}"
      end

      # Truncate base to leave room for hash suffix (4 chars: _ + 3 hash chars)
      # Total cap is 48 chars, max base is 44
      if result.size > 44
        result = result[0, 44]
      end

      unless result.ends_with?('_')
        result = "#{result}_"
      end
      result += short_hash(s)
      result
    end

    # Sanitize a string for use as a filename on all platforms.
    #
    # Port of `sanitize_for_filename` (path.rs:190).
    # Replaces invalid characters with `-`. If the input was changed,
    # appends a 3-char hash suffix to avoid collisions.
    #
    # ```
    # WorkTrees::Template.sanitize_hash("simple")      # => "simple" (unchanged)
    # WorkTrees::Template.sanitize_hash("feature/foo") # => "feature-foo-abc"
    # ```
    def self.sanitize_hash(value : String) : String
      return "" if value.empty?

      sanitized = value.gsub(/[<>:\"\/\\|?*\x00-\x1f]/, "-")

      if sanitized == value
        return sanitized
      end

      result = if sanitized.empty?
                 "_empty"
               else
                 sanitized
               end
      unless result.ends_with?('-')
        result = "#{result}-"
      end
      result + short_hash(value)
    end

    # Hash a string to a port number in range 10000..19999.
    #
    # Port of `string_to_port` (expansion.rs:354).
    #
    # ```
    # port = WorkTrees::Template.hash_port("my-branch")
    # (10000..19999).should contain(port)
    # ```
    def self.hash_port(s : String) : UInt16
      h = s.hash.to_u64!
      (10000_u16 + (h % 10000).to_u16)
    end

    # Strip everything after the last path separator.
    #
    # Port of the `dirname` filter (expansion.rs:701).
    #
    # ```
    # WorkTrees::Template.dirname("/a/b/c") # => "/a/b"
    # WorkTrees::Template.dirname("file")   # => ""
    # ```
    def self.dirname(value : String) : String
      dir = ::File.dirname(value)
      dir == "." ? "" : dir
    end

    # Return the file portion of a path (last component).
    #
    # Port of the `basename` filter (expansion.rs:707).
    #
    # ```
    # WorkTrees::Template.basename("/a/b/c") # => "c"
    # WorkTrees::Template.basename("file")   # => "file"
    # ```
    def self.basename(value : String) : String
      ::File.basename(value)
    end

    # Redact credentials from URLs for safe logging.
    #
    # Port of `redact_credentials` (expansion.rs:570).
    #
    # ```
    # WorkTrees::Template.redact_credentials("https://token@github.com/owner/repo")
    # # => "https://[REDACTED]@github.com/owner/repo"
    # ```
    def self.redact_credentials(s : String) : String
      s.sub(/^([a-z][a-z0-9+.-]*:\/\/)([^@\/]+)@/) { "#{$1}[REDACTED]@" }
    end
  end
end
