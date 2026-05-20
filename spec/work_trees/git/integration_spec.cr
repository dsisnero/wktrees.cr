require "../../spec_helper"

describe WorkTrees::Git::Integration do
  describe ".check" do
    it "detects same commit (trivially integrated)" do
      repo = WorkTrees::Git::Repository.current
      branch = repo.current_worktree.current_branch
      # A branch is always integrated into itself
      result = WorkTrees::Git::Integration.check(repo, branch, branch)
      result.should be_true
    end

    it "detects ancestor relationship" do
      repo = WorkTrees::Git::Repository.current
      default = repo.default_branch
      # Default branch is ancestor of any branch created from it
      result = WorkTrees::Git::Integration.check(repo, default, default)
      result.should be_true
    end

    it "returns false for divergent branches" do
      repo = WorkTrees::Git::Repository.current
      # A non-existent branch cannot be integrated
      result = WorkTrees::Git::Integration.check(repo, "nonexistent-branch-xyz", "main")
      result.should be_false
    end

    it "provides reason for integration" do
      repo = WorkTrees::Git::Repository.current
      branch = repo.current_worktree.current_branch
      reason = WorkTrees::Git::Integration.reason(repo, branch, branch)
      reason.should_not be_nil
      reason.to_s.should_not be_empty
    end
  end
end
