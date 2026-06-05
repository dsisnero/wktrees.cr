require "../spec_helper"

describe WorkTrees::Cmd do
  it "constructs command string" do
    cmd = WorkTrees::Cmd.new("git").args(["status", "--porcelain"])
    cmd.command_string.should eq("git status --porcelain")
  end

  it "runs a simple command successfully" do
    result = WorkTrees::Cmd.new("echo").arg("hello").run
    result.success?.should be_true
    result.stdout.strip.should eq("hello")
    result.exit_code.should eq(0)
  end

  it "captures stderr" do
    # Use a command that writes to stderr
    result = WorkTrees::Cmd.new("sh").args(["-c", "echo error >&2"]).run
    result.stdout.strip.should eq("")
    result.stderr.strip.should eq("error")
  end

  it "detects command failure" do
    result = WorkTrees::Cmd.new("false").run
    result.success?.should be_false
    result.exit_code.should_not eq(0)
  end

  it "run! raises on failure" do
    expect_raises(WorkTrees::CmdError) do
      WorkTrees::Cmd.new("false").run!
    end
  end

  it "run! succeeds for valid commands" do
    result = WorkTrees::Cmd.new("true").run!
    result.success?.should be_true
  end

  it "sets working directory" do
    result = WorkTrees::Cmd.new("pwd").current_dir("/tmp").run
    # macOS resolves /tmp -> /private/tmp
    result.stdout.strip.should match(/\/tmp$/)
  end

  it "supports stdin_data from string" do
    result = WorkTrees::Cmd.new("cat").stdin_data("hello stdin").run
    result.stdout.should eq("hello stdin")
  end

  it "supports method chaining" do
    result = WorkTrees::Cmd.new("echo").arg("-n").arg("chained").run
    result.stdout.should eq("chained")
  end

  it "empty args produces program-only command string" do
    cmd = WorkTrees::Cmd.new("git")
    cmd.command_string.should eq("git")
  end

  it "handles context label for logging" do
    cmd = WorkTrees::Cmd.new("git").args(["status", "--porcelain"]).context("feature-auth")
    cmd.command_string.should eq("git status --porcelain")
  end

  it "run! raises CmdError with exit code on failure" do
    begin
      WorkTrees::Cmd.new("sh").args(["-c", "exit 42"]).run!
      fail "Expected CmdError"
    rescue ex : WorkTrees::CmdError
      ex.exit_code.should eq(42)
      ex.program.should eq("sh")
    end
  end

  it "CmdResult.success? is true for exit code 0" do
    result = WorkTrees::Cmd.new("true").run
    result.success?.should be_true
    result.exit_code.should eq(0)
  end

  it "CmdResult.success? is false for non-zero exit" do
    result = WorkTrees::Cmd.new("sh").args(["-c", "exit 1"]).run
    result.success?.should be_false
    result.exit_code.should eq(1)
  end

  it "handles command not found gracefully" do
    result = WorkTrees::Cmd.new("nonexistent_command_xyz_12345").run
    result.success?.should be_false
    result.stderr.should_not be_empty
  end

  # Upstream parity: exit_code must not raise on command-not-found
  it "exit_code returns 127 for command not found" do
    result = WorkTrees::Cmd.new("nonexistent_command_xyz_12345").run
    result.success?.should be_false
    result.exit_code.should eq(127)
  end
end
