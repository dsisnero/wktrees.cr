require "../spec_helper"

module WorkTrees
  describe PathUtil do
    describe "sanitize_for_filename" do
      it "passes through clean names" do
        result = PathUtil.sanitize_for_filename("feature-login-fix")
        result.should eq("feature-login-fix")
      end

      it "replaces forward slashes" do
        result = PathUtil.sanitize_for_filename("feature/login")
        result.should eq("feature-login")
      end

      it "replaces backslashes" do
        result = PathUtil.sanitize_for_filename("path\\to\\branch")
        result.should eq("path-to-branch")
      end

      it "replaces colons" do
        result = PathUtil.sanitize_for_filename("branch:name")
        result.should eq("branch-name")
      end

      it "replaces multiple invalid chars" do
        result = PathUtil.sanitize_for_filename("feature/fix:login\\bug")
        result.should eq("feature-fix-login-bug")
      end

      it "trims leading hyphens" do
        result = PathUtil.sanitize_for_filename("-feature")
        result.should eq("feature")
      end

      it "returns empty-safe string for all-invalid input" do
        result = PathUtil.sanitize_for_filename("/:\\")
        result.should eq("")
      end
    end

    describe "format_path_for_display" do
      it "replaces home directory with ~" do
        home = Path.home.to_s
        result = PathUtil.format_path_for_display("#{home}/worktrees/feature")
        result.should contain("~/worktrees/feature")
      end

      it "passes through paths outside home" do
        result = PathUtil.format_path_for_display("/tmp/worktrees/feature")
        result.should contain("/tmp/worktrees/feature")
      end
    end
    describe "tilde_expand" do
      it "expands leading ~ to home directory" do
        result = PathUtil.expand_home("~/worktrees/feature")
        result.should contain("/worktrees/feature")
        result.should_not contain("~/")
      end

      it "passes through non-tilde paths" do
        PathUtil.expand_home("/tmp/feature").should eq("/tmp/feature")
      end

      it "handles just ~" do
        result = PathUtil.expand_home("~")
        result.should eq(Path.home.to_s)
      end
    end
  end
end
