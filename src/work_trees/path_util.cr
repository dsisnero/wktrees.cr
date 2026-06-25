# Path utilities — Crystal port of worktrunk/src/path.rs
#
# Uses Crystal's stdlib Path for home directory resolution.

module WorkTrees
  module PathUtil
    UNSAFE_CHARS = "/\\:"

    def self.sanitize_for_filename(name : String) : String
      result = name
      UNSAFE_CHARS.each_char do |char|
        result = result.gsub(char, '-')
      end
      result = result.gsub(/-+/, "-")
      result = result.lstrip('-').rstrip('-')
      result
    end

    def self.format_path_for_display(path : String) : String
      home = Path.home.to_s
      if path.starts_with?(home)
        "~#{path[home.size..]}"
      else
        path
      end
    end

    # Expand ~ at the start of a path to the user's home directory.
    def self.expand_home(path : String) : String
      if path == "~"
        Path.home.to_s
      elsif path.starts_with?("~/")
        File.join(Path.home.to_s, path[2..])
      else
        path
      end
    end

    # Resolve a path by canonicalizing the longest existing prefix, then
    # appending any nonexistent tail components. Handles symlinked ancestor
    # directories (e.g. macOS /var → /private/var) for computed worktree
    # paths that don't exist yet.
    #
    # Mirrors vendor/worktrunk/src/path.rs `canonicalize_with_parents`.
    def self.canonicalize_with_parents(path_str : String) : String
      return path_str if path_str.empty?

      expanded = File.expand_path(path_str, home: false)

      if File.exists?(expanded) || Dir.exists?(expanded)
        begin
          return File.real_path(expanded)
        rescue
          return expanded
        end
      end

      components = [] of String
      current = expanded
      loop do
        break if File.exists?(current) || Dir.exists?(current)
        parent = File.dirname(current)
        return path_str if parent == current
        components << File.basename(current)
        current = parent
      end

      prefix = begin
        File.real_path(current)
      rescue
        current
      end

      result = prefix
      components.reverse_each { |comp| result = File.join(result, comp) }
      result
    end
  end
end
