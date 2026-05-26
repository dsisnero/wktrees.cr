require "../../spec_helper"

module WorkTrees
  describe Git do
    describe "LineDiff" do
      it "is empty by default" do
        Git::LineDiff.new.empty?.should be_true
        Git::LineDiff.new(0, 0).empty?.should be_true
        Git::LineDiff.new(5, 0).empty?.should be_false
        Git::LineDiff.new(0, 5).empty?.should be_false
      end

      it "converts to tuple" do
        diff = Git::LineDiff.new(10, 5)
        diff.to_tuple.should eq({10, 5})
      end

      it "parses from shortstat" do
        output = " 5 files changed, 100 insertions(+), 50 deletions(-)"
        diff = Git::LineDiff.from_shortstat(output)
        diff.added.should eq(100)
        diff.deleted.should eq(50)
      end

      it "returns empty from empty shortstat" do
        diff = Git::LineDiff.from_shortstat("")
        diff.empty?.should be_true
      end
    end

    describe "parse_numstat_line" do
      it "parses basic numstat line" do
        result = Git.parse_numstat_line("10\t5\tfile.rs")
        result.should eq({10, 5})
      end

      it "parses insertions only" do
        result = Git.parse_numstat_line("15\t0\tfile.rs")
        result.should eq({15, 0})
      end

      it "parses deletions only" do
        result = Git.parse_numstat_line("0\t8\tfile.rs")
        result.should eq({0, 8})
      end

      it "returns nil for binary files" do
        Git.parse_numstat_line("-\t-\timage.png").should be_nil
      end

      it "handles graph prefix" do
        Git.parse_numstat_line("* | 11\t0\tCargo.toml").should eq({11, 0})
        Git.parse_numstat_line("| 17\t3\tsrc/main.rs").should eq({17, 3})
      end

      it "handles ANSI-colored graph lines" do
        ansi = "\e[31m|\e[m 11\t0\tCargo.toml"
        Git.parse_numstat_line(ansi).should eq({11, 0})
      end

      it "returns nil for non-numstat lines" do
        Git.parse_numstat_line("* abc1234 Fix bug").should be_nil
        Git.parse_numstat_line("").should be_nil
        Git.parse_numstat_line("regular text").should be_nil
      end
    end

    describe "parse_shortstat" do
      it "parses all parts" do
        result = Git.parse_shortstat(" 23 files changed, 624 insertions(+), 160 deletions(-)")
        result.should eq({23, 624, 160})
      end

      it "parses insertions only" do
        result = Git.parse_shortstat(" 1 file changed, 6 insertions(+)")
        result.should eq({1, 6, 0})
      end

      it "parses deletions only" do
        result = Git.parse_shortstat(" 2 files changed, 10 deletions(-)")
        result.should eq({2, 0, 10})
      end

      it "returns nil for empty input" do
        Git.parse_shortstat("").should be_nil
        Git.parse_shortstat("  ").should be_nil
      end

      it "parses singular file form" do
        result = Git.parse_shortstat(" 1 file changed, 1 insertion(+), 1 deletion(-)")
        result.should eq({1, 1, 1})
      end
    end

    describe "DiffStats" do
      it "format_summary is empty by default" do
        Git::DiffStats.new.format_summary.empty?.should be_true
      end

      it "format_summary shows all parts" do
        stats = Git::DiffStats.new(3, 45, 12)
        parts = stats.format_summary
        parts.join(", ").should contain("3 files")
        parts.join(", ").should contain("+45")
        parts.join(", ").should contain("-12")
      end

      it "format_summary shows single file" do
        stats = Git::DiffStats.new(1, 10, 0)
        parts = stats.format_summary
        parts.join(", ").should contain("1 file")
        parts.join(", ").should contain("+10")
      end

      it "parses from shortstat" do
        stats = Git::DiffStats.from_shortstat(" 3 files changed, 45 insertions(+), 12 deletions(-)")
        stats.files.should eq(3)
        stats.insertions.should eq(45)
        stats.deletions.should eq(12)
      end

      it "returns empty from empty shortstat" do
        stats = Git::DiffStats.from_shortstat("")
        stats.files.should eq(0)
        stats.insertions.should eq(0)
        stats.deletions.should eq(0)
      end
    end
  end
end
