require "../../spec_helper"

describe WorkTrees::Git::BranchDeletionMode do
  it "has Keep variant" do
    WorkTrees::Git::BranchDeletionMode::Keep.should_not be_nil
  end

  it "has SafeDelete variant" do
    WorkTrees::Git::BranchDeletionMode::SafeDelete.should_not be_nil
  end

  it "has ForceDelete variant" do
    WorkTrees::Git::BranchDeletionMode::ForceDelete.should_not be_nil
  end
end

describe WorkTrees::Git::Repository do
  describe "#remove_worktree" do
    it "is defined" do
      repo = WorkTrees::Git::Repository.current
      repo.responds_to?(:remove_worktree).should be_true
    end
  end

  describe "#delete_branch" do
    it "is defined" do
      repo = WorkTrees::Git::Repository.current
      repo.responds_to?(:delete_branch).should be_true
    end
  end
end
