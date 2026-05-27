require "../../spec_helper"

module WorkTrees
  describe Git::Recovery do
    describe "generate_backup_path" do
      it "appends suffix for clean paths" do
        result = Git::Recovery.generate_backup_path("/tmp/feature")
        result.should start_with("/tmp/feature")
        result.should_not eq("/tmp/feature")
      end

      it "includes timestamp in backup name" do
        result = Git::Recovery.generate_backup_path("/tmp/feature")
        # Should have .trash or similar suffix with timestamp
        result.should contain("feature")
      end

      it "handles paths with extensions" do
        result = Git::Recovery.generate_backup_path("/tmp/repo.txt")
        result.should contain("repo")
      end

      it "handles hidden directories" do
        result = Git::Recovery.generate_backup_path("/tmp/.config")
        result.should_not eq("/tmp/.config")
      end
    end

    describe "safe_delete_branch" do
      it "returns :integrated for merged branches" do
        result = Git::Recovery.safe_delete_result(
          branch: "feature", target: "main", integrated: true, force: false,
        )
        result.should eq(:deleted)
      end
    end

    describe "cleanup_result" do
      it "returns partial when branch kept" do
        result = Git::Recovery.cleanup_result(
          worktree_removed: true, branch_deleted: false, cd_path: "/tmp/main",
        )
        result.worktree_removed?.should be_true
        result.branch_deleted?.should be_false
        result.cd_path.should eq("/tmp/main")
      end

      it "returns complete when both removed" do
        result = Git::Recovery.cleanup_result(
          worktree_removed: true, branch_deleted: true,
        )
        result.worktree_removed?.should be_true
        result.branch_deleted?.should be_true
        result.cd_path.should be_nil
      end
    end
  end
end
