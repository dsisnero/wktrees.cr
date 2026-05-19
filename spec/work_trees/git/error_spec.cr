require "../../spec_helper"

describe WorkTrees::Git::CommandError do
  it "constructs from program and args" do
    err = WorkTrees::Git::CommandError.new(
      program: "git",
      args: ["status", "--porcelain"],
      stderr: "fatal: not a git repository",
      stdout: "",
      exit_code: 128
    )
    err.program.should eq("git")
    err.args.should eq(["status", "--porcelain"])
    err.stderr.should eq("fatal: not a git repository")
    err.exit_code.should eq(128)
  end

  it "reconstructs command string" do
    err = WorkTrees::Git::CommandError.new(
      program: "gh",
      args: ["pr", "list"],
      stderr: "",
      stdout: "",
      exit_code: 1
    )
    err.command_string.should eq("gh pr list")
  end

  it "has short single-line display" do
    err = WorkTrees::Git::CommandError.new(
      program: "git",
      args: ["worktree", "list"],
      stderr: "error message",
      stdout: "",
      exit_code: 128
    )
    err.to_s.should eq("git worktree list failed (exit 128)")
  end

  it "shows display without exit code when killed by signal" do
    err = WorkTrees::Git::CommandError.new(
      program: "git",
      args: [] of String,
      stderr: "",
      stdout: "",
      exit_code: nil
    )
    err.to_s.should eq("git failed")
  end

  it "combines stderr and stdout output" do
    err = WorkTrees::Git::CommandError.new(
      program: "git",
      args: [] of String,
      stderr: "error: failed\n",
      stdout: "some output\n",
      exit_code: 1
    )
    err.combined_output.should eq("error: failed\nsome output")
  end
end

describe WorkTrees::Git::RefType do
  it "provides symbol for PR" do
    WorkTrees::Git::RefType::Pr.symbol.should eq("#")
  end

  it "provides symbol for MR" do
    WorkTrees::Git::RefType::Mr.symbol.should eq("!")
  end

  it "provides name for PR" do
    WorkTrees::Git::RefType::Pr.name.should eq("PR")
  end

  it "formats display string" do
    WorkTrees::Git::RefType::Pr.display(42).should eq("PR #42")
    WorkTrees::Git::RefType::Mr.display(7).should eq("MR !7")
  end
end

describe WorkTrees::Git::GitError do
  it "has short single-line display for BranchNotFound" do
    err = WorkTrees::Git::BranchNotFound.new("feature-x", true, nil, nil)
    err.to_s.should contain("feature-x")
  end

  it "has short single-line display for DetachedHead" do
    err = WorkTrees::Git::DetachedHead.new("merge")
    err.to_s.should contain("detached")
  end

  it "has short single-line display for UncommittedChanges" do
    err = WorkTrees::Git::UncommittedChanges.new("remove", "feature-auth", false, [] of String)
    err.to_s.should contain("feature-auth")
    err.to_s.should contain("uncommitted")
  end
end

describe WorkTrees::Git::WorktrunkError do
  it "provides exit code for AlreadyDisplayed" do
    err = WorkTrees::Git::AlreadyDisplayed.new(130)
    err.exit_code.should eq(130)
  end

  it "provides exit code for ChildProcessExited" do
    err = WorkTrees::Git::ChildProcessExited.new("git", 130, 2)
    err.exit_code.should eq(130)
  end
end
