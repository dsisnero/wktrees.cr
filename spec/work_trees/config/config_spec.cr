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
