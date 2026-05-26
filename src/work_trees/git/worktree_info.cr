# WorktreeInfo — parsed representation of a git worktree.
# Ported from vendor/worktrunk/src/git/mod.rs:637 and src/git/parse.rs

require "../cmd"

module WorkTrees
  module Git
    NULL_OID = "0000000000000000000000000000000000000000"

    class WorktreeInfo
      property path : String
      property head : String
      property branch : String?
      property? bare : Bool = false
      property? detached : Bool = false
      property locked : String?
      property prunable : String?

      def initialize(
        @path = "",
        @head = "",
        @branch = nil,
        @bare = false,
        @detached = false,
        @locked = nil,
        @prunable = nil,
      )
      end

      # Parse porcelain output into WorktreeInfo objects.
      def self.parse_porcelain_list(output : String) : Array(WorktreeInfo)
        worktrees = [] of WorktreeInfo
        current = WorktreeInfo.new

        output.each_line do |line|
          if line.blank?
            worktrees << current if current.head.presence
            current = WorktreeInfo.new
            next
          end

          parse_line(current, line)
        end

        worktrees << current if current.head.presence
        worktrees
      end

      private def self.parse_line(current : WorktreeInfo, line : String) : Nil
        parts = line.split(' ', 2)
        key = parts[0]
        value = parts[1]?.try(&.presence)

        case key
        when "worktree" then current.path = value || ""
        when "HEAD"     then current.head = value || ""
        when "branch"
          if v = value
            current.branch = v.lchop?("refs/heads/") || v
          end
        when "bare"     then current.bare = true
        when "detached" then current.detached = true
        when "locked"   then current.locked = value
        when "prunable" then current.prunable = value
        end
      end

      def prunable? : Bool
        !@prunable.nil?
      end

      def locked? : Bool
        !@locked.nil?
      end

      def has_commits? : Bool
        @head != NULL_OID
      end

      def dir_name : String
        ::File.basename(@path)
      end
    end

    # Repository extensions for worktree management.
    class Repository
      def list_worktrees : Array(WorktreeInfo)
        output = run_command(["worktree", "list", "--porcelain"])
        WorktreeInfo.parse_porcelain_list(output).reject(&.bare?)
      end

      def worktree_for_branch(branch : String) : String?
        list_worktrees.each do |worktree|
          return worktree.path if worktree.branch == branch
        end
        nil
      end
    end
  end
end
