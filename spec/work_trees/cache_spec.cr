require "../spec_helper"
require "file_utils"

module WorkTrees
  describe Cache do
    it "round-trips read/write JSON" do
      with_tmp_dir do |dir|
        path = File.join(dir, "sub", "entry.json")
        Cache.read_json(path).should be_nil
        Cache.write_json(path, JSON.parse(%({"x":42})))
        parsed = Cache.read_json(path)
        parsed.should_not be_nil
        parsed.not_nil!["x"].as_i.should eq(42)
      end
    end

    it "returns nil for corrupt JSON" do
      with_tmp_dir do |dir|
        path = File.join(dir, "bad.json")
        File.write(path, "not json {{")
        Cache.read_json(path).should be_nil
      end
    end

    describe "clear_one" do
      it "returns false for a missing file" do
        with_tmp_dir do |dir|
          Cache.clear_one(File.join(dir, "nope.json")).should be_false
        end
      end

      it "raises when the path is a directory, not a file" do
        with_tmp_dir do |dir|
          path = File.join(dir, "dir.json")
          Dir.mkdir(path)
          expect_raises(Exception) do
            Cache.clear_one(path)
          end
        end
      end
    end

    describe "clear_json_files" do
      it "removes .json files, counts them, and skips non-.json siblings" do
        with_tmp_dir do |dir|
          sub = File.join(dir, "c")
          Dir.mkdir_p(sub)
          File.write(File.join(sub, "a.json"), "{}")
          File.write(File.join(sub, "b.json"), "{}")
          File.write(File.join(sub, "README"), "stray")
          File.write(File.join(sub, "a.json.tmp"), "leftover")

          Cache.clear_json_files(sub).should eq(2)
          File.exists?(File.join(sub, "a.json")).should be_false
          File.exists?(File.join(sub, "b.json")).should be_false
          File.exists?(File.join(sub, "README")).should be_true
          File.exists?(File.join(sub, "a.json.tmp")).should be_true
        end
      end

      it "returns 0 for a missing directory" do
        with_tmp_dir do |dir|
          Cache.clear_json_files(File.join(dir, "nope")).should eq(0)
        end
      end

      it "raises when the path is a file, not a directory" do
        with_tmp_dir do |dir|
          path = File.join(dir, "not-a-dir")
          File.write(path, "file")
          expect_raises(Exception) do
            Cache.clear_json_files(path)
          end
        end
      end
    end

    describe "count_json_files" do
      it "counts .json files and skips others" do
        with_tmp_dir do |dir|
          sub = File.join(dir, "c")
          Dir.mkdir_p(sub)
          File.write(File.join(sub, "a.json"), "{}")
          File.write(File.join(sub, "README"), "stray")

          Cache.count_json_files(sub).should eq(1)
          Cache.count_json_files(File.join(dir, "nope")).should eq(0)
        end
      end
    end

    describe "sweep_lru" do
      it "trims oldest entries when over the max bound" do
        with_tmp_dir do |dir|
          sub = File.join(dir, "c")
          Dir.mkdir_p(sub)
          (0...5).each do |i|
            File.write(File.join(sub, "entry#{i}.json"), "true")
            sleep(Time::Span.new(nanoseconds: 15_000_000)) # ensure distinct mtimes
          end

          Cache.sweep_lru(sub, 3)
          remaining = Dir.children(sub).select(&.ends_with?(".json")).sort!
          remaining.should eq(["entry2.json", "entry3.json", "entry4.json"])
        end
      end

      it "keeps all entries when under the max bound" do
        with_tmp_dir do |dir|
          sub = File.join(dir, "c")
          Dir.mkdir_p(sub)
          (0...3).each do |i|
            File.write(File.join(sub, "entry#{i}.json"), "true")
          end

          Cache.sweep_lru(sub, 5)
          remaining = Dir.children(sub).select(&.ends_with?(".json"))
          remaining.size.should eq(3)
        end
      end
    end
  end
end

private def with_tmp_dir(&)
  dir = File.tempname("wt-cache")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
