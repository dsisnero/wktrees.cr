require "../../spec_helper"

describe WorkTrees::Config do
  describe ".parse_hooks" do
    it "parses hook commands from TOML" do
      toml = <<-TOML
      [post-start]
      server = "npm run dev"
      TOML

      hooks = WorkTrees::Config.parse_hooks(toml, "post-start")
      hooks.size.should eq(1)
      hooks.first.name.should eq("server")
      hooks.first.command.should eq("npm run dev")
    end

    it "parses string hook (no section table)" do
      toml = <<-TOML
      [pre-start]
      init = "npm install"
      TOML

      hooks = WorkTrees::Config.parse_hooks(toml, "pre-start")
      hooks.size.should eq(1)
      hooks.first.command.should eq("npm install")
    end

    it "parses multiple hooks" do
      toml = <<-TOML
      [post-start]
      server = "npm run dev"
      lint = "cargo clippy"
      TOML

      hooks = WorkTrees::Config.parse_hooks(toml, "post-start")
      hooks.size.should eq(2)
    end

    it "returns empty for missing section" do
      toml = <<-TOML
      [commit]
      template = "feat: {{ branch }}"
      TOML

      hooks = WorkTrees::Config.parse_hooks(toml, "pre-start")
      hooks.should be_empty
    end
  end
end

describe WorkTrees::Config::HookCommand do
  it "stores name and command" do
    cmd = WorkTrees::Config::HookCommand.new("test", "echo hello")
    cmd.name.should eq("test")
    cmd.command.should eq("echo hello")
  end

  it "interpolates template variables" do
    cmd = WorkTrees::Config::HookCommand.new("test", "echo {{ branch }}")
    result = cmd.expand({"branch" => "feature-x"})
    result.should eq("echo feature-x")
  end
end
