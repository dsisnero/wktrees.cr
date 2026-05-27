# List item types — Crystal port of worktrunk/src/commands/list/model/item.rs
#
# Core data structures for representing worktrees and branches in wt list output.
# Uses JSON::Serializable for type-safe JSON output.

require "json"

module WorkTrees
  module List
    struct DisplayFields
      include JSON::Serializable

      @[JSON::Field(key: "ci_status")]
      property ci_status : String?

      @[JSON::Field(key: "working_diff")]
      property working_diff : String?

      @[JSON::Field(key: "upstream")]
      property upstream_status : String?

      property summary : String?
      property status : String?
      property commits : String?

      @[JSON::Field(key: "branch_diff")]
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

    struct ListItem
      include JSON::Serializable

      property branch : String
      property head : String

      @[JSON::Field(key: "worktree_path")]
      property worktree_path : String?

      property? current : Bool

      def initialize(
        @branch : String,
        @worktree_path : String? = nil,
        @head : String = "",
        @current : Bool = false,
      )
      end

      def display_name : String
        @branch
      end
    end

    struct ListData
      include JSON::Serializable

      property branch : String
      property head : String
      property worktree_path : String?
      property? current : Bool
      property ahead : Int32
      property behind : Int32

      @[JSON::Field(key: "ci_status")]
      property ci_status : String?

      @[JSON::Field(key: "working_diff")]
      property working_diff : String?

      @[JSON::Field(key: "upstream")]
      property upstream_status : String?

      property summary : String?

      def initialize(
        @branch : String,
        @head : String = "",
        @worktree_path : String? = nil,
        @current : Bool = false,
        @ahead : Int32 = 0,
        @behind : Int32 = 0,
        @ci_status : String? = nil,
        @working_diff : String? = nil,
        @upstream_status : String? = nil,
        @summary : String? = nil,
      )
      end

      # Single-line status output for shell prompts.
      #
      # Format: `branch  ↑a  ↓b  +N -M  ✓  summary`
      def statusline : String
        parts = [@branch]

        if @ahead > 0
          parts << Styling.green("↑#{@ahead}")
        end
        if @behind > 0
          parts << Styling.red("↓#{@behind}")
        end
        if wd = @working_diff
          parts << wd unless wd.empty?
        end
        if ci = @ci_status
          parts << ci unless ci.empty?
        end
        if s = @summary
          parts << s unless s.empty?
        end

        parts.join("  ")
      end
    end
  end
end
