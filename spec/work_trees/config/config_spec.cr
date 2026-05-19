require "../../spec_helper"

describe WorkTrees::Config do
  describe ".load_user" do
    it "returns default config when no file exists" do
      config = WorkTrees::Config.load_user("/nonexistent/path")
      config.worktree_path_template.should_not be_empty
    end

    it "parses worktree path template from TOML" do
      toml = <<-TOML
      worktree-path = "~/dev/{{ branch | sanitize }}"
      TOML
      config = WorkTrees::Config.parse_user(toml)
      config.worktree_path_template.should eq("~/dev/{{ branch | sanitize }}")
    end

    it "provides default worktree path template" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template.should contain("{{ branch")
    end
  end

  describe "UserConfig" do
    it "has sensible defaults" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template.should eq("~/worktrees/{{ branch | sanitize }}")
    end

    it "is customizable" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template = "~/code/{{ branch }}"
      config.worktree_path_template.should eq("~/code/{{ branch }}")
    end
  end
end
