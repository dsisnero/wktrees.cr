require "../spec_helper"

module WorkTrees
  describe "Branch summary generation" do
    describe "build_summary_prompt" do
      it "formats a summary prompt with diff" do
        diff = "diff --git a/x b/x\n+add\n-delete"
        prompt = Commands.build_summary_prompt(diff)
        prompt.should contain("branch")
        prompt.should contain("diff")
        prompt.should contain(diff)
      end

      it "returns empty string for empty diff" do
        Commands.build_summary_prompt("").should eq("")
      end
    end

    describe "summary prompt content" do
      it "asks for subject+body format" do
        prompt = Commands.build_summary_prompt("test diff")
        prompt.should contain("subject")
        prompt.should contain("body")
      end

      it "requests one-line subject" do
        prompt = Commands.build_summary_prompt("test diff")
        prompt.should contain("one sentence")
      end
    end
  end
end
