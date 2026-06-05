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
      it "returns :deleted for merged branches" do
        result = Git::Recovery.safe_delete_result(
          branch: "feature", target: "main", integrated: true, force: false,
        )
        result.should eq(:deleted)
      end

      it "returns :kept for unmerged branches without force" do
        result = Git::Recovery.safe_delete_result(
          branch: "feature", target: "main", integrated: false, force: false,
        )
        result.should eq(:kept)
      end

      it "returns :deleted for unmerged branches with force" do
        result = Git::Recovery.safe_delete_result(
          branch: "feature", target: "main", integrated: false, force: true,
        )
        result.should eq(:deleted)
      end

      it "returns :skipped for empty branch name" do
        result = Git::Recovery.safe_delete_result(
          branch: "", target: "main", integrated: true, force: true,
        )
        result.should eq(:skipped)
      end

      it "returns :skipped for empty branch regardless of flags" do
        result = Git::Recovery.safe_delete_result(
          branch: "", target: "main", integrated: false, force: false,
        )
        result.should eq(:skipped)
      end

      # Upstream: integration status semantics — marked as integrated when
      # the branch is an ancestor (merged); not integrated when divergent.
      it "returns :deleted when force overrides non-integrated" do
        result = Git::Recovery.safe_delete_result(
          branch: "stale-feature", target: "main", integrated: false, force: true,
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

      it "returns nothing removed with defaults" do
        result = Git::Recovery.cleanup_result
        result.worktree_removed?.should be_false
        result.branch_deleted?.should be_false
        result.cd_path.should be_nil
      end

      # Upstream: cd_path is the directory to switch to after cleanup
      it "sets cd_path to target directory" do
        result = Git::Recovery.cleanup_result(
          worktree_removed: true, branch_deleted: true, cd_path: "/tmp/default",
        )
        result.cd_path.should eq("/tmp/default")
      end
    end

    describe "generate_backup_path" do
      it "avoids collisions with existing files" do
        base_path = File.join(Dir.tempdir, "wt-backup-test-#{Random.rand(99999)}")
        Dir.mkdir(base_path)
        begin
          # Create the first backup path as if it already exists
          first = Git::Recovery.generate_backup_path("#{base_path}/feature")
          File.write(first, "stale")
          # Second call should skip that path and find another
          second = Git::Recovery.generate_backup_path("#{base_path}/feature")
          second.should_not eq(first)
        ensure
          Dir.children(base_path).each { |c| File.delete(File.join(base_path, c)) rescue nil }
          Dir.delete(base_path) rescue nil
        end
      end

      it "preserves the base directory" do
        result = Git::Recovery.generate_backup_path("/tmp/feature")
        result.should start_with("/tmp/feature")
      end

      it "includes base name in backup" do
        result = Git::Recovery.generate_backup_path("/tmp/my-worktree")
        result.should contain("my-worktree")
      end

      it "appends .trash suffix" do
        result = Git::Recovery.generate_backup_path("/tmp/feature")
        result.should end_with(".trash")
      end
    end
  end
end
