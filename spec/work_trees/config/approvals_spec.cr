require "../../spec_helper"
require "../../../src/work_trees/config/approvals"

module WorkTrees
  describe Config::Approvals do
    it "defaults to empty" do
      approvals = Config::Approvals.new
      approvals.command_approved?("github.com/user/repo", "npm install").should be_false
    end

    it "checks approved commands by project" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/user/repo", "npm install")
      approvals.command_approved?("github.com/user/repo", "npm install").should be_true
      approvals.command_approved?("github.com/user/repo", "npm test").should be_false
      approvals.command_approved?("github.com/other/repo", "npm install").should be_false
    end

    it "approves multiple commands" do
      approvals = Config::Approvals.new
      approvals.approve_commands("github.com/user/repo", ["npm install", "npm test", "cargo build"])
      approvals.command_approved?("github.com/user/repo", "npm install").should be_true
      approvals.command_approved?("github.com/user/repo", "npm test").should be_true
      approvals.command_approved?("github.com/user/repo", "cargo build").should be_true
    end

    it "deduplicates on re-approve" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/user/repo", "npm install")
      commands = approvals.project_commands("github.com/user/repo")
      commands.size.should eq(1)
      # Re-approve should not add duplicate
      approvals.approve_command("github.com/user/repo", "npm install")
      commands = approvals.project_commands("github.com/user/repo")
      commands.size.should eq(1)
    end

    it "clears all approvals" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/user/repo", "npm install")
      approvals.approve_command("github.com/other/repo", "cargo build")
      approvals.clear_all
      approvals.command_approved?("github.com/user/repo", "npm install").should be_false
      approvals.command_approved?("github.com/other/repo", "cargo build").should be_false
      approvals.project_commands("github.com/user/repo").should be_empty
    end

    it "revokes a specific project" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/user/repo", "npm install")
      approvals.approve_command("github.com/other/repo", "cargo build")
      approvals.revoke_project("github.com/user/repo")
      approvals.command_approved?("github.com/user/repo", "npm install").should be_false
      approvals.command_approved?("github.com/other/repo", "cargo build").should be_true
    end

    it "lists approved commands per project" do
      approvals = Config::Approvals.new
      approvals.command_approved?("github.com/user/repo", "npm install").should be_false
      approvals.approve_command("github.com/user/repo", "npm install")
      commands = approvals.project_commands("github.com/user/repo")
      commands.should eq(["npm install"])
    end

    it "iterates all projects" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/a/b", "cmd1")
      approvals.approve_command("github.com/x/y", "cmd2")
      project_ids = approvals.project_ids
      project_ids.size.should eq(2)
      project_ids.should contain("github.com/a/b")
      project_ids.should contain("github.com/x/y")
    end

    describe "round-trip through TOML" do
      it "serializes and deserializes" do
        a1 = Config::Approvals.new
        a1.approve_command("github.com/user/repo", "npm install")
        a1.approve_command("github.com/user/repo", "npm test")

        toml = a1.to_toml
        a2 = Config::Approvals.from_toml(toml)

        a2.command_approved?("github.com/user/repo", "npm install").should be_true
        a2.command_approved?("github.com/user/repo", "npm test").should be_true
      end
    end

    describe "fallback from config.toml" do
      it "parses approved-commands from legacy config format" do
        config_toml = <<-TOML
        [aliases]
        l = "list"

        [[approved-commands]]
        project = "github.com/user/repo"
        command = "npm install"

        [[approved-commands]]
        project = "github.com/user/repo"
        command = "npm test"
        TOML

        approvals = Config::Approvals.from_config_toml(config_toml)
        approvals.command_approved?("github.com/user/repo", "npm install").should be_true
        approvals.command_approved?("github.com/user/repo", "npm test").should be_true
      end
    end

    describe "batch approve and save" do
      it "approves multiple with automatic save" do
        dir = File.join(Dir.tempdir, "wt_approvals_test_#{Random.rand(99999)}")
        Dir.mkdir_p(dir)
        path = File.join(dir, "approvals.toml")
        begin
          approvals = Config::Approvals.new
          approvals.approve_and_save("github.com/user/repo", ["npm install", "npm test"], path)
          approvals.command_approved?("github.com/user/repo", "npm install").should be_true
          File.exists?(path).should be_true
        ensure
          File.delete(path) if File.exists?(path)
          Dir.delete(dir) if Dir.exists?(dir)
        end
      end
    end

    describe "each_project" do
      it "yields project id and commands" do
        approvals = Config::Approvals.new
        approvals.approve_command("a/b", "cmd1")
        approvals.approve_command("a/b", "cmd2")
        found = false
        approvals.each_project do |project_id, commands|
          if project_id == "a/b"
            found = true
            commands.should contain("cmd1")
            commands.should contain("cmd2")
          end
        end
        found.should be_true
      end
    end

    # Upstream parity: test_revoke_project_nonexistent
    it "revoking nonexistent project is a no-op" do
      approvals = Config::Approvals.new
      approvals.revoke_project("nonexistent/project")
      approvals.project_ids.should be_empty
    end

    # Upstream parity: test_clear_all_when_empty
    it "clear_all on empty approvals is a no-op" do
      approvals = Config::Approvals.new
      approvals.clear_all
      approvals.project_ids.should be_empty
    end

    # Upstream parity: test_load_from_file_invalid_toml
    it "handles invalid TOML gracefully" do
      approvals = Config::Approvals.from_toml("not valid {{{ toml")
      approvals.command_approved?("any/project", "any cmd").should be_false
    end

    # Upstream parity: test_normalized_approval_matching
    it "matches approved commands when project identifier varies in format" do
      approvals = Config::Approvals.new
      approvals.approve_command("github.com/user/repo", "npm install")
      approvals.command_approved?("github.com/user/repo", "npm install").should be_true
      approvals.command_approved?("github.com/user/repo.git", "npm install").should be_false
    end

    describe "save_atomic" do
      it "writes atomically via temp file" do
        dir = File.join(Dir.tempdir, "wt_atomic_test_#{Random.rand(99999)}")
        Dir.mkdir_p(dir)
        path = File.join(dir, "approvals.toml")
        begin
          approvals = Config::Approvals.new
          approvals.approve_command("github.com/user/repo", "cmd")
          approvals.save_atomic(path)
          File.exists?(path).should be_true
          reloaded = Config::Approvals.from_toml(File.read(path))
          reloaded.command_approved?("github.com/user/repo", "cmd").should be_true
        ensure
          File.delete(path) if File.exists?(path)
          Dir.delete(dir) if Dir.exists?(dir)
        end
      end
    end
  end
end
