# Model types for `wt list` — Crystal port of worktrunk list command.
#
# Ported from vendor/worktrunk/src/commands/list/model/
# - state.rs    → state enums (Divergence, WorktreeState, MainState, OperationState, ActiveGitOperation, Tier)
# - stats.rs    → AheadBehind, UpstreamStatus
# - status_symbols.rs → WorkingTreeStatus, StatusSymbols, SlotState
# - statusline_segment.rs → StatuslineSegment

require "colorize"

module WorkTrees
  module List
    # ---------------------------------------------------------------
    # Divergence — upstream divergence relative to remote tracking branch
    # ---------------------------------------------------------------
    enum Divergence
      None     # No remote tracking branch configured
      InSync   # In sync with upstream remote
      Ahead    # Has commits the remote doesn't have
      Behind   # Missing commits from the remote
      Diverged # Both ahead and behind the remote

      def self.from_counts_with_remote(ahead : Int32, behind : Int32) : Divergence
        case {ahead, behind}
        when {0, 0} then InSync
        when {_, 0} then Ahead
        when {0, _} then Behind
        else             Diverged
        end
      end

      def symbol : String
        case self
        in .none?     then ""
        in .in_sync?  then "|"
        in .ahead?    then "⇡"
        in .behind?   then "⇣"
        in .diverged? then "⇅"
        end
      end

      # Returns styled symbol (dimmed), or nil for None variant.
      def styled : String?
        return nil if none?
        symbol.colorize.dim.to_s
      end
    end

    # ---------------------------------------------------------------
    # IntegrationReason — how content reached the default branch
    # ---------------------------------------------------------------
    enum IntegrationReason
      SameCommit
      Ancestor
      TreesMatch
      NoAddedChanges
      MergeAddsNothing
      PatchIdMatch
    end

    # ---------------------------------------------------------------
    # MainState — default branch relationship state
    #
    # Priority order:
    #   IsMain > Orphan > WouldConflict > Empty > SameCommit >
    #   Integrated > Diverged > Ahead > Behind > None
    # ---------------------------------------------------------------
    enum MainState
      None          # Normal working branch (up-to-date)
      IsMain        # This IS the main worktree
      WouldConflict # Merge-tree conflicts with default branch
      Empty         # Same commit as default AND clean working tree
      SameCommit    # Same commit as default with uncommitted changes
      Integrated    # Content is in default branch via different history
      Orphan        # No common ancestor with default branch
      Diverged      # Both ahead and behind default branch
      Ahead         # Has commits default branch doesn't have
      Behind        # Missing commits from default branch

      def integration_reason : IntegrationReason?
        nil
      end

      def to_s(io : IO) : Nil
        io << case self
        in .none?           then ""
        in .is_main?        then "^"
        in .would_conflict? then "✗"
        in .empty?          then "_"
        in .same_commit?    then "–" # en-dash U+2013
        in .integrated?     then "⊂"
        in .orphan?         then "∅" # U+2205 empty set
        in .diverged?       then "↕"
        in .ahead?          then "↑"
        in .behind?         then "↓"
        end
      end

      def display : String
        io = IO::Memory.new
        to_s(io)
        io.to_s
      end

      # Returns styled symbol with appropriate color, or nil for None.
      def styled : String?
        return nil if none?
        s = display
        if would_conflict?
          s.colorize.yellow.to_s
        else
          s.colorize.dim.to_s
        end
      end

      def as_json_str : String?
        s = display
        s.empty? ? nil : s
      end

      def self.from_integration_and_counts(
        is_main : Bool,
        would_conflict : Bool,
        integration : MainState?,
        is_same_commit_dirty : Bool,
        is_orphan : Bool,
        ahead : Int32,
        behind : Int32,
      ) : MainState
        return IsMain if is_main
        return Orphan if is_orphan
        return WouldConflict if would_conflict

        if state = integration
          return state
        end

        if is_same_commit_dirty
          return SameCommit
        end

        case {ahead, behind}
        when {0, 0} then None
        when {_, 0} then Ahead
        when {0, _} then Behind
        else             Diverged
        end
      end
    end

    # ---------------------------------------------------------------
    # WorktreeState — worktree "location" state indicator
    #
    # Priority: BranchWorktreeMismatch > Prunable > Locked > Branch > None
    # ---------------------------------------------------------------
    enum WorktreeState
      None                   # Normal worktree
      BranchWorktreeMismatch # Path doesn't match template
      Prunable               # Worktree directory missing
      Locked                 # Protected from removal
      Branch                 # Branch without worktree

      def to_s(io : IO) : Nil
        io << case self
        in .none?                     then ""
        in .branch_worktree_mismatch? then "⚑"
        in .prunable?                 then "⊟"
        in .locked?                   then "⊞"
        in .branch?                   then "/"
        end
      end

      def display : String
        io = IO::Memory.new
        to_s(io)
        io.to_s
      end
    end

    # ---------------------------------------------------------------
    # OperationState — blocking git operation in progress
    #
    # Priority: Conflicts > Rebase > Merge > None
    # ---------------------------------------------------------------
    enum OperationState
      None      # No operation in progress
      Conflicts # Unmerged paths in working tree
      Rebase    # Rebase in progress
      Merge     # Merge in progress

      def to_s(io : IO) : Nil
        io << case self
        in .none?      then ""
        in .conflicts? then "✘"
        in .rebase?    then "⤴"
        in .merge?     then "⤵"
        end
      end

      def display : String
        io = IO::Memory.new
        to_s(io)
        io.to_s
      end

      def styled : String?
        return nil if none?
        s = display
        if conflicts?
          s.colorize.red.to_s
        else
          s.colorize.yellow.to_s
        end
      end

      def as_json_str : String?
        s = display
        s.empty? ? nil : s
      end
    end

    # ---------------------------------------------------------------
    # ActiveGitOperation — raw data about active git ops
    # ---------------------------------------------------------------
    enum ActiveGitOperation
      None
      Rebase
      Merge

      def none? : Bool
        self == None
      end
    end

    # ---------------------------------------------------------------
    # Tier — per-gate resolution with partial data
    #
    # Fired(T)  = tier's signal is known and positive; use this value
    # RuledOut  = tier's signal is known negative; fall through
    # Wait      = tier's signal not loaded; gate must wait
    # ---------------------------------------------------------------
    enum Tier
      Fired
      RuledOut
      Wait
    end

    # Tier 1: IsMain. Resolves immediately from metadata.
    def self.tier_is_main(is_main : Bool) : {Tier, MainState?}
      if is_main
        {Tier::Fired, MainState::IsMain}
      else
        {Tier::RuledOut, nil}
      end
    end

    # Tier 2: Orphan. Requires is_orphan to be loaded.
    def self.tier_orphan(is_orphan : Bool?) : {Tier, MainState?}
      case is_orphan
      when true  then {Tier::Fired, MainState::Orphan}
      when false then {Tier::RuledOut, nil}
      else            {Tier::Wait, nil}
      end
    end

    # Represents the 3-state working-tree conflict probe result.
    # Mirrors Rust's `Option<Option<bool>>`:
    #   NotRun = None (task not run)
    #   Clean  = Some(None) (task ran, no dirty-tree result)
    #   Conflicts/NoConflicts = Some(Some(b)) (dirty-tree result)
    enum WorkingTreeConflictProbe
      NotRun
      Clean
      Conflicts
      NoConflicts
    end

    # Tier 3: WouldConflict. Working-tree probe is authoritative when present.
    def self.tier_would_conflict(
      has_merge_tree_conflicts : Bool?,
      has_working_tree_conflicts : WorkingTreeConflictProbe,
    ) : {Tier, MainState?}
      case has_working_tree_conflicts
      in .conflicts?
        # Working-tree probe shows dirty conflict → fire (authoritative)
        {Tier::Fired, MainState::WouldConflict}
      in .no_conflicts?
        # Working-tree probe shows dirty no-conflict → rule out (authoritative)
        {Tier::RuledOut, nil}
      in .clean?
        # Working tree ran and is clean — fall back to HEAD probe
        case has_merge_tree_conflicts
        when true  then {Tier::Fired, MainState::WouldConflict}
        when false then {Tier::RuledOut, nil}
        else            {Tier::RuledOut, nil}
        end
      in .not_run?
        # Working tree not probed — consult HEAD probe only
        case has_merge_tree_conflicts
        when true  then {Tier::Fired, MainState::WouldConflict}
        when false then {Tier::Wait, nil}
        else            {Tier::Wait, nil}
        end
      end
    end

    # Tiers 4-6: integration / same-commit-dirty / counts-based fallback.
    def self.tier_integration_or_counts(
      counts : AheadBehind?,
      is_clean : Bool?,
      integration : MainState?,
    ) : {Tier, MainState?}
      return {Tier::Wait, nil} unless counts
      return {Tier::Wait, nil} if is_clean.nil?
      is_clean_value = is_clean.as(Bool)

      is_same_commit_dirty = !is_clean_value && counts.ahead == 0 && counts.behind == 0
      state = MainState.from_integration_and_counts(
        false, false, integration, is_same_commit_dirty,
        false, counts.ahead, counts.behind
      )
      {Tier::Fired, state}
    end

    # ---------------------------------------------------------------
    # AheadBehind — commit count diff vs base branch
    # ---------------------------------------------------------------
    struct AheadBehind
      property ahead : Int32
      property behind : Int32

      def initialize(@ahead : Int32 = 0, @behind : Int32 = 0)
      end
    end

    # ---------------------------------------------------------------
    # UpstreamStatus — remote tracking info
    # ---------------------------------------------------------------
    struct UpstreamStatus
      property remote : String?
      property ahead : Int32
      property behind : Int32

      def initialize(@remote : String? = nil, @ahead : Int32 = 0, @behind : Int32 = 0)
      end

      def active? : Bool
        !remote.nil?
      end
    end

    # ---------------------------------------------------------------
    # WorkingTreeStatus — boolean flags for working tree changes
    # ---------------------------------------------------------------
    struct WorkingTreeStatus
      getter? staged : Bool
      getter? modified : Bool
      getter? untracked : Bool
      getter? renamed : Bool
      getter? deleted : Bool

      def initialize(
        @staged : Bool = false,
        @modified : Bool = false,
        @untracked : Bool = false,
        @renamed : Bool = false,
        @deleted : Bool = false,
      )
      end

      def dirty? : Bool
        staged? || modified? || untracked? || renamed? || deleted?
      end

      def to_symbols : String
        String.build do |builder|
          builder << '+' if staged?
          builder << '!' if modified?
          builder << '?' if untracked?
          builder << '»' if renamed?
          builder << '✘' if deleted?
        end
      end
    end

    # ---------------------------------------------------------------
    # SlotState — per-position render state for status symbols
    # ---------------------------------------------------------------
    enum SlotState
      Loading # Data hasn't arrived → show "·"
      Empty   # Resolved to nothing → show space
      Visible # Resolved with content string
    end

    # ---------------------------------------------------------------
    # StatusSymbols — gate outputs for 7 status positions
    #
    # Gates (independent, resolve as data arrives):
    #   1. Working tree (positions 0-2): staged, modified, untracked
    #   2. Worktree state (position 3): mismatch/prunable/locked/branch
    #   3. Operation state (position 3, priority over worktree)
    #   4. Main state (position 4): ^ ✗ _ – ⊂ ∅ ↕ ↑ ↓
    #   5. Upstream divergence (position 5): | ⇡ ⇣ ⇅
    #   6. User marker (position 6): 2-wide user string
    # ---------------------------------------------------------------
    class StatusSymbols
      property working_tree : WorkingTreeStatus?
      property worktree_state : WorktreeState?
      property operation_state : OperationState?
      property main_state : MainState?
      property upstream_divergence : Divergence?
      property user_marker : String?

      def initialize
        @working_tree = nil
        @worktree_state = nil
        @operation_state = nil
        @main_state = nil
        @upstream_divergence = nil
        @user_marker = nil
      end

      # Fixed width per status position
      POSITION_WIDTHS = [1, 1, 1, 1, 1, 1, 2]

      # Returns 7-tuple of (position_index, symbol_string, color_category).
      # Gates resolve independently; unresolved → "·" placeholder.
      def styled_symbols : Array(Tuple(Int32, String))
        result = [] of Tuple(Int32, String)
        build_working_tree_symbols(result)
        build_operation_state_symbol(result)
        build_main_state_symbol(result)
        build_upstream_symbol(result)
        build_user_marker_symbol(result)
        result
      end

      private def build_working_tree_symbols(result : Array(Tuple(Int32, String)))
        if wt = working_tree
          result << {0, wt.staged? ? "+".colorize.cyan.to_s : " "}
          result << {1, wt.modified? ? "!".colorize.cyan.to_s : " "}
          result << {2, wt.untracked? ? "?".colorize.cyan.to_s : " "}
        else
          result << {0, "·".colorize.dim.to_s}
          result << {1, " "}
          result << {2, " "}
        end
      end

      private def build_operation_state_symbol(result : Array(Tuple(Int32, String)))
        if op = operation_state
          case op
          in .conflicts? then result << {3, "✘".colorize.red.to_s}
          in .rebase?    then result << {3, "⤴".colorize.yellow.to_s}
          in .merge?     then result << {3, "⤵".colorize.yellow.to_s}
          in .none?      then result << {3, " "}
          end
        elsif ws = worktree_state
          case ws
          in .branch_worktree_mismatch? then result << {3, "⚑".colorize.red.to_s}
          in .prunable?                 then result << {3, "⊟".colorize.yellow.to_s}
          in .locked?                   then result << {3, "⊞".colorize.yellow.to_s}
          in .branch?                   then result << {3, "/".colorize.dim.to_s}
          in .none?                     then result << {3, " "}
          end
        else
          result << {3, "·".colorize.dim.to_s}
        end
      end

      private def build_main_state_symbol(result : Array(Tuple(Int32, String)))
        if ms = main_state
          result << {4, (ms.styled || " ")}
        else
          result << {4, "·".colorize.dim.to_s}
        end
      end

      private def build_upstream_symbol(result : Array(Tuple(Int32, String)))
        if ud = upstream_divergence
          result << {5, (ud.styled || " ")}
        else
          result << {5, "·".colorize.dim.to_s}
        end
      end

      private def build_user_marker_symbol(result : Array(Tuple(Int32, String)))
        if marker = user_marker
          result << {6, marker.rjust(2)}
        else
          result << {6, "  "}
        end
      end

      # Render with position mask and placeholder
      def render_with_mask(placeholder : String = "·") : String
        symbols = styled_symbols
        symbols_by_pos = {} of Int32 => String
        symbols.each { |pos, symbol| symbols_by_pos[pos] = symbol }

        String.build do |io|
          7.times do |idx|
            if sym = symbols_by_pos[idx]?
              io << sym
            else
              io << placeholder_for_position(idx, placeholder)
            end
          end
        end
      end

      private def placeholder_for_position(idx : Int32, placeholder : String) : String
        if idx < 3 && working_tree.nil?
          placeholder.colorize.dim.to_s
        elsif idx == 3 && operation_state.nil? && worktree_state.nil?
          placeholder.colorize.dim.to_s
        elsif idx == 4 && main_state.nil?
          placeholder.colorize.dim.to_s
        elsif idx == 5 && upstream_divergence.nil?
          placeholder.colorize.dim.to_s
        else
          " " * POSITION_WIDTHS[idx]
        end
      end

      # Compact format for statusline (no padding, only visible slots)
      def format_compact : String
        styled_symbols
          .reject { |_pos, symbol| symbol.strip.empty? }
          .map { |_pos, symbol| symbol }
          .join
      end
    end

    # ---------------------------------------------------------------
    # StatuslineSegment — segment for shell prompt integration
    # ---------------------------------------------------------------
    struct StatuslineSegment
      property content : String
      property priority : Int32

      def initialize(@content : String, @priority : Int32)
      end

      # Visible width (strips ANSI escape codes)
      def width : Int32
        content.gsub(/\e\[[\d;]*m/, "").size
      end

      # Join segments with 2-space separators
      def self.join(segments : Array(StatuslineSegment)) : String
        segments.map(&.content).join("  ")
      end

      # Total width of joined segments including separators
      def self.total_width(segments : Array(StatuslineSegment)) : Int32
        return 0 if segments.empty?
        segments.sum(&.width) + (segments.size - 1) * 2
      end

      # Truncate segments to fit within max_width by dropping lowest-priority.
      # Priority: lower number = more important (like upstream).
      # Never drops below 1 segment.
      def self.fit_to_width(segments : Array(StatuslineSegment), max_width : Int32) : Array(StatuslineSegment)
        return segments if segments.empty?
        working = segments.dup

        while working.size > 1 && total_width(working) > max_width
          # Find lowest priority (highest priority number) segment, breaking ties with later position
          worst_idx = 0
          worst_priority = working[0].priority
          (1...working.size).each do |i|
            if working[i].priority >= worst_priority
              worst_idx = i
              worst_priority = working[i].priority
            end
          end
          working.delete_at(worst_idx)
        end

        working
      end
    end
  end
end
