require "../../spec_helper"

describe WorkTrees::Template do
  describe ".expand" do
    it "substitutes simple variables" do
      result = WorkTrees::Template.expand("~/repo.{{ branch }}", {"branch" => "feature-auth"})
      result.should eq("~/repo.feature-auth")
    end

    it "supports sanitize filter" do
      result = WorkTrees::Template.expand(
        "~/repo.{{ branch | sanitize }}",
        {"branch" => "feature/auth"}
      )
      result.should eq("~/repo.feature-auth")
    end

    it "supports codename filter with word count" do
      result = WorkTrees::Template.expand(
        "~/repo.{{ branch | codename(2) }}",
        {"branch" => "feature-auth"}
      )
      # codename is deterministic, should produce a specific 2-word output
      result.should_not contain("{{")
      result.should match(%r{~/repo\.[a-z]+-[a-z]+$})
    end

    it "supports hash filter" do
      result = WorkTrees::Template.expand(
        "~/repo.{{ branch | hash }}",
        {"branch" => "feature-auth"}
      )
      result.should_not contain("{{")
      result.should match(%r{~/repo\.[0-9a-z]{3}$})
    end

    it "supports hash_port filter" do
      result = WorkTrees::Template.expand(
        "port={{ branch | hash_port }}",
        {"branch" => "my-service"}
      )
      result.should_not contain("{{")
      result.should match(/port=\d+/)
    end

    it "supports sanitize_db filter" do
      result = WorkTrees::Template.expand(
        "db_{{ branch | sanitize_db }}",
        {"branch" => "feature/auth"}
      )
      result.should start_with("db_feature_auth_")
    end

    it "supports sanitize_hash filter" do
      result = WorkTrees::Template.expand(
        "{{ branch | sanitize_hash }}",
        {"branch" => "feature/auth"}
      )
      result.should_not contain("/")
      result.should contain("feature-auth-")
    end

    it "supports dirname filter" do
      result = WorkTrees::Template.expand(
        "{{ path | dirname }}",
        {"path" => "/home/user/repo"}
      )
      result.should eq("/home/user")
    end

    it "supports basename filter" do
      result = WorkTrees::Template.expand(
        "{{ path | basename }}",
        {"path" => "/home/user/repo"}
      )
      result.should eq("repo")
    end

    it "handles multiple variables in one template" do
      result = WorkTrees::Template.expand(
        "{{ repo }}/{{ branch | sanitize }}",
        {"repo" => "myproject", "branch" => "feature/login"}
      )
      result.should eq("myproject/feature-login")
    end

    it "leaves unmatched placeholders as-is" do
      result = WorkTrees::Template.expand(
        "{{ branch }}-{{ unknown }}",
        {"branch" => "main"}
      )
      result.should eq("main-{{ unknown }}")
    end

    it "handles empty template" do
      result = WorkTrees::Template.expand("", {"branch" => "main"})
      result.should eq("")
    end

    it "handles no placeholders" do
      result = WorkTrees::Template.expand("just/a/path", {"branch" => "main"})
      result.should eq("just/a/path")
    end

    it "computes worktree path from config template" do
      result = WorkTrees::Template.expand(
        "~/worktrees/{{ branch | sanitize }}",
        {"branch" => "fix/auth-bug"}
      )
      result.should eq("~/worktrees/fix-auth-bug")
    end

    it "expands multiple placeholders with filters" do
      result = WorkTrees::Template.expand(
        "{{ repo }}.{{ branch | sanitize }}.port_{{ branch | hash_port }}",
        {"repo" => "myapp", "branch" => "feature/x"}
      )
      result.should match(/^myapp\.feature-x\.port_\d{5}$/)
    end
  end
end
