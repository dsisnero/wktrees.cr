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

    it "has 10 hook type variants" do
      WorkTrees::Template::HookType.values.size.should eq(10)
    end

    it "each variant has a display_name" do
      WorkTrees::Template::HookType.values.each do |ht|
        ht.display_name.should_not be_empty
        ht.display_name.should contain("-") # all use kebab-case
      end
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

    it "provides extra vars for remove hooks" do
      extras = WorkTrees::Template::HookType::PreRemove.extra_vars
      extras.should contain("target")
      extras.should contain("target_worktree_path")
    end

    it "start hooks have same extras as switch hooks" do
      WorkTrees::Template::HookType::PreStart.extra_vars.should eq(
        WorkTrees::Template::HookType::PreSwitch.extra_vars
      )
      WorkTrees::Template::HookType::PostStart.extra_vars.should eq(
        WorkTrees::Template::HookType::PostSwitch.extra_vars
      )
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

    it "each deprecated var maps to a valid target" do
      WorkTrees::Template::DEPRECATED_TEMPLATE_VARS.each do |deprecated, target|
        all_vars = WorkTrees::Template.base_vars
        all_vars.should contain(target), "Deprecated var '#{deprecated}' maps to missing target '#{target}'"
      end
    end
  end

  describe "ValidationScope" do
    it "has three scope variants" do
      WorkTrees::Template::ValidationScope.values.size.should eq(3)
    end

    it "includes Hook, SwitchExecute, and Alias" do
      scope = WorkTrees::Template::ValidationScope::Hook
      scope.should be_a(WorkTrees::Template::ValidationScope)
      WorkTrees::Template::ValidationScope::SwitchExecute.should be_a(WorkTrees::Template::ValidationScope)
      WorkTrees::Template::ValidationScope::Alias.should be_a(WorkTrees::Template::ValidationScope)
    end
  end

  describe "ACTIVE_VARS" do
    it "includes the six active-context variables" do
      %w[branch worktree_path worktree_name commit short_commit upstream].each do |v|
        WorkTrees::Template::ACTIVE_VARS.should contain(v)
      end
    end
  end

  describe "REPO_VARS" do
    it "includes repo metadata variables" do
      %w[repo repo_path owner remote remote_url].each do |v|
        WorkTrees::Template::REPO_VARS.should contain(v)
      end
    end
  end
end
