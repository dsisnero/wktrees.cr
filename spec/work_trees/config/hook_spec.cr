require "../../spec_helper"

describe WorkTrees::Config do
  describe ".parse_hooks" do
    it "parses concurrent hook commands from TOML" do
      toml = <<-TOML
      [post-start]
      server = "npm run dev"
      TOML

      groups = WorkTrees::Config.parse_hooks(toml, "post-start")
      groups.size.should eq(1)
      groups.first.concurrent?.should be_true
      groups.first.hooks.first.name.should eq("server")
      groups.first.hooks.first.command.should eq("npm run dev")
    end

    it "parses named hook from table" do
      toml = <<-TOML
      [pre-start]
      init = "npm install"
      TOML

      groups = WorkTrees::Config.parse_hooks(toml, "pre-start")
      groups.size.should eq(1)
      groups.first.hooks.first.command.should eq("npm install")
    end

    it "parses multiple concurrent hooks" do
      toml = <<-TOML
      [post-start]
      server = "npm run dev"
      lint = "cargo clippy"
      TOML

      groups = WorkTrees::Config.parse_hooks(toml, "post-start")
      groups.size.should eq(1)
      hooks = groups.first.hooks
      hooks.size.should eq(2)
    end

    it "returns empty for missing section" do
      toml = <<-TOML
      [commit]
      template = "feat: {{ branch }}"
      TOML

      groups = WorkTrees::Config.parse_hooks(toml, "pre-start")
      groups.should be_empty
    end

    it "parses sequential pipeline hooks from array-of-tables" do
      toml = <<-TOML
      [[post-start]]
      install = "npm install"
      [[post-start]]
      build = "npm run build"
      TOML

      groups = WorkTrees::Config.parse_hooks(toml, "post-start")
      groups.size.should eq(2)
      groups[0].sequential?.should be_true
      groups[0].hooks.first.command.should eq("npm install")
      groups[1].sequential?.should be_true
      groups[1].hooks.first.command.should eq("npm run build")
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
