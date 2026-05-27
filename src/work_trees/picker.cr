# Interactive picker — Crystal port of vendor/worktrunk/src/commands/picker/
#
# Uses bubbletea + bubbles for a fully integrated TUI picker
# instead of shelling out to an external fzf/skim binary.
#
# Architecture: Elm model (Tea::Model) with Bubbles::List for item selection
# and Bubbles::Viewport for preview rendering.

require "bubbles"
require "lipgloss"
require "./git/worktree_info"

module WorkTrees
  module Picker
    # Preview mode constants matching vendor numbering.
    enum PreviewMode
      WorkingTree  = 1
      Log          = 2
      BranchDiff   = 3
      UpstreamDiff = 4
      Summary      = 5
    end

    # A pickable worktree item implementing Bubbles::List::DefaultItem.
    struct PickerItem
      include Bubbles::List::DefaultItem

      getter branch : String
      getter worktree_path : String
      getter head_sha : String
      getter status_symbols : String
      getter? is_current : Bool

      def initialize(
        @branch : String,
        @worktree_path : String = "",
        @head_sha : String = "",
        @is_current : Bool = false,
        @status_symbols : String = "",
      )
      end

      def filter_value : String
        "#{@branch} #{@worktree_path}"
      end

      def title : String
        @branch
      end

      def description : String
        parts = [] of String
        parts << "@" if @is_current
        parts << @worktree_path unless @worktree_path.empty?
        parts << @status_symbols unless @status_symbols.empty?
        parts.join(" ")
      end
    end

    # Convert WorktreeInfo objects to PickerItems.
    def self.build_items(worktrees : Array(Git::WorktreeInfo)) : Array(PickerItem)
      worktrees.map do |worktree|
        PickerItem.new(
          branch: worktree.branch || "(detached)",
          worktree_path: worktree.path,
          head_sha: worktree.head,
        )
      end
    end
  end
end
