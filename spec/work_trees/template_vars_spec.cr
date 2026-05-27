require "../spec_helper"

module WorkTrees
  describe TemplateVars do
    describe "#as_extra_vars" do
      it "returns empty for new instance" do
        vars = TemplateVars.new
        vars.as_extra_vars.should be_empty
      end

      it "emits base and base_worktree_path" do
        vars = TemplateVars.new.with_base("main", "/repo")
        pairs = vars.as_extra_vars
        pairs.should contain({"base", "main"})
        pairs.should contain({"base_worktree_path", "/repo"})
      end

      it "emits target and target_worktree_path" do
        vars = TemplateVars.new
          .with_target("feature")
          .with_target_worktree_path("/repo.feature")
        pairs = vars.as_extra_vars
        pairs.should contain({"target", "feature"})
        pairs.should contain({"target_worktree_path", "/repo.feature"})
      end

      it "emits worktree_path with deprecated worktree alias" do
        vars = TemplateVars.new.with_active_worktree("/repo.feature")
        pairs = vars.as_extra_vars
        pairs.should contain({"worktree_path", "/repo.feature"})
        pairs.should contain({"worktree", "/repo.feature"})
        pairs.should contain({"worktree_name", "repo.feature"})
      end

      it "falls back to unknown for worktree_name on root path" do
        vars = TemplateVars.new.with_active_worktree("/")
        pairs = vars.as_extra_vars
        pairs.should contain({"worktree_name", "unknown"})
      end

      it "emits commit and short_commit" do
        vars = TemplateVars.new.with_active_commit("0123456789abcdef", "0123456")
        pairs = vars.as_extra_vars
        pairs.should contain({"commit", "0123456789abcdef"})
        pairs.should contain({"short_commit", "0123456"})
      end

      it "emits pr_number and pr_url independently" do
        vars = TemplateVars.new.with_pr(42_u32, "https://example.test/pr/42")
        pairs = vars.as_extra_vars
        pairs.should contain({"pr_number", "42"})
        pairs.should contain({"pr_url", "https://example.test/pr/42"})
      end

      it "skips None values in with_base_strs" do
        vars = TemplateVars.new.with_base_strs("main", nil)
        pairs = vars.as_extra_vars
        pairs.should contain({"base", "main"})
        pairs.none? { |(k, _)| k == "base_worktree_path" }.should be_true
      end

      it "returns multiple pairs combined" do
        vars = TemplateVars.new
          .with_base("main", "/repo")
          .with_target("feature")
          .with_active_commit("abc", "abc1234")
        pairs = vars.as_extra_vars
        pairs.size.should be >= 4
        pairs.should contain({"base", "main"})
        pairs.should contain({"target", "feature"})
        pairs.should contain({"commit", "abc"})
      end
    end
  end
end
