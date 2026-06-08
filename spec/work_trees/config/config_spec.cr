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
      config.worktree_path_template.should eq("{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}")
    end

    it "is customizable" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template = "~/code/{{ branch }}"
      config.worktree_path_template.should eq("~/code/{{ branch }}")
    end
  end

  describe "config sections" do
    it "parses [list] section with full and branches" do
      toml = <<-TOML
      [list]
      full = true
      branches = false
      TOML
      config = WorkTrees::Config.parse_user(toml)
      config.list_config.full?.should be_true
      config.list_config.branches?.should be_false
    end

    it "parses [merge] section with squash and ff" do
      toml = <<-TOML
      [merge]
      squash = false
      ff = true
      TOML
      config = WorkTrees::Config.parse_user(toml)
      config.merge_config.squash?.should be_false
    end

    it "parses [commit] section with stage mode" do
      toml = <<-TOML
      [commit]
      stage = "tracked"
      TOML
      config = WorkTrees::Config.parse_user(toml)
      config.commit_config.stage.should eq(WorkTrees::Config::StageMode::Tracked)
    end

    it "has sensible defaults for all section configs" do
      config = WorkTrees::Config::UserConfig.new
      config.list_config.full?.should be_false
      config.list_config.branches?.should be_false
      config.merge_config.squash?.should be_true
      config.merge_config.rebase?.should be_true
      config.commit_config.stage.should eq(WorkTrees::Config::StageMode::All)
    end

    it "merges list config project over user" do
      user = WorkTrees::Config.parse_user("[list]\nfull = false\nbranches = true\n")
      project = WorkTrees::Config.parse_project("[list]\nfull = true\n")
      merged = WorkTrees::Config.merge(user, project)
      merged.list_config.full?.should be_true
      merged.list_config.branches?.should be_true
    end
  end

  describe "vendor parity" do
    # Mirrors upstream tests:
    #   vendor/worktrunk/src/config/user/tests.rs: test_worktrunk_config_default
    #   vendor/worktrunk/src/config/mod.rs: test_default_config
    it "defaults to sibling-directory worktree path" do
      config = WorkTrees::Config::UserConfig.new
      # vendor: "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}"
      config.worktree_path_template.should eq("{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}")
    end

    # Mirrors vendor/test_format_worktree_path in mod.rs:187-199
    # The sibling-directory template expands with raw vars; `..` is NOT resolved
    # by the template engine (only ~ is expanded), leaving resolution to git/filesystem.
    it "expands format path with vars" do
      result = WorkTrees::Template.expand(
        WorkTrees::Config::UserConfig::DEFAULT_PATH_TEMPLATE,
        {"repo_path" => "/home/user/code/myproject", "repo" => "myproject", "branch" => "feature/auth"}
      )
      # vendor: sibling directory → /home/user/code/myproject/../myproject.feature-auth
      result.should eq("/home/user/code/myproject/../myproject.feature-auth")
    end

    # Mirrors vendor/test_worktree_path_for_project_falls_back_to_default (tests.rs:232-240)
    it "falls back to default when no config is set" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template.should eq(WorkTrees::Config::UserConfig::DEFAULT_PATH_TEMPLATE)
    end
  end

  describe "env var overrides" do
    it "applies WORKTRUNK_WORKTREE_PATH override" do
      config = WorkTrees::Config::UserConfig.new
      with_env({"WORKTRUNK_WORKTREE_PATH" => "/tmp/{{ branch }}"}) do
        overridden = WorkTrees::Config.apply_env_overrides(config)
        overridden.worktree_path_template.should eq("/tmp/{{ branch }}")
      end
    end

    it "applies WORKTRUNK_COMMIT__GENERATION__COMMAND override" do
      config = WorkTrees::Config::UserConfig.new
      with_env({"WORKTRUNK_COMMIT__GENERATION__COMMAND" => "llm-cli"}) do
        overridden = WorkTrees::Config.apply_env_overrides(config)
        overridden.llm_command.should eq("llm-cli")
      end
    end

    it "does not change config when no env vars are set" do
      config = WorkTrees::Config::UserConfig.new
      config.worktree_path_template = "~/dev/{{ branch }}"
      with_env({} of String => String) do
        overridden = WorkTrees::Config.apply_env_overrides(config)
        overridden.worktree_path_template.should eq("~/dev/{{ branch }}")
      end
    end

    it "ignores excluded env vars" do
      config = WorkTrees::Config::UserConfig.new
      with_env({"WORKTRUNK_CONFIG_PATH" => "/custom/path"}) do
        overridden = WorkTrees::Config.apply_env_overrides(config)
        overridden.worktree_path_template.should eq(WorkTrees::Config::UserConfig::DEFAULT_PATH_TEMPLATE)
      end
    end

    it "collect_env_overrides returns empty hash with no env vars" do
      with_env({} of String => String) do
        WorkTrees::Config.collect_env_overrides.should be_empty
      end
    end
  end
end

# Helper to temporarily set/clear environment variables during a test
private def with_env(vars : Hash(String, String), &)
  old = {} of String => String?
  vars.each do |key, value|
    old[key] = ENV[key]?
    ENV[key] = value
  end
  begin
    yield
  ensure
    old.each do |key, value|
      if value
        ENV[key] = value
      else
        ENV.delete(key)
      end
    end
  end
end
