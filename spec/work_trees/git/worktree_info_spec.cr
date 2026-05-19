require "../../spec_helper"

describe WorkTrees::Git::WorktreeInfo do
  describe ".parse_porcelain_list" do
    it "parses a single worktree" do
      output = <<-PORCELAIN
      worktree /tmp/repo
      HEAD abcdef1234567890abcdef1234567890abcdef12
      branch refs/heads/main
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.size.should eq(1)
      wt = wts.first
      wt.path.should eq("/tmp/repo")
      wt.head.should eq("abcdef1234567890abcdef1234567890abcdef12")
      wt.branch.should eq("main")
      wt.bare?.should be_false
      wt.detached?.should be_false
    end

    it "parses multiple worktrees separated by blank lines" do
      output = <<-PORCELAIN
      worktree /tmp/repo
      HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      branch refs/heads/main

      worktree /tmp/repo.feature
      HEAD bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
      branch refs/heads/feature-x
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.size.should eq(2)
      wts[0].branch.should eq("main")
      wts[1].branch.should eq("feature-x")
    end

    it "detects bare worktrees" do
      output = <<-PORCELAIN
      worktree /tmp/bare
      HEAD 0000000000000000000000000000000000000000
      bare
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.size.should eq(1)
      wts.first.bare?.should be_true
    end

    it "detects detached HEAD" do
      output = <<-PORCELAIN
      worktree /tmp/repo
      HEAD cccccccccccccccccccccccccccccccccccccccc
      detached
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.size.should eq(1)
      wts.first.detached?.should be_true
      wts.first.branch.should be_nil
    end

    it "detects locked worktrees with reason" do
      output = <<-PORCELAIN
      worktree /tmp/repo
      HEAD dddddddddddddddddddddddddddddddddddddddd
      branch refs/heads/locked-branch
      locked reason: in use by another process
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.first.locked.should eq("reason: in use by another process")
    end

    it "detects prunable worktrees" do
      output = <<-PORCELAIN
      worktree /tmp/deleted
      HEAD eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
      branch refs/heads/old-feature
      prunable git worktree prune
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.first.prunable.should_not be_nil
      wts.first.prunable?.should be_true
    end

    it "handles empty output" do
      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list("")
      wts.should be_empty
    end

    it "strips refs/heads/ prefix from branch" do
      output = <<-PORCELAIN
      worktree /tmp/repo
      HEAD ffffffffffffffffffffffffffffffffffffffff
      branch refs/heads/nested/feature
      PORCELAIN

      wts = WorkTrees::Git::WorktreeInfo.parse_porcelain_list(output)
      wts.first.branch.should eq("nested/feature")
    end
  end

  describe "list_worktrees integration" do
    it "lists worktrees for the current repo" do
      repo = WorkTrees::Git::Repository.current
      wts = repo.list_worktrees
      wts.should_not be_empty
    end

    it "finds worktree by branch" do
      repo = WorkTrees::Git::Repository.current
      wts = repo.list_worktrees
      if branch = wts.first?.try(&.branch)
        path = repo.worktree_for_branch(branch)
        path.should_not be_nil
      end
    end
  end
end
