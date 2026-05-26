require "../spec_helper"
require "../../src/work_trees/cache"

# Recursive remove helper for test cleanup
private def rm_rf(path : String)
  if File.directory?(path)
    Dir.children(path).each do |child|
      rm_rf(File.join(path, child))
    end
    Dir.delete(path)
  else
    File.delete(path)
  end
rescue File::NotFoundError
  # already gone
end

module WorkTrees
  describe Cache do
    tmp_dir = File.join(Dir.tempdir, "wt_cache_test_#{Random.rand(99999)}")
    Dir.mkdir(tmp_dir) unless Dir.exists?(tmp_dir)

    Spec.before_each do
      Dir.children(tmp_dir).each do |child|
        rm_rf(File.join(tmp_dir, child))
      end
    end

    describe ".read_json" do
      it "returns nil for missing file" do
        path = File.join(tmp_dir, "nonexistent.json")
        Cache.read_json(path).should be_nil
      end

      it "returns nil for corrupt JSON" do
        path = File.join(tmp_dir, "bad.json")
        File.write(path, "not json {{")
        Cache.read_json(path).should be_nil
      end

      it "round-trips valid JSON" do
        path = File.join(tmp_dir, "good.json")
        value = JSON::Any.new({"x" => JSON::Any.new(42_i64)})
        Cache.write_json(path, value)
        result = Cache.read_json(path)
        result.should_not be_nil
      end
    end

    describe ".write_json" do
      it "creates parent directories" do
        path = File.join(tmp_dir, "sub", "deep", "entry.json")
        value = JSON::Any.new({"key" => JSON::Any.new("val")})
        Cache.write_json(path, value)
        File.exists?(path).should be_true
      end
    end

    describe ".clear_one" do
      it "returns false for missing file" do
        path = File.join(tmp_dir, "nope.json")
        Cache.clear_one(path).should be_false
      end

      it "returns true for existing file" do
        path = File.join(tmp_dir, "yes.json")
        File.write(path, "{}")
        Cache.clear_one(path).should be_true
        File.exists?(path).should be_false
      end
    end

    describe ".clear_json_files" do
      it "removes .json files and skips non-json" do
        cdir = File.join(tmp_dir, "cache_test")
        Dir.mkdir(cdir)
        File.write(File.join(cdir, "a.json"), "{}")
        File.write(File.join(cdir, "b.json"), "{}")
        File.write(File.join(cdir, "README"), "stray")
        File.write(File.join(cdir, "a.json.tmp"), "leftover")

        Cache.clear_json_files(cdir).should eq(2)
        File.exists?(File.join(cdir, "a.json")).should be_false
        File.exists?(File.join(cdir, "b.json")).should be_false
        File.exists?(File.join(cdir, "README")).should be_true
        File.exists?(File.join(cdir, "a.json.tmp")).should be_true
      end

      it "returns 0 for missing directory" do
        Cache.clear_json_files(File.join(tmp_dir, "noexist")).should eq(0)
      end
    end

    describe ".count_json_files" do
      it "counts only .json files" do
        cdir = File.join(tmp_dir, "count_test")
        Dir.mkdir(cdir)
        File.write(File.join(cdir, "a.json"), "{}")
        File.write(File.join(cdir, "README"), "stray")

        Cache.count_json_files(cdir).should eq(1)
        Cache.count_json_files(File.join(tmp_dir, "nope")).should eq(0)
      end
    end

    describe ".sweep_lru" do
      it "trims oldest entries" do
        cdir = File.join(tmp_dir, "lru_test")
        Dir.mkdir(cdir)
        5.times do |i|
          File.write(File.join(cdir, "entry#{i}.json"), "true")
          sleep 0.01.seconds
        end

        Cache.sweep_lru(cdir, 3)

        remaining = Dir.children(cdir).select(&.ends_with?(".json")).sort
        # entry4 and entry3 are newest (highest i), entry0 and entry1 should be trimmed
        remaining.should eq(["entry2.json", "entry3.json", "entry4.json"])
      end

      it "does nothing when under bound" do
        cdir = File.join(tmp_dir, "lru_under_test")
        Dir.mkdir(cdir)
        3.times do |i|
          File.write(File.join(cdir, "entry#{i}.json"), "true")
        end

        Cache.sweep_lru(cdir, 5)
        Cache.count_json_files(cdir).should eq(3)
      end
    end
  end
end
