# Column definitions for `wt list` — Crystal port of worktrunk.
#
# Ported from vendor/worktrunk/src/commands/list/columns.rs
#
# COLUMN_SPECS is the single source of truth for display order, base priority
# (lower = kept longer during truncation), task dependency, and shrinkability.

module WorkTrees
  module List
    # Logical identifier for each column rendered by `wt list`.
    enum ColumnKind
      Gutter # Type indicator: @ (current), ^ (main), + (worktree), space (branch-only)
      Branch
      Status      # Includes both git status symbols and user-defined status
      WorkingDiff # HEAD± — working tree changes
      AheadBehind # main↕ — commits ahead/behind default branch
      BranchDiff  # main…± — line diff vs default branch
      Summary
      Upstream # Remote⇅ — commits ahead/behind remote
      CiStatus
      Path
      Url # Dev server URL from project config template
      Commit
      Time
      Message

      # Column header text displayed in the table.
      def header : String
        case self
        in .gutter?       then ""
        in .branch?       then "Branch"
        in .status?       then "Status"
        in .working_diff? then "HEAD±"
        in .ahead_behind? then "main↕"
        in .branch_diff?  then "main…±"
        in .path?         then "Path"
        in .upstream?     then "Remote⇅"
        in .url?          then "URL"
        in .time?         then "Age"
        in .ci_status?    then "CI"
        in .commit?       then "Commit"
        in .summary?      then "Summary"
        in .message?      then "Message"
        end
      end

      # Base priority for this column (lower = more important).
      # Used by layout and statusline truncation.
      def priority : UInt8
        COLUMN_SPECS.each do |spec|
          return spec.base_priority if spec.kind == self
        end
        UInt8::MAX
      end
    end

    # Differentiates between diff-style columns with plus/minus symbols and arrow styles.
    enum DiffVariant
      Signs
      Arrows         # Simple arrows (↑↓) for commits ahead/behind main
      UpstreamArrows # Double-struck arrows (⇡⇣) for commits ahead/behind remote
    end

    # Static metadata describing a column's behavior in both layout and rendering.
    struct ColumnSpec
      getter kind : ColumnKind
      getter base_priority : UInt8
      getter requires_task : String? # TaskKind name; Some = column hidden when task skipped
      getter? shrinkable : Bool = false

      def initialize(
        @kind : ColumnKind,
        @base_priority : UInt8,
        @requires_task : String? = nil,
        @shrinkable : Bool = false,
      )
      end

      # Builder method: marks this column as shrinkable.
      def shrinkable! : self
        @shrinkable = true
        self
      end
    end

    # Static registry of all possible columns in display order.
    # base_priority determines truncation order (lower = kept longer),
    # which is independent of display order (position in array).
    COLUMN_SPECS = [
      ColumnSpec.new(ColumnKind::Gutter, 0_u8),
      ColumnSpec.new(ColumnKind::Branch, 1_u8).shrinkable!,
      ColumnSpec.new(ColumnKind::Status, 2_u8),
      ColumnSpec.new(ColumnKind::WorkingDiff, 3_u8),
      ColumnSpec.new(ColumnKind::AheadBehind, 4_u8),
      ColumnSpec.new(ColumnKind::BranchDiff, 6_u8, "branch-diff"),
      ColumnSpec.new(ColumnKind::Summary, 10_u8, "summary-generate"),
      ColumnSpec.new(ColumnKind::Upstream, 8_u8),
      ColumnSpec.new(ColumnKind::CiStatus, 5_u8, "ci-status"),
      ColumnSpec.new(ColumnKind::Path, 7_u8),
      ColumnSpec.new(ColumnKind::Url, 9_u8, "url-status"),
      ColumnSpec.new(ColumnKind::Commit, 11_u8),
      ColumnSpec.new(ColumnKind::Time, 12_u8),
      ColumnSpec.new(ColumnKind::Message, 13_u8),
    ]

    # Index of a column kind in COLUMN_SPECS display order.
    def self.column_display_index(kind : ColumnKind) : Int32
      COLUMN_SPECS.each_with_index do |spec, idx|
        return idx if spec.kind == kind
      end
      Int32::MAX
    end
  end
end
