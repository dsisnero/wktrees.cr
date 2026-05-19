require "../../spec_helper"

describe WorkTrees::Git::BranchResolver do
  describe ".resolve" do
    it "returns the branch name unchanged for normal branches" do
      result = WorkTrees::Git::BranchResolver.resolve("feature-auth")
      result.should eq("feature-auth")
    end

    it "resolves ^ to default branch" do
      result = WorkTrees::Git::BranchResolver.resolve("^")
      result.should_not be_empty
      result.should_not eq("^")
    end

    it "resolves @ to current branch" do
      result = WorkTrees::Git::BranchResolver.resolve("@")
      result.should_not eq("@")
      result.should_not be_empty
    end

    it "saves and resolves - as previous branch" do
      # Save current branch as previous
      current = WorkTrees::Git::BranchResolver.resolve("@")
      WorkTrees::Git::BranchResolver.save_previous(current)

      # Switch to another branch (just save it)
      WorkTrees::Git::BranchResolver.save_previous("some-other")

      # Now - should resolve to the first saved branch
      result = WorkTrees::Git::BranchResolver.resolve("-")
      result.should_not be_empty
      result.should_not eq("-")
    end

    it "parses pr:N syntax" do
      result = WorkTrees::Git::BranchResolver.resolve("pr:42")
      result.should eq("pr:42") # actual PR resolution deferred
    end

    it "parses mr:N syntax (falls back if glab not available)" do
      result = WorkTrees::Git::BranchResolver.resolve("mr:7")
      # Should return either resolved branch or "mr:7" as fallback
      result.should_not be_empty
    end
  end
end
