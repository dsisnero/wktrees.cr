# Git diff utilities — Crystal port of worktrunk/src/git/diff.rs
#
# Parses git --numstat and --shortstat output into structured diff statistics.

module WorkTrees
  module Git
    # Line-level diff totals (added/deleted counts).
    struct LineDiff
      property added : Int32 = 0
      property deleted : Int32 = 0

      def self.new(added : Int32, deleted : Int32)
        instance = allocate
        instance.initialize(added, deleted)
        instance
      end

      def initialize(@added = 0, @deleted = 0)
      end

      def self.from_shortstat(output : String) : LineDiff
        parts = Git.parse_shortstat(output)
        if parts
          _, ins, del = parts
          new(ins, del)
        else
          new
        end
      end

      def empty? : Bool
        @added == 0 && @deleted == 0
      end

      def to_tuple : {Int32, Int32}
        {@added, @deleted}
      end
    end

    # Diff statistics (files changed, insertions, deletions).
    struct DiffStats
      property files : Int32 = 0
      property insertions : Int32 = 0
      property deletions : Int32 = 0

      def initialize(@files = 0, @insertions = 0, @deletions = 0)
      end

      def self.from_shortstat(output : String) : DiffStats
        parts = Git.parse_shortstat(output)
        if parts
          files, ins, del = parts
          new(files, ins, del)
        else
          new
        end
      end

      def format_summary : Array(String)
        parts = [] of String
        if @files > 0
          s = @files == 1 ? "" : "s"
          parts << "#{@files} file#{s}"
        end
        if @insertions > 0
          parts << Styling.green("+#{@insertions}")
        end
        if @deletions > 0
          parts << Styling.red("-#{@deletions}")
        end
        parts
      end
    end

    # Parse a git numstat line and extract insertions/deletions.
    #
    # Supports standard `git diff --numstat` output as well as log output with
    # `--graph --color=always` prefixes.
    # Returns `nil` for binary entries (`-` counts) or unparseable lines.
    def self.parse_numstat_line(line : String) : {Int32, Int32}?
      # Strip ANSI escape sequences (graph coloring contains digits)
      stripped = line.gsub(/\e\[[0-9;]*m/, "")

      # Strip graph prefix and find tab-separated values
      trimmed = stripped.lstrip { |char| !char.ascii_number? && char != '-' }

      parts = trimmed.split('\t')
      added_str = parts[0]?
      deleted_str = parts[1]?
      return nil unless added_str && deleted_str

      # "-" means binary file; skip
      return nil if added_str == "-" || deleted_str == "-"

      added = added_str.to_i?
      deleted = deleted_str.to_i?
      return nil unless added && deleted

      {added, deleted}
    end

    # Parse `git diff --shortstat` output into (files, insertions, deletions).
    #
    # The format is: `N file(s) changed, N insertion(s)(+), N deletion(s)(-)`
    # with optional parts omitted when zero. The `(+)` and `(-)` markers are
    # hardcoded in git's C source and not subject to localization.
    def self.parse_shortstat(output : String) : {Int32, Int32, Int32}?
      line = output.strip
      return nil if line.empty?

      files = 0
      insertions = 0
      deletions = 0

      line.split(',').each_with_index do |part, i|
        # Find the first number in each comma-separated part
        num = 0
        part.split(' ').each do |word|
          if val = word.to_i?
            num = val
            break
          end
        end

        if i == 0
          files = num
        elsif part.includes?("(+)")
          insertions = num
        elsif part.includes?("(-)")
          deletions = num
        end
      end

      {files, insertions, deletions}
    end
  end
end
