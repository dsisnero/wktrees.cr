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
  end
end
