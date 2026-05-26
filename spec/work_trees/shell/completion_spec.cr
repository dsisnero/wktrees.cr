require "../../spec_helper"

module WorkTrees
  describe "shell completions" do
    it "bash completions includes step subcommands" do
      result = Commands.bash_completions
      result.should contain("commit diff squash rebase push for-each eval prune")
      result.should contain("step_subs=")
    end

    it "bash completes top-level commands" do
      result = Commands.bash_completions
      result.should contain("list switch remove step merge hook config shell help")
    end
  end
end
