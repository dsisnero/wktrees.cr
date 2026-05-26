require "../../spec_helper"
require "../../../src/work_trees/list/model"

module WorkTrees::List
  describe Divergence do
    describe ".from_counts_with_remote" do
      it "returns InSync for 0/0" do
        Divergence.from_counts_with_remote(0, 0).should eq(Divergence::InSync)
      end

      it "returns Ahead when ahead only" do
        Divergence.from_counts_with_remote(5, 0).should eq(Divergence::Ahead)
      end

      it "returns Behind when behind only" do
        Divergence.from_counts_with_remote(0, 3).should eq(Divergence::Behind)
      end

      it "returns Diverged when both ahead and behind" do
        Divergence.from_counts_with_remote(5, 3).should eq(Divergence::Diverged)
      end
    end

    describe "#symbol" do
      it "returns empty for None" do
        Divergence::None.symbol.should eq("")
      end

      it "returns pipe for InSync" do
        Divergence::InSync.symbol.should eq("|")
      end

      it "returns up arrow for Ahead" do
        Divergence::Ahead.symbol.should eq("⇡")
      end

      it "returns down arrow for Behind" do
        Divergence::Behind.symbol.should eq("⇣")
      end

      it "returns up-down for Diverged" do
        Divergence::Diverged.symbol.should eq("⇅")
      end
    end

    describe "#styled" do
      it "returns nil for None" do
        Divergence::None.styled.should be_nil
      end

      it "returns dimmed symbol for InSync" do
        Divergence::InSync.styled.should_not be_nil
      end

      it "returns dimmed symbol for Ahead" do
        Divergence::Ahead.styled.should_not be_nil
      end

      it "returns dimmed symbol for Behind" do
        Divergence::Behind.styled.should_not be_nil
      end

      it "returns dimmed symbol for Diverged" do
        Divergence::Diverged.styled.should_not be_nil
      end
    end
  end

  describe MainState do
    describe "#display" do
      it "returns empty for None" do
        MainState::None.display.should eq("")
      end

      it "returns ^ for IsMain" do
        MainState::IsMain.display.should eq("^")
      end

      it "returns ✗ for WouldConflict" do
        MainState::WouldConflict.display.should eq("✗")
      end

      it "returns _ for Empty" do
        MainState::Empty.display.should eq("_")
      end

      it "returns en-dash for SameCommit" do
        MainState::SameCommit.display.should eq("–")
      end

      it "returns subset for Integrated" do
        MainState::Integrated.display.should eq("⊂")
      end

      it "returns empty set for Orphan" do
        MainState::Orphan.display.should eq("∅")
      end

      it "returns up-down for Diverged" do
        MainState::Diverged.display.should eq("↕")
      end

      it "returns up arrow for Ahead" do
        MainState::Ahead.display.should eq("↑")
      end

      it "returns down arrow for Behind" do
        MainState::Behind.display.should eq("↓")
      end
    end

    describe "#styled" do
      it "returns nil for None" do
        MainState::None.styled.should be_nil
      end

      it "returns yellow for WouldConflict" do
        MainState::WouldConflict.styled.should_not be_nil
      end

      it "returns dimmed for IsMain" do
        MainState::IsMain.styled.should_not be_nil
      end

      it "returns dimmed for Ahead" do
        MainState::Ahead.styled.should_not be_nil
      end

      it "returns dimmed for Orphan" do
        MainState::Orphan.styled.should_not be_nil
      end
    end

    describe "#as_json_str" do
      it "returns nil for None" do
        MainState::None.as_json_str.should be_nil
      end

      it "returns display for non-None" do
        MainState::IsMain.as_json_str.should eq("^")
        MainState::Diverged.as_json_str.should eq("↕")
      end
    end

    describe "#integration_reason" do
      it "returns nil for non-Integrated states" do
        MainState::None.integration_reason.should be_nil
        MainState::IsMain.integration_reason.should be_nil
        MainState::WouldConflict.integration_reason.should be_nil
        MainState::Empty.integration_reason.should be_nil
        MainState::SameCommit.integration_reason.should be_nil
        MainState::Diverged.integration_reason.should be_nil
        MainState::Ahead.integration_reason.should be_nil
        MainState::Behind.integration_reason.should be_nil
      end
    end

    describe ".from_integration_and_counts" do
      it "prioritizes IsMain over everything" do
        result = MainState.from_integration_and_counts(true, true, nil, false, true, 5, 3)
        result.should eq(MainState::IsMain)
      end

      it "prioritizes Orphan over WouldConflict" do
        result = MainState.from_integration_and_counts(false, true, nil, false, true, 0, 0)
        result.should eq(MainState::Orphan)
      end

      it "returns WouldConflict when not orphan" do
        result = MainState.from_integration_and_counts(false, true, nil, false, false, 5, 3)
        result.should eq(MainState::WouldConflict)
      end

      it "returns Empty from integration state" do
        result = MainState.from_integration_and_counts(false, false, MainState::Empty, false, false, 0, 0)
        result.should eq(MainState::Empty)
      end

      it "returns SameCommit via dirty flag" do
        result = MainState.from_integration_and_counts(false, false, nil, true, false, 0, 0)
        result.should eq(MainState::SameCommit)
      end

      it "returns Diverged when both ahead and behind" do
        result = MainState.from_integration_and_counts(false, false, nil, false, false, 3, 2)
        result.should eq(MainState::Diverged)
      end

      it "returns Ahead only" do
        result = MainState.from_integration_and_counts(false, false, nil, false, false, 3, 0)
        result.should eq(MainState::Ahead)
      end

      it "returns Behind only" do
        result = MainState.from_integration_and_counts(false, false, nil, false, false, 0, 2)
        result.should eq(MainState::Behind)
      end

      it "returns None when in sync" do
        result = MainState.from_integration_and_counts(false, false, nil, false, false, 0, 0)
        result.should eq(MainState::None)
      end
    end
  end

  describe WorktreeState do
    describe "#display" do
      it "returns empty for None" do
        WorktreeState::None.display.should eq("")
      end

      it "returns flag for mismatch" do
        WorktreeState::BranchWorktreeMismatch.display.should eq("⚑")
      end

      it "returns box for prunable" do
        WorktreeState::Prunable.display.should eq("⊟")
      end

      it "returns plus-box for locked" do
        WorktreeState::Locked.display.should eq("⊞")
      end

      it "returns slash for branch-only" do
        WorktreeState::Branch.display.should eq("/")
      end
    end
  end

  describe OperationState do
    describe "#display" do
      it "returns empty for None" do
        OperationState::None.display.should eq("")
      end

      it "returns heavy X for Conflicts" do
        OperationState::Conflicts.display.should eq("✘")
      end

      it "returns up-arrow for Rebase" do
        OperationState::Rebase.display.should eq("⤴")
      end

      it "returns down-arrow for Merge" do
        OperationState::Merge.display.should eq("⤵")
      end
    end

    describe "#styled" do
      it "returns nil for None" do
        OperationState::None.styled.should be_nil
      end

      it "returns red for Conflicts" do
        OperationState::Conflicts.styled.should_not be_nil
      end

      it "returns yellow for Rebase" do
        OperationState::Rebase.styled.should_not be_nil
      end

      it "returns yellow for Merge" do
        OperationState::Merge.styled.should_not be_nil
      end
    end
  end

  describe ActiveGitOperation do
    describe "#none?" do
      it "is true for None" do
        ActiveGitOperation::None.none?.should be_true
      end

      it "is false for Rebase" do
        ActiveGitOperation::Rebase.none?.should be_false
      end

      it "is false for Merge" do
        ActiveGitOperation::Merge.none?.should be_false
      end
    end
  end

  describe "Tier functions" do
    describe "tier_is_main" do
      it "fires for true" do
        tier, state = List.tier_is_main(true)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::IsMain)
      end

      it "rules out for false" do
        tier, state = List.tier_is_main(false)
        tier.should eq(Tier::RuledOut)
        state.should be_nil
      end
    end

    describe "tier_orphan" do
      it "fires for Some(true)" do
        tier, state = List.tier_orphan(true)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::Orphan)
      end

      it "rules out for Some(false)" do
        tier, state = List.tier_orphan(false)
        tier.should eq(Tier::RuledOut)
        state.should be_nil
      end

      it "waits for nil" do
        tier, state = List.tier_orphan(nil)
        tier.should eq(Tier::Wait)
        state.should be_nil
      end
    end

    describe "tier_would_conflict" do
      it "fires on HEAD conflict even without WT probe" do
        tier, state = List.tier_would_conflict(true, WorkingTreeConflictProbe::NotRun)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::WouldConflict)
      end

      it "fires on dirty-tree conflict without HEAD probe" do
        tier, state = List.tier_would_conflict(nil, WorkingTreeConflictProbe::Conflicts)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::WouldConflict)
      end

      it "rules out when both probes say no conflict" do
        tier, state = List.tier_would_conflict(false, WorkingTreeConflictProbe::Clean)
        tier.should eq(Tier::RuledOut)
        state.should be_nil
      end

      it "rules out on dirty-tree no-conflict regardless of HEAD" do
        tier, state = List.tier_would_conflict(false, WorkingTreeConflictProbe::NoConflicts)
        tier.should eq(Tier::RuledOut)
        state.should be_nil
      end

      it "rules out when WT says no-conflict even if HEAD says yes" do
        tier, state = List.tier_would_conflict(true, WorkingTreeConflictProbe::NoConflicts)
        tier.should eq(Tier::RuledOut)
        state.should be_nil
      end

      it "waits when neither probe has reported" do
        tier, state = List.tier_would_conflict(nil, WorkingTreeConflictProbe::NotRun)
        tier.should eq(Tier::Wait)
        state.should be_nil
      end

      it "waits when HEAD says no conflict but WT not run" do
        tier, state = List.tier_would_conflict(false, WorkingTreeConflictProbe::NotRun)
        tier.should eq(Tier::Wait)
        state.should be_nil
      end
    end

    describe "tier_integration_or_counts" do
      it "waits when counts missing" do
        tier, _ = List.tier_integration_or_counts(nil, true, nil)
        tier.should eq(Tier::Wait)
      end

      it "waits when is_clean missing" do
        counts = AheadBehind.new(ahead: 0, behind: 0)
        tier, _ = List.tier_integration_or_counts(counts, nil, nil)
        tier.should eq(Tier::Wait)
      end

      it "fires None for in-sync clean" do
        counts = AheadBehind.new(ahead: 0, behind: 0)
        tier, state = List.tier_integration_or_counts(counts, true, nil)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::None)
      end

      it "fires SameCommit for in-sync dirty" do
        counts = AheadBehind.new(ahead: 0, behind: 0)
        tier, state = List.tier_integration_or_counts(counts, false, nil)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::SameCommit)
      end

      it "fires Ahead" do
        counts = AheadBehind.new(ahead: 3, behind: 0)
        tier, state = List.tier_integration_or_counts(counts, true, nil)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::Ahead)
      end

      it "fires Diverged" do
        counts = AheadBehind.new(ahead: 3, behind: 2)
        tier, state = List.tier_integration_or_counts(counts, true, nil)
        tier.should eq(Tier::Fired)
        state.should eq(MainState::Diverged)
      end
    end
  end

  describe WorkingTreeStatus do
    it "is clean by default" do
      ws = WorkingTreeStatus.new
      ws.dirty?.should be_false
    end

    it "is dirty when staged" do
      WorkingTreeStatus.new(staged: true).dirty?.should be_true
    end

    it "is dirty when modified" do
      WorkingTreeStatus.new(modified: true).dirty?.should be_true
    end

    it "is dirty when untracked" do
      WorkingTreeStatus.new(untracked: true).dirty?.should be_true
    end

    it "generates symbols for all flags" do
      ws = WorkingTreeStatus.new(staged: true, modified: true, untracked: true, renamed: true, deleted: true)
      ws.to_symbols.should eq("+!?»✘")
    end

    it "generates empty symbols when clean" do
      WorkingTreeStatus.new.to_symbols.should eq("")
    end
  end

  describe UpstreamStatus do
    it "is inactive without remote" do
      UpstreamStatus.new.active?.should be_false
    end

    it "is active with remote" do
      UpstreamStatus.new(remote: "origin").active?.should be_true
    end
  end

  describe StatusSymbols do
    it "starts with all nil" do
      ss = StatusSymbols.new
      ss.working_tree.should be_nil
      ss.main_state.should be_nil
    end

    it "render_with_mask shows placeholders when unloaded" do
      ss = StatusSymbols.new
      output = ss.render_with_mask
      output.should contain("·")
    end

    it "render_with_mask shows symbols when loaded, placeholder for unloaded gates" do
      ss = StatusSymbols.new
      ss.working_tree = WorkingTreeStatus.new(staged: true)
      ss.main_state = MainState::Ahead
      ss.upstream_divergence = Divergence::InSync
      ss.operation_state = OperationState::None
      output = ss.render_with_mask
      output.should_not contain("·")
    end

    it "format_compact shows only visible symbols" do
      ss = StatusSymbols.new
      ss.working_tree = WorkingTreeStatus.new(staged: true)
      ss.main_state = MainState::Ahead
      output = ss.format_compact
      output.strip.should_not eq("")
    end
  end

  describe StatuslineSegment do
    it "computes visible width stripping ANSI" do
      seg = StatuslineSegment.new("hello", 1)
      seg.width.should eq(5)
    end

    it "joins with 2-space separators" do
      segs = [
        StatuslineSegment.new("a", 1),
        StatuslineSegment.new("b", 2),
      ]
      StatuslineSegment.join(segs).should eq("a  b")
    end

    it "computes total width" do
      segs = [
        StatuslineSegment.new("abc", 1),
        StatuslineSegment.new("de", 2),
      ]
      StatuslineSegment.total_width(segs).should eq(7) # 3 + 2 + 2 separator
    end

    it "total_width is 0 for empty" do
      StatuslineSegment.total_width([] of StatuslineSegment).should eq(0)
    end

    it "fit_to_width drops lowest priority segment" do
      segs = [
        StatuslineSegment.new("aaa", 1),  # high priority
        StatuslineSegment.new("bb", 2),   # medium
        StatuslineSegment.new("cccc", 3), # low priority
      ]
      # total = 3 + 2 + 4 + 2*2 = 13
      # fit to 11: drop priority 3 segment -> 3 + 2 + 2 = 7, fits
      result = StatuslineSegment.fit_to_width(segs, 11)
      result.size.should eq(2)
    end

    it "fit_to_width drops later segments on tie" do
      segs = [
        StatuslineSegment.new("aa", 1),
        StatuslineSegment.new("bb", 1), # same priority
      ]
      result = StatuslineSegment.fit_to_width(segs, 3)
      result.size.should eq(1)
      result[0].content.should eq("aa")
    end

    it "fit_to_width never drops below 1 segment" do
      segs = [
        StatuslineSegment.new("aaa", 1),
        StatuslineSegment.new("bbb", 2),
      ]
      result = StatuslineSegment.fit_to_width(segs, 1)
      result.size.should eq(1)
    end
  end
end
