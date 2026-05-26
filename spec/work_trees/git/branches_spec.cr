require "../../spec_helper"

module WorkTrees
  describe Git::Branches do
    describe "parse_local_branch_line" do
      it "parses all fields" do
        sep = '\0'
        line = ["feature", "abc123def", "1718273932", "origin/feature", ""].join(sep)
        branch = Git::Branches.parse_local_branch_line(line)
        branch.should_not be_nil
        b = branch.not_nil!
        b.name.should eq("feature")
        b.commit_sha.should eq("abc123def")
        b.committer_ts.should eq(1718273932)
        b.upstream_short.should eq("origin/feature")
      end

      it "returns nil for empty upstream (no tracking)" do
        sep = '\0'
        line = ["feature", "abc123def", "1718273932", "", ""].join(sep)
        branch = Git::Branches.parse_local_branch_line(line)
        b = branch.not_nil!
        b.upstream_short.should be_nil
      end

      it "returns nil for [gone] upstream" do
        sep = '\0'
        line = ["feature", "abc123def", "1718273932", "origin/feature", "[gone]"].join(sep)
        branch = Git::Branches.parse_local_branch_line(line)
        b = branch.not_nil!
        b.upstream_short.should be_nil
      end

      it "returns nil for malformed lines" do
        Git::Branches.parse_local_branch_line("bad").should be_nil
        Git::Branches.parse_local_branch_line("").should be_nil
      end
    end

    describe "parse_remote_branch_line" do
      it "parses all fields" do
        sep = '\0'
        line = ["origin/feature", "abc123", "1718273932"].join(sep)
        branch = Git::Branches.parse_remote_branch_line(line)
        branch.should_not be_nil
        b = branch.not_nil!
        b.short_name.should eq("origin/feature")
        b.commit_sha.should eq("abc123")
        b.committer_ts.should eq(1718273932)
        b.remote_name.should eq("origin")
        b.local_name.should eq("feature")
      end

      it "skips HEAD symref" do
        sep = '\0'
        line = ["origin/HEAD", "abc123", "1718273932"].join(sep)
        Git::Branches.parse_remote_branch_line(line).should be_nil
      end

      it "returns nil for malformed lines" do
        Git::Branches.parse_remote_branch_line("bad").should be_nil
      end
    end

    describe "LocalBranchInventory" do
      it "builds from branch list with O(1) lookup" do
        b1 = Git::LocalBranch.new("main", "aaa", 1718273930, nil)
        b2 = Git::LocalBranch.new("feature", "bbb", 1718273932, "origin/feature")
        inv = Git::Branches::LocalBranchInventory.new([b1, b2])
        inv.entries.size.should eq(2)
        inv.get("main").try(&.name).should eq("main")
        inv.get("feature").try(&.name).should eq("feature")
        inv.get("absent").should be_nil
      end
    end
  end
end
