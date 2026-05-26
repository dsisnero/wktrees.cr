require "../../spec_helper"

module WorkTrees
  describe Config::HookSource do
    it "has User and Project variants" do
      Config::HookSource::User.should be_a(Config::HookSource)
      Config::HookSource::Project.should be_a(Config::HookSource)
      Config::HookSource::User.should_not eq(Config::HookSource::Project)
    end
  end

  describe Config::ParsedFilter do
    describe ".parse" do
      it "parses user: prefix" do
        filter = Config::ParsedFilter.parse("user:my-hook")
        filter.source.should eq(Config::HookSource::User)
        filter.name.should eq("my-hook")
      end

      it "parses project: prefix" do
        filter = Config::ParsedFilter.parse("project:deploy")
        filter.source.should eq(Config::HookSource::Project)
        filter.name.should eq("deploy")
      end

      it "parses bare name as any-source" do
        filter = Config::ParsedFilter.parse("build")
        filter.source.should be_nil
        filter.name.should eq("build")
      end

      it "parses user: with empty name (all user hooks)" do
        filter = Config::ParsedFilter.parse("user:")
        filter.source.should eq(Config::HookSource::User)
        filter.name.should eq("")
      end

      it "parses project: with empty name (all project hooks)" do
        filter = Config::ParsedFilter.parse("project:")
        filter.source.should eq(Config::HookSource::Project)
        filter.name.should eq("")
      end
    end

    describe "#matches_source?" do
      it "without source filter matches any source" do
        filter = Config::ParsedFilter.parse("build")
        filter.matches_source?(Config::HookSource::User).should be_true
        filter.matches_source?(Config::HookSource::Project).should be_true
      end

      it "with user: filter matches only User" do
        filter = Config::ParsedFilter.parse("user:build")
        filter.matches_source?(Config::HookSource::User).should be_true
        filter.matches_source?(Config::HookSource::Project).should be_false
      end

      it "with project: filter matches only Project" do
        filter = Config::ParsedFilter.parse("project:deploy")
        filter.matches_source?(Config::HookSource::User).should be_false
        filter.matches_source?(Config::HookSource::Project).should be_true
      end
    end
  end

  # Test the CLI-level filter_hooks_by_name via the HookCommand and ParsedFilter types
  describe "hook name filtering" do
    it "passes all hooks when filters are empty" do
      h1 = Config::HookCommand.new("build", "cargo build")
      h2 = Config::HookCommand.new("test", "cargo test")
      hooks = [h1, h2]
      result = filter_hooks(hooks, [] of Config::ParsedFilter)
      result.size.should eq(2)
    end

    it "filters by exact name" do
      h1 = Config::HookCommand.new("build", "cargo build")
      h2 = Config::HookCommand.new("test", "cargo test")
      hooks = [h1, h2]
      filters = [Config::ParsedFilter.parse("build")]
      result = filter_hooks(hooks, filters)
      result.size.should eq(1)
      result[0].name.should eq("build")
    end

    it "filters by source prefix (name match across both sources)" do
      h1 = Config::HookCommand.new("build", "cargo build")
      h2 = Config::HookCommand.new("deploy", "kubectl apply")
      hooks = [h1, h2]
      filters = [Config::ParsedFilter.parse("user:build")]
      result = filter_hooks(hooks, filters)
      result.size.should eq(1)
      result[0].name.should eq("build")
    end
  end
end

# Helper: simulate CLI filter_hooks_by_name logic
private def filter_hooks(hooks, filters)
  return hooks if filters.empty?
  hooks.select do |hook|
    filters.any? do |filter|
      filter.name.empty? || hook.name == filter.name
    end
  end
end
