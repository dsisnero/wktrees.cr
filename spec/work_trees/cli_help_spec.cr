require "../spec_helper"

module WorkTrees
  # Compiled binary path
  BIN = "/Volumes/extreme_ssd/repos/github.com/dsisnero/work_trees/bin/wktrees"

  # Helper to run the compiled binary and capture output
  def self.run_bin(args : Array(String))
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(BIN, args, output: output, error: error)
    {status.exit_code, output.to_s, error.to_s}
  end

  describe "CLI help" do
    describe "global --help" do
      it "shows usage with --help" do
        code, stdout, _ = run_bin(["--help"])
        code.should eq(0)
        stdout.should contain("wktrees")
        stdout.should contain("list")
      end

      it "shows usage with -h" do
        code, stdout, _ = run_bin(["-h"])
        code.should eq(0)
        stdout.should contain("wktrees")
      end
    end

    describe "top-level subcommands" do
      {
        "list"   => ["list"],
        "switch" => ["switch"],
        "remove" => ["remove"],
        "merge"  => ["merge"],
        "config" => ["config"],
        "hook"   => ["hook"],
        "step"   => ["step"],
        "shell"  => ["shell"],
      }.each do |name, _|
        it "#{name} --help shows help" do
          code, stdout, _ = run_bin([name, "--help"])
          code.should eq(0)
          stdout.should contain("Usage:")
        end
      end
    end

    describe "step subcommands" do
      step_subs = [
        "commit", "diff", "squash", "rebase", "push",
        "for-each", "eval", "prune", "copy-ignored", "promote",
        "relocate", "tether", "statusline",
      ]

      step_subs.each do |sub|
        it "step #{sub} --help shows help" do
          code, stdout, _ = run_bin(["step", sub, "--help"])
          code.should eq(0)
          stdout.should contain("#{sub}")
        end
      end
    end

    describe "sub-subcommands" do
      it "config state --help shows help" do
        code, stdout, _ = run_bin(["config", "state", "--help"])
        code.should eq(0)
        stdout.should contain("Usage")
      end

      it "hook run --help shows help" do
        code, stdout, _ = run_bin(["hook", "run", "--help"])
        code.should eq(0)
        stdout.should contain("Usage")
      end
    end

    describe "upstream parity" do
      all = [
        ["list"],
        ["switch"],
        ["remove"],
        ["merge"],
        ["config"],
        ["hook"],
        ["step"],
        ["shell"],
        ["step", "commit"],
        ["step", "diff"],
        ["step", "squash"],
        ["step", "rebase"],
        ["step", "push"],
        ["step", "for-each"],
        ["step", "eval"],
        ["step", "prune"],
        ["step", "copy-ignored"],
        ["step", "promote"],
        ["step", "relocate"],
        ["step", "tether"],
        ["step", "statusline"],
      ]

      all.each do |subcommand|
        label = subcommand.join(" ")
        it "#{label} --help exits 0" do
          args = subcommand + ["--help"]
          code, _, _ = run_bin(args)
          code.should eq(0), "Expected #{label} --help to exit 0, got #{code}"
        end
      end
    end
  end
end
