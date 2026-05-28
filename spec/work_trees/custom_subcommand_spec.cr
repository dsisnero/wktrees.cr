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
    end

    describe "find_plugin" do
      it "finds executable in .work_trees/bin/ before PATH" do
        # Create a project-local plugin dir with a test executable
        dir = File.join(Dir.current, ".work_trees", "bin")
        Dir.mkdir_p(dir)
        plugin_path = File.join(dir, "wktrees-hello")
        begin
          File.write(plugin_path, "#!/bin/sh\necho hello\n")
          File.chmod(plugin_path, 0o755)
          result = WorkTrees::CLI.find_plugin("hello")
          result.should_not be_nil
          result.try(&.should contain(".work_trees/bin/wktrees-hello"))
        ensure
          File.delete(plugin_path) if File.exists?(plugin_path)
          Dir.delete(dir) if Dir.exists?(dir)
        end
      end

      it "prefers .work_trees/bin/ over PATH" do
        dir = File.join(Dir.current, ".work_trees", "bin")
        Dir.mkdir_p(dir)
        plugin_path = File.join(dir, "wktrees-testlocal")
        begin
          File.write(plugin_path, "#!/bin/sh\necho local\n")
          File.chmod(plugin_path, 0o755)
          result = WorkTrees::CLI.find_plugin("testlocal")
          result.should_not be_nil
          result.try(&.should contain(".work_trees/bin"))
        ensure
          File.delete(plugin_path) if File.exists?(plugin_path)
          Dir.delete(dir) if Dir.exists?(dir)
        end
      end
    end
  end
end
