require "../../spec_helper"

describe WorkTrees::Git::Repository do
  it "discovers repo from current working directory" do
    repo = WorkTrees::Git::Repository.current
    repo.git_common_dir.should_not be_nil
    repo.git_common_dir.should end_with(".git")
  end

  it "discovers repo from explicit path" do
    repo = WorkTrees::Git::Repository.at(Dir.current)
    repo.discovery_path.should eq(Dir.current)
  end

  it "runs a git command in repo context" do
    repo = WorkTrees::Git::Repository.current
    output = repo.run_command(["rev-parse", "--git-common-dir"])
    output.should contain(".git")
  end

  it "runs a git command with check (boolean return)" do
    repo = WorkTrees::Git::Repository.current
    result = repo.run_command_check(["rev-parse", "--is-inside-work-tree"])
    result.should be_true
  end

  it "provides worktree at current path" do
    repo = WorkTrees::Git::Repository.current
    wt = repo.worktree_at(Dir.current)
    wt.should_not be_nil
  end

  it "fetches default branch" do
    repo = WorkTrees::Git::Repository.current
    branch = repo.default_branch
    branch.should_not be_empty
  end
end

describe WorkTrees::Git::WorkingTree do
  it "runs a git command in worktree context" do
    repo = WorkTrees::Git::Repository.current
    wt = repo.worktree_at(Dir.current)
    output = wt.not_nil!.run_command(["rev-parse", "--abbrev-ref", "HEAD"])
    output.strip.should_not be_empty
  end

  it "gets HEAD SHA" do
    repo = WorkTrees::Git::Repository.current
    wt = repo.worktree_at(Dir.current)
    sha = wt.not_nil!.head_sha
    sha.size.should eq(40)
    sha.should match(/^[0-9a-f]{40}$/)
  end

  it "gets current branch name" do
    repo = WorkTrees::Git::Repository.current
    wt = repo.worktree_at(Dir.current)
    branch = wt.not_nil!.current_branch
    branch.should_not be_empty
  end
end
