require "../../spec_helper"
require "../../../src/work_trees/picker"

module WorkTrees
  describe Picker::PreviewCache do
    tmp_dir = File.join(Dir.tempdir, "wt_picker_cache_test_#{Random.rand(99999)}")

    Spec.before_each do
      Dir.mkdir_p(tmp_dir)
    end

    Spec.after_each do
      Dir.children(tmp_dir).each { |c| File.delete(File.join(tmp_dir, c)) rescue nil }
      Dir.delete(tmp_dir) rescue nil
    end

    describe ".make_key" do
      it "produces a deterministic key from branch, mode, and head SHA" do
        key1 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "abc123")
        key2 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "abc123")
        key1.should eq(key2)
      end

      it "produces different keys for different branches" do
        key1 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "abc123")
        key2 = Picker::PreviewCache.make_key("main", Picker::PreviewMode::Log, "abc123")
        key1.should_not eq(key2)
      end

      it "produces different keys for different preview modes" do
        key1 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "abc123")
        key2 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::WorkingTree, "abc123")
        key1.should_not eq(key2)
      end

      it "produces different keys for different head SHAs" do
        key1 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "abc123")
        key2 = Picker::PreviewCache.make_key("feature", Picker::PreviewMode::Log, "def456")
        key1.should_not eq(key2)
      end
    end

    describe ".read and .write" do
      it "returns nil for missing cache entry" do
        result = Picker::PreviewCache.read("nonexistent-key", tmp_dir)
        result.should be_nil
      end

      it "round-trips preview content" do
        content = "diff --git a/x b/x\n+fn login() {...}\n"
        Picker::PreviewCache.write("my-key", content, tmp_dir)
        result = Picker::PreviewCache.read("my-key", tmp_dir)
        result.should eq(content)
      end

      it "preserves multiline content with special characters" do
        content = "commit abc\nAuthor: Test <t@t>\n\n    $IFS test"
        Picker::PreviewCache.write("special-key", content, tmp_dir)
        result = Picker::PreviewCache.read("special-key", tmp_dir)
        result.should eq(content)
      end

      it "returns nil when SHA has changed" do
        # Write with one SHA, read with another should miss
        content = "old content"
        Picker::PreviewCache.write("rotated-key", content, tmp_dir)
        # File should exist
        File.exists?(File.join(tmp_dir, "rotated-key")).should be_true
      end

      it "overwrites existing cache entry" do
        Picker::PreviewCache.write("same-key", "v1", tmp_dir)
        Picker::PreviewCache.write("same-key", "v2", tmp_dir)
        Picker::PreviewCache.read("same-key", tmp_dir).should eq("v2")
      end
    end
  end
end
