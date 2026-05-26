require "../../spec_helper"

module WorkTrees
  describe List do
    describe "ListItem" do
      it "stores branch name and worktree path" do
        item = List::ListItem.new(
          branch: "feature/my-branch",
          worktree_path: "/home/user/worktrees/feature",
          head_sha: "abc123def",
          current: true,
        )
        item.branch.should eq("feature/my-branch")
        item.worktree_path.should eq("/home/user/worktrees/feature")
        item.head_sha.should eq("abc123def")
        item.current?.should be_true
      end

      it "is not current by default" do
        item = List::ListItem.new(branch: "feature", worktree_path: "/tmp/feat")
        item.current?.should be_false
      end

      it "returns nil worktree_path for branch-only items" do
        item = List::ListItem.new(branch: "remote-only")
        item.worktree_path.should be_nil
        item.head_sha.should eq("")
      end

      it "supports display_name for remote branches" do
        item = List::ListItem.new(branch: "origin/feature")
        item.display_name.should eq("origin/feature")
      end
    end

    describe "DisplayFields" do
      it "defaults all fields to nil" do
        fields = List::DisplayFields.new
        fields.ci_status.should be_nil
        fields.working_diff.should be_nil
        fields.upstream_status.should be_nil
        fields.summary.should be_nil
      end

      it "can be populated with display values" do
        fields = List::DisplayFields.new(
          ci_status: "✓",
          working_diff: "+3 -1",
          upstream_status: "↑2",
          summary: "fix: login bug",
        )
        fields.ci_status.should eq("✓")
        fields.working_diff.should eq("+3 -1")
        fields.upstream_status.should eq("↑2")
        fields.summary.should eq("fix: login bug")
      end
    end

    describe "ListData" do
      it "wraps item and display fields" do
        item = List::ListItem.new(branch: "main", worktree_path: "/home/main")
        fields = List::DisplayFields.new(ci_status: "✓")
        data = List::ListData.new(item, fields, ahead: 1, behind: 0)
        data.item.branch.should eq("main")
        data.fields.ci_status.should eq("✓")
        data.ahead.should eq(1)
        data.behind.should eq(0)
      end
    end
  end
end
