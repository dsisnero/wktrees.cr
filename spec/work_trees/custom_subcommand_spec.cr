require "../spec_helper"

module WorkTrees
  describe "Custom subcommand" do
    describe "find_on_path" do
      it "finds a known executable on PATH" do
        result = WorkTrees::CLI.find_on_path("sh")
        result.should_not be_nil
        result.try(&.should contain("sh"))
      end

      it "returns nil for nonexistent command" do
        WorkTrees::CLI.find_on_path("nonexistent_cmd_xyz_12345").should be_nil
      end

      it "finds wktrees binary itself" do
        WorkTrees::CLI.find_on_path("wktrees")
        true
      end
    end
  end
end
