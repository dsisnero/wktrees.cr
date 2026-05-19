require "../../spec_helper"

describe WorkTrees::Template do
  describe ".sanitize" do
    it "replaces forward slashes with dashes" do
      WorkTrees::Template.sanitize("feature/foo").should eq("feature-foo")
    end

    it "replaces backslashes with dashes" do
      WorkTrees::Template.sanitize("user\\task").should eq("user-task")
    end

    it "returns unchanged for already-safe names" do
      WorkTrees::Template.sanitize("simple-branch").should eq("simple-branch")
    end

    it "handles mixed separators" do
      WorkTrees::Template.sanitize("a/b\\c").should eq("a-b-c")
    end
  end

  describe ".short_hash" do
    it "produces a 3-character deterministic string" do
      h1 = WorkTrees::Template.short_hash("hello")
      h2 = WorkTrees::Template.short_hash("hello")
      h1.should eq(h2)
      h1.size.should eq(3)
    end

    it "produces different hashes for different inputs" do
      h1 = WorkTrees::Template.short_hash("hello")
      h2 = WorkTrees::Template.short_hash("world")
      h1.should_not eq(h2)
    end

    it "uses only base-36 characters" do
      h = WorkTrees::Template.short_hash("test")
      h.should match(/^[0-9a-z]{3}$/)
    end
  end

  describe ".sanitize_db" do
    it "returns empty string for empty input" do
      WorkTrees::Template.sanitize_db("").should eq("")
    end

    it "hashes to ensure uniqueness" do
      result = WorkTrees::Template.sanitize_db("feature/auth")
      result.should start_with("feature_auth_")
    end

    it "prefixes digit-starting identifiers with underscore" do
      result = WorkTrees::Template.sanitize_db("123-bug-fix")
      result.should start_with("_123_bug_fix_")
    end

    it "converts to lowercase" do
      result = WorkTrees::Template.sanitize_db("UPPERCASE.Branch")
      result.should start_with("uppercase_branch_")
    end

    it "produces distinct results for colliding transforms" do
      db1 = WorkTrees::Template.sanitize_db("a-b")
      db2 = WorkTrees::Template.sanitize_db("a_b")
      db1.should_not eq(db2)
    end

    it "truncates to max 48 characters" do
      long_input = "a" * 100
      result = WorkTrees::Template.sanitize_db(long_input)
      result.size.should be <= 48
    end

    it "collapses consecutive underscores" do
      result = WorkTrees::Template.sanitize_db("a---b")
      result.should_not contain("__")
    end
  end

  describe ".sanitize_hash" do
    it "returns unchanged for already-safe filenames" do
      WorkTrees::Template.sanitize_hash("simple").should eq("simple")
    end

    it "returns empty for empty input" do
      WorkTrees::Template.sanitize_hash("").should eq("")
    end

    it "replaces invalid chars and appends hash" do
      result = WorkTrees::Template.sanitize_hash("feature/foo")
      result.should start_with("feature-foo-")
      result.size.should eq("feature-foo-".size + 3)
    end
  end

  describe ".hash_port" do
    it "produces a port in range 10000..19999" do
      port = WorkTrees::Template.hash_port("my-branch")
      port.should be >= 10000
      port.should be <= 19999
    end

    it "is deterministic" do
      port1 = WorkTrees::Template.hash_port("branch-a")
      port2 = WorkTrees::Template.hash_port("branch-a")
      port1.should eq(port2)
    end
  end

  describe ".dirname" do
    it "strips the last path component" do
      WorkTrees::Template.dirname("/a/b/c").should eq("/a/b")
    end

    it "handles a single component" do
      WorkTrees::Template.dirname("file").should eq("")
    end
  end

  describe ".basename" do
    it "returns the last path component" do
      WorkTrees::Template.basename("/a/b/c").should eq("c")
    end

    it "handles a single component" do
      WorkTrees::Template.basename("file").should eq("file")
    end
  end

  describe ".redact_credentials" do
    it "redacts credentials in URLs" do
      result = WorkTrees::Template.redact_credentials("https://ghp_token123@github.com/owner/repo")
      result.should eq("https://[REDACTED]@github.com/owner/repo")
    end

    it "leaves URLs without credentials unchanged" do
      result = WorkTrees::Template.redact_credentials("https://github.com/owner/repo")
      result.should eq("https://github.com/owner/repo")
    end

    it "passes through non-URL values" do
      result = WorkTrees::Template.redact_credentials("main")
      result.should eq("main")
    end
  end
end
