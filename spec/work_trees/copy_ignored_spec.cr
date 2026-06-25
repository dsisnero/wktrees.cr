require "../spec_helper"
require "file_utils"
require "../../src/work_trees/copy_ignored"

module WorkTrees
  describe CopyIgnored do
    describe "BUILTIN_EXCLUDES" do
      it "matches upstream built-in excludes (no .pi/)" do
        CopyIgnored::BUILTIN_EXCLUDES.should eq([
          ".bzr/", ".conductor/", ".entire/", ".hg/", ".jj/",
          ".pijul/", ".sl/", ".svn/", ".worktrees/",
        ])
      end
    end

    describe "parse_ls_files" do
      it "splits files and directories (trailing slash = dir)" do
        text = "node_modules/\n.env\ntarget/\nlog.txt\n"
        entries = CopyIgnored.parse_ls_files(text)
        entries.should eq([
          {"node_modules", true},
          {".env", false},
          {"target", true},
          {"log.txt", false},
        ])
      end

      it "ignores blank lines" do
        CopyIgnored.parse_ls_files("\n\n").should be_empty
      end
    end

    describe "pattern_matches?" do
      it "matches a directory pattern against a directory entry" do
        CopyIgnored.pattern_matches?("node_modules", true, "node_modules/").should be_true
        CopyIgnored.pattern_matches?("node_modules", true, "node_modules").should be_true
      end

      it "does not match a directory-only pattern against a file" do
        CopyIgnored.pattern_matches?("build", false, "build/").should be_false
      end

      it "matches glob patterns by basename in any segment" do
        CopyIgnored.pattern_matches?("foo.log", false, "*.log").should be_true
        CopyIgnored.pattern_matches?("src/foo.log", false, "*.log").should be_true
        CopyIgnored.pattern_matches?("foo.txt", false, "*.log").should be_false
      end

      it "anchors patterns containing a leading slash to the root" do
        CopyIgnored.pattern_matches?("cache", true, "/cache").should be_true
        CopyIgnored.pattern_matches?("src/cache", true, "/cache").should be_false
      end

      it "treats a leading ! (negation) as no match" do
        CopyIgnored.pattern_matches?("keep.log", false, "!keep.log").should be_false
      end
    end

    describe "filter_entries" do
      it "drops built-in VCS/tool directories" do
        entries = [{".jj", true}, {"node_modules", true}]
        result = CopyIgnored.filter_entries(entries, "/wt", [] of String,
          [] of String, [] of String)
        result.should eq([{"node_modules", true}])
      end

      it "drops entries containing nested worktrees" do
        entries = [{"sub", true}, {"keep", true}]
        result = CopyIgnored.filter_entries(entries, "/wt", ["/wt/sub"],
          [] of String, [] of String)
        result.should eq([{"keep", true}])
      end

      it "drops entries matching configured excludes" do
        entries = [{"secret", true}, {"cache", true}]
        result = CopyIgnored.filter_entries(entries, "/wt", [] of String,
          ["secret/"], [] of String)
        result.should eq([{"cache", true}])
      end

      it "keeps only worktreeinclude matches when include patterns are present" do
        entries = [{".env", false}, {"notes.txt", false}]
        result = CopyIgnored.filter_entries(entries, "/wt", [] of String,
          [] of String, ["*.env"])
        result.should eq([{".env", false}])
      end

      it "keeps everything when no include patterns are given" do
        entries = [{".env", false}, {"notes.txt", false}]
        result = CopyIgnored.filter_entries(entries, "/wt", [] of String,
          [] of String, [] of String)
        result.should eq(entries)
      end
    end

    describe "resolve" do
      it "defaults to the built-in excludes" do
        cfg = CopyIgnored.resolve(Config::StepConfig.new, nil)
        cfg.exclude.should eq(CopyIgnored::BUILTIN_EXCLUDES)
      end

      it "merges built-in, then project, then user (de-duped, ordered)" do
        user = Config::StepConfig.new(copy_ignored: Config::CopyIgnoredConfig.new(exclude: ["u/"]))
        project = Config::StepConfig.new(copy_ignored: Config::CopyIgnoredConfig.new(exclude: ["p/"]))
        cfg = CopyIgnored.resolve(user, project)
        cfg.exclude.should eq(CopyIgnored::BUILTIN_EXCLUDES + ["p/", "u/"])
      end
    end

    describe "copy_path" do
      it "copies a file and reports one file copied" do
        with_tmp_dir do |dir|
          src = File.join(dir, "src.txt")
          dst = File.join(dir, "dst.txt")
          File.write(src, "hello")
          count = CopyIgnored.copy_path(src, dst, force: false)
          count.should eq(1)
          File.read(dst).should eq("hello")
        end
      end

      it "skips an existing destination without --force" do
        with_tmp_dir do |dir|
          src = File.join(dir, "src.txt")
          dst = File.join(dir, "dst.txt")
          File.write(src, "new")
          File.write(dst, "old")
          count = CopyIgnored.copy_path(src, dst, force: false)
          count.should eq(0)
          File.read(dst).should eq("old")
        end
      end

      it "overwrites an existing destination with --force" do
        with_tmp_dir do |dir|
          src = File.join(dir, "src.txt")
          dst = File.join(dir, "dst.txt")
          File.write(src, "new")
          File.write(dst, "old")
          count = CopyIgnored.copy_path(src, dst, force: true)
          count.should eq(1)
          File.read(dst).should eq("new")
        end
      end

      it "copies directories recursively" do
        with_tmp_dir do |dir|
          src = File.join(dir, "src")
          Dir.mkdir_p(File.join(src, "nested"))
          File.write(File.join(src, "a.txt"), "a")
          File.write(File.join(src, "nested", "b.txt"), "b")
          dst = File.join(dir, "dst")
          count = CopyIgnored.copy_path(src, dst, force: false)
          count.should eq(2)
          File.read(File.join(dst, "a.txt")).should eq("a")
          File.read(File.join(dst, "nested", "b.txt")).should eq("b")
        end
      end

      it "preserves symlinks" do
        with_tmp_dir do |dir|
          File.write(File.join(dir, "target.txt"), "t")
          link = File.join(dir, "link")
          File.symlink("target.txt", link)
          dst = File.join(dir, "dst-link")
          CopyIgnored.copy_path(link, dst, force: false)
          File.symlink?(dst).should be_true
          File.readlink(dst).should eq("target.txt")
        end
      end
    end

    describe "move_entry" do
      it "moves a file within the same filesystem" do
        with_tmp_dir do |dir|
          src = File.join(dir, "a.txt")
          dst = File.join(dir, "b.txt")
          File.write(src, "content")
          CopyIgnored.move_entry(src, dst, is_dir: false)
          File.exists?(src).should be_false
          File.exists?(dst).should be_true
          File.read(dst).should eq("content")
        end
      end

      it "moves a directory within the same filesystem" do
        with_tmp_dir do |dir|
          src = File.join(dir, "sub")
          Dir.mkdir_p(src)
          File.write(File.join(src, "x.txt"), "x")
          dst = File.join(dir, "sub-dst")
          CopyIgnored.move_entry(src, dst, is_dir: true)
          File.exists?(src).should be_false
          File.exists?(dst).should be_true
          File.read(File.join(dst, "x.txt")).should eq("x")
        end
      end

      it "creates parent directories for the destination" do
        with_tmp_dir do |dir|
          src = File.join(dir, "a.txt")
          File.write(src, "deep")
          dst = File.join(dir, "nested", "deep", "a.txt")
          CopyIgnored.move_entry(src, dst, is_dir: false)
          File.exists?(src).should be_false
          File.read(dst).should eq("deep")
        end
      end
    end

    describe "stage_ignored + distribute_staged" do
      it "round-trips gitignored entries safely" do
        with_tmp_dir do |dir|
          tree_a = File.join(dir, "tree-a")
          tree_b = File.join(dir, "tree-b")
          staging = File.join(dir, "staging")
          Dir.mkdir_p(tree_a)
          Dir.mkdir_p(tree_b)
          Dir.mkdir_p(staging)

          # Tree A: has a gitignored file and dir
          File.write(File.join(tree_a, ".worktreeinclude"), ".env\nsecret/\n")
          File.write(File.join(tree_a, ".env"), "prod")
          Dir.mkdir_p(File.join(tree_a, "secret"))
          File.write(File.join(tree_a, "secret", "key"), "abc123")
          # Tree B: has a different gitignored file
          File.write(File.join(tree_b, ".worktreeinclude"), "cache/\n")
          Dir.mkdir_p(File.join(tree_b, "cache"))
          File.write(File.join(tree_b, "cache", "index.html"), "<html>")

          entries_a = [{"secret", true}, {".env", false}]
          entries_b = [{"cache", true}]

          CopyIgnored.stage_ignored(tree_a, entries_a, tree_b, entries_b, staging)
          # Staging should have a/ and b/ subdirs
          Dir.exists?(File.join(staging, "a")).should be_true
          Dir.exists?(File.join(staging, "b")).should be_true
          # Originals removed
          File.exists?(File.join(tree_a, ".env")).should be_false
          File.exists?(File.join(tree_a, "secret", "key")).should be_false
          File.exists?(File.join(tree_b, "cache", "index.html")).should be_false

          # Distribute: B's files go to A, A's files go to B (swap)
          CopyIgnored.distribute_staged(staging, tree_a, entries_a, tree_b, entries_b)
          # B's cache now in A
          File.read(File.join(tree_a, "cache", "index.html")).should eq("<html>")
          # A's secret/.env now in B
          File.read(File.join(tree_b, ".env")).should eq("prod")
          File.read(File.join(tree_b, "secret", "key")).should eq("abc123")
          # Staging cleaned up
          Dir.exists?(staging).should be_false
        end
      end
    end

    describe "list_ignored_entries (integration)" do
      it "discovers gitignored files and directories via git ls-files" do
        with_tmp_dir do |dir|
          git(dir, "init", "-q")
          git(dir, "config", "user.email", "t@example.com")
          git(dir, "config", "user.name", "Test")
          git(dir, "config", "commit.gpgsign", "false")
          File.write(File.join(dir, ".gitignore"), "ignored.txt\nbuild/\n")
          File.write(File.join(dir, "tracked.txt"), "x")
          git(dir, "add", ".gitignore", "tracked.txt")
          git(dir, "commit", "-q", "-m", "initial empty commit")
          File.write(File.join(dir, "ignored.txt"), "secret")
          Dir.mkdir_p(File.join(dir, "build"))
          File.write(File.join(dir, "build", "out.o"), "obj")

          entries = CopyIgnored.list_ignored_entries(dir).to_h
          entries["ignored.txt"]?.should eq(false)
          entries["build"]?.should eq(true)
          entries.has_key?("tracked.txt").should be_false
        end
      end
    end
  end
end

private def git(dir : String, *args : String)
  output = IO::Memory.new
  error = IO::Memory.new
  status = Process.run("git", args.to_a, chdir: dir, output: output, error: error)
  unless status.success?
    raise "git #{args.join(' ')} failed (exit #{status.exit_code}): #{error.to_s.strip}"
  end
end

private def with_tmp_dir(&)
  dir = File.tempname("wt-copy-ignored")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
