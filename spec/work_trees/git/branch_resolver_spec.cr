require "../../spec_helper"

describe WorkTrees::Git::BranchResolver do
  describe ".resolve" do
    it "returns the branch name unchanged for normal branches" do
      result = WorkTrees::Git::BranchResolver.resolve("feature-auth")
      result.should eq("feature-auth")
    end

    it "passes through branch names with slashes" do
      result = WorkTrees::Git::BranchResolver.resolve("feat/nested/branch")
      result.should eq("feat/nested/branch")
    end

    it "passes through branch names with dots" do
      result = WorkTrees::Git::BranchResolver.resolve("v1.2.3-hotfix")
      result.should eq("v1.2.3-hotfix")
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
      current = WorkTrees::Git::BranchResolver.resolve("@")
      WorkTrees::Git::BranchResolver.save_previous(current)
      WorkTrees::Git::BranchResolver.save_previous("some-other")
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
      result.should_not be_empty
    end
  end

  describe "shortcut constants" do
    it "defines ^ as default branch shortcut" do
      WorkTrees::Git::BranchResolver::SHORTCUT_DEFAULT.should eq("^")
    end

    it "defines @ as current branch shortcut" do
      WorkTrees::Git::BranchResolver::SHORTCUT_CURRENT.should eq("@")
    end

    it "defines - as previous branch shortcut" do
      WorkTrees::Git::BranchResolver::SHORTCUT_PREVIOUS.should eq("-")
    end

    it "defines pr: prefix" do
      WorkTrees::Git::BranchResolver::PR_PREFIX.should eq("pr:")
    end

    it "defines mr: prefix" do
      WorkTrees::Git::BranchResolver::MR_PREFIX.should eq("mr:")
    end
  end
end
