require "../../spec_helper"

module WorkTrees
  describe List do
    describe "ListItem" do
      it "stores branch name and worktree path" do
        item = List::ListItem.new(
          branch: "feature/my-branch",
          worktree_path: "/home/user/worktrees/feature",
          head: "abc123def",
        )
        item.branch.should eq("feature/my-branch")
        item.worktree_path.should eq("/home/user/worktrees/feature")
        item.head.should eq("abc123def")
      end

      it "is not current by default" do
        item = List::ListItem.new(branch: "feature", worktree_path: "/tmp/feat")
        item.current?.should be_false
      end

      it "returns nil worktree_path for branch-only items" do
        item = List::ListItem.new(branch: "remote-only")
        item.worktree_path.should be_nil
        item.head.should eq("")
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
      it "wraps item fields and counts" do
        data = List::ListData.new(
          branch: "main", worktree_path: "/home/main",
          ci_status: "✓", ahead: 1, behind: 0,
        )
        data.branch.should eq("main")
        data.ci_status.should eq("✓")
        data.ahead.should eq(1)
        data.behind.should eq(0)
      end
    end

    describe "JSON serialization" do
      it "ListItem serializes to JSON" do
        item = List::ListItem.new(
          branch: "feature/fix",
          worktree_path: "/home/wt/feature",
          head: "abc1234",
          current: true,
        )
        json = item.to_json
        json.should contain("feature/fix")
        json.should contain("abc1234")
        json.should contain("worktree_path")
      end

      it "ListData serializes to JSON" do
        data = List::ListData.new(
          branch: "main", ci_status: "✓", summary: "fix: bug",
          ahead: 3, behind: 1,
        )
        json = data.to_json
        json.should contain("main")
        json.should contain("ci_status")
        json.should contain("summary")
        json.should contain("ahead")
        json.should contain("behind")
      end

      it "DisplayFields skips nil values in JSON" do
        fields = List::DisplayFields.new(ci_status: "✓")
        json = fields.to_json
        json.should contain("ci_status")
        json.should_not contain("working_diff")
      end
    end

    describe "statusline" do
      it "formats branch with ahead/behind indicators" do
        data = List::ListData.new(
          branch: "feature/fix", ahead: 3, behind: 1,
        )
        line = data.statusline
        line.should contain("feature/fix")
        line.should contain("↑")
        line.should contain("↓")
      end

      it "formats clean branch without indicators" do
        data = List::ListData.new(branch: "main")
        line = data.statusline
        line.should contain("main")
      end

      it "includes working diff when present" do
        data = List::ListData.new(
          branch: "feature", working_diff: "+5 -2",
        )
        line = data.statusline
        line.should contain("+5")
      end

      it "includes CI status when present" do
        data = List::ListData.new(
          branch: "feature", ci_status: "✓",
        )
        line = data.statusline
        line.should contain("✓")
      end

      it "includes summary when present" do
        data = List::ListData.new(
          branch: "feature", summary: "fix: login bug",
        )
        line = data.statusline
        line.should contain("fix: login bug")
      end
    end
  end
end
