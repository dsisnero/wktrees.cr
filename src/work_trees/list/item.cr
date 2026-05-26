# List item types — Crystal port of worktrunk/src/commands/list/model/item.rs
#
# Core data structures for representing worktrees and branches in wt list output.
# Replaces ad-hoc hashes with structured types.

module WorkTrees
  module List
    # Pre-formatted display strings for a list row (ANSI-styled).
    struct DisplayFields
      property ci_status : String?
      property working_diff : String?
      property upstream_status : String?
      property summary : String?
      property status : String?
      property commits : String?
      property branch_diff : String?

      def initialize(
        @ci_status : String? = nil,
        @working_diff : String? = nil,
        @upstream_status : String? = nil,
        @summary : String? = nil,
        @status : String? = nil,
        @commits : String? = nil,
        @branch_diff : String? = nil,
      )
      end
    end

    # A single item in the wt list output — either a worktree or branch.
    struct ListItem
      getter branch : String
      getter worktree_path : String?
      getter head_sha : String
      getter? current : Bool

      def initialize(
        @branch : String,
        @worktree_path : String? = nil,
        @head_sha : String = "",
        @current : Bool = false,
      )
      end

      # Display name for the branch (may include remote/ prefix).
      def display_name : String
        @branch
      end
    end

    # ListData pairs a ListItem with its computed DisplayFields and counts.
    struct ListData
      getter item : ListItem
      getter fields : DisplayFields
      getter ahead : Int32
      getter behind : Int32

      def initialize(
        @item : ListItem,
        @fields : DisplayFields = DisplayFields.new,
        @ahead : Int32 = 0,
        @behind : Int32 = 0,
      )
      end
    end
  end
end
