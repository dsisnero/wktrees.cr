require "../../spec_helper"

describe WorkTrees::Template do
  describe ".base_vars" do
    it "includes active, repo, and exec vars" do
      vars = WorkTrees::Template.base_vars
      vars.should contain("branch")
      vars.should contain("repo")
      vars.should contain("cwd")
    end
  end

  describe "HookType" do
    it "has display names" do
      WorkTrees::Template::HookType::PreSwitch.display_name.should eq("pre-switch")
      WorkTrees::Template::HookType::PostMerge.display_name.should eq("post-merge")
    end

    it "provides extra vars for switch hooks" do
      extras = WorkTrees::Template::HookType::PreSwitch.extra_vars
      extras.should contain("base")
      extras.should contain("target")
      extras.should contain("pr_number")
    end

    it "provides extra vars for commit hooks" do
      extras = WorkTrees::Template::HookType::PreCommit.extra_vars
      extras.should eq(%w[target])
    end

    it "provides extra vars for merge hooks" do
      extras = WorkTrees::Template::HookType::PostMerge.extra_vars
      extras.should eq(%w[target target_worktree_path])
    end
  end

  describe ".vars_available_in" do
    it "returns base vars plus operation vars for hook scope" do
      vars = WorkTrees::Template.vars_available_in(:hook, WorkTrees::Template::HookType::PreMerge)
      vars.should contain("branch")
      vars.should contain("hook_type")
      vars.should contain("target")
    end

    it "returns alias-prefixed vars for alias scope" do
      vars = WorkTrees::Template.vars_available_in(:alias)
      vars.should contain("args")
    end

    it "includes deprecated aliases" do
      vars = WorkTrees::Template.vars_available_in(:switch_execute)
      vars.should contain("main_worktree")
      vars.should contain("repo_root")
    end
  end
end
