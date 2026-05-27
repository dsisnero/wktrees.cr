require "../../spec_helper"

describe WorkTrees::Shell do
  describe ".generate" do
    it "generates bash wrapper" do
      result = WorkTrees::Shell.generate(:bash, "wt")
      result.should contain("wt()")
      result.should contain("command wt")
      result.should contain("wktrees shell integration for bash")
    end

    it "generates zsh wrapper" do
      result = WorkTrees::Shell.generate(:zsh, "wt")
      result.should contain("wt()")
      result.should contain("command wt")
      result.should contain("wktrees shell integration for zsh")
    end

    it "generates fish wrapper" do
      result = WorkTrees::Shell.generate(:fish, "wt")
      result.should contain("function wt")
      result.should contain("command wt")
      result.should contain("wktrees shell integration for fish")
    end

    it "generates nushell wrapper" do
      result = WorkTrees::Shell.generate(:nu, "wt")
      result.should contain("def --env --wrapped wt")
      result.should contain("wktrees shell integration for nu")
    end

    it "generates powershell wrapper" do
      result = WorkTrees::Shell.generate(:ps, "wt")
      result.should contain("function Invoke-wt")
      result.should contain("Set-Alias")
    end

    it "uses custom command name" do
      result = WorkTrees::Shell.generate(:bash, "work_trees")
      result.should contain("work_trees()")
    end

    it "rejects truly unsupported shells" do
      expect_raises(Exception) do
        WorkTrees::Shell.generate(:unknown_shell)
      end
    end
  end
end
