require "../../spec_helper"
require "bubbles"

module WorkTrees
  describe Picker::PickerItem do
    it "composes filter_value from branch and path" do
      item = Picker::PickerItem.new(
        branch: "feature/fix-login",
        worktree_path: "/home/user/worktrees/feature",
      )
      item.filter_value.should contain("feature/fix-login")
      item.filter_value.should contain("/home/user/worktrees/feature")
    end

    it "returns branch as title" do
      item = Picker::PickerItem.new(branch: "main")
      item.title.should eq("main")
    end

    it "returns path as description" do
      item = Picker::PickerItem.new(
        branch: "feature",
        worktree_path: "/home/user/worktrees/feat",
      )
      item.description.should contain("/home/user/worktrees/feat")
    end

    it "includes current marker in description when current" do
      item = Picker::PickerItem.new(
        branch: "main",
        worktree_path: "/repo",
        is_current: true,
      )
      item.description.should contain("@")
    end

    it "includes status symbols in description" do
      item = Picker::PickerItem.new(
        branch: "feature",
        worktree_path: "/wt/feat",
        status_symbols: "↑3 ↓1",
      )
      item.description.should contain("↑3")
      item.description.should contain("↓1")
    end

    it "includes Bubbles::List::Item interface" do
      item = Picker::PickerItem.new(branch: "test")
      item.should be_a(Bubbles::List::Item)
    end
  end

  describe Picker::PreviewMode do
    it "has 5 variants matching vendor" do
      Picker::PreviewMode::WorkingTree.value.should eq(1)
      Picker::PreviewMode::Log.value.should eq(2)
      Picker::PreviewMode::BranchDiff.value.should eq(3)
      Picker::PreviewMode::UpstreamDiff.value.should eq(4)
      Picker::PreviewMode::Summary.value.should eq(5)
    end
  end

  describe Picker do
    describe "build_items" do
      it "converts worktree info to PickerItems" do
        worktrees = [
          Git::WorktreeInfo.new("/repo", "abc", "main"),
          Git::WorktreeInfo.new("/wt/feat", "def", "feature/fix"),
        ]
        items = Picker.build_items(worktrees)
        items.size.should eq(2)
        items[0].branch.should eq("main")
        items[1].branch.should eq("feature/fix")
      end
    end
  end

  describe Picker::Model do
    it "initializes with items in list" do
      items = [
        Picker::PickerItem.new(branch: "main", worktree_path: "/repo"),
        Picker::PickerItem.new(branch: "feature/x", worktree_path: "/wt/feat"),
      ]
      model = Picker::Model.new(items, terminal_width: 80, terminal_height: 24)
      model.item_count.should eq(2)
    end

    it "defaults preview mode to WorkingTree" do
      model = Picker::Model.new(
        [Picker::PickerItem.new(branch: "main")],
        terminal_width: 80, terminal_height: 24,
      )
      model.preview_mode.should eq(Picker::PreviewMode::WorkingTree)
    end

    it "has a list that is not nil" do
      model = Picker::Model.new(
        [Picker::PickerItem.new(branch: "main")],
        terminal_width: 80, terminal_height: 24,
      )
      model.list.should_not be_nil
    end

    it "has a viewport that is not nil" do
      model = Picker::Model.new(
        [Picker::PickerItem.new(branch: "main")],
        terminal_width: 80, terminal_height: 24,
      )
      model.viewport.should_not be_nil
    end
  end
end
