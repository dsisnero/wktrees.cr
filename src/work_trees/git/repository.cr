# Repository — git repository operations.
#
# Ported from vendor/worktrunk/src/git/repository/mod.rs
#
# Repository discovers a git repo from a path and provides methods for
# running git commands in the repository context. WorkingTree wraps
# per-worktree operations.

require "../cmd"

module WorkTrees
  module Git
    # A git repository, discovered from a filesystem path.
    #
    # Cloning a Repository shares the same underlying discovery data.
    class Repository
      getter discovery_path : String
      getter git_common_dir : String

      # Discover the repository from the current working directory.
      def self.current : self
        at(Dir.current)
      end

      # Discover the repository from the specified path.
      def self.at(path : String) : self
        discovery = resolve_git_dir(path)
        common_dir = run_git_check(path, ["rev-parse", "--git-common-dir"])
        new(discovery, common_dir)
      end

      def initialize(@discovery_path : String, @git_common_dir : String)
      end

      # Run a git command in the repository context and return stdout.
      def run_command(args : Array(String)) : String
        result = Cmd.new("git")
          .args(args)
          .current_dir(@discovery_path)
          .context("repo")
          .run!

        result.stdout.strip
      end

      # Run a git command and return true if it succeeds, false otherwise.
      def run_command_check(args : Array(String)) : Bool
        result = Cmd.new("git")
          .args(args)
          .current_dir(@discovery_path)
          .context("repo")
          .run
        result.success?
      end

      # Get a WorkingTree for the given path.
      def worktree_at(path : String) : WorkingTree
        WorkingTree.new(path, self)
      end

      # Get the current worktree (from the discovery path).
      def current_worktree : WorkingTree
        worktree_at(@discovery_path)
      end

      # Determine the default branch name.
      def default_branch : String
        # Try local first: git symbolic-ref refs/remotes/origin/HEAD
        result = Cmd.new("git")
          .args(["symbolic-ref", "refs/remotes/origin/HEAD"])
          .current_dir(@discovery_path)
          .run
        if result.success?
          result.stdout.strip.sub("refs/remotes/origin/", "")
        else
          # Fallback: try main then master
          if run_command_check(["rev-parse", "--verify", "refs/heads/main"])
            "main"
          else
            "master"
          end
        end
      end

      # Resolve the git directory from a path.
      private def self.resolve_git_dir(path : String) : String
        run_git_check(path, ["rev-parse", "--show-toplevel"])
      rescue
        path
      end

      # Run a git command and return the output, or raise.
      private def self.run_git_check(path : String, args : Array(String)) : String
        result = Cmd.new("git")
          .args(args)
          .current_dir(path)
          .run!
        result.stdout.strip
      end
    end

    # A working tree within a git repository.
    #
    # Port of `WorkingTree` from repository/working_tree.rs.
    class WorkingTree
      getter path : String
      getter repo : Repository

      def initialize(@path : String, @repo : Repository)
      end

      # Run a git command in this worktree's context.
      def run_command(args : Array(String)) : String
        Cmd.new("git")
          .args(args)
          .current_dir(@path)
          .context(worktree_name)
          .run!
          .stdout
          .strip
      end

      # Get the HEAD commit SHA (40-character hex).
      def head_sha : String
        run_command(["rev-parse", "HEAD"])
      end

      # Get the current branch name.
      def current_branch : String
        run_command(["rev-parse", "--abbrev-ref", "HEAD"])
      end

      # Get a human-readable worktree name (last path component).
      def worktree_name : String
        File.basename(@path)
      end
    end
  end
end
