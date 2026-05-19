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
end
