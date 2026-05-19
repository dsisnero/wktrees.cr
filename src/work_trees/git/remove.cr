# Worktree removal and branch deletion operations.
# Ported from vendor/worktrunk/src/git/remove.rs

require "./repository"

module WorkTrees
  module Git
    # How the branch should be handled after worktree removal.
    enum BranchDeletionMode
      Keep        # Never delete the branch
      SafeDelete  # Delete only if integrated (default)
      ForceDelete # Delete even if not merged (-D)
    end

    class Repository
      # Remove a worktree at the given path.
      # When force is true, uses --force to bypass dirty checks.
      def remove_worktree(path : String, force : Bool = false) : Nil
        args = ["worktree", "remove"]
        args << "--force" if force
        args << path
        run_command(args)
      end

      # Delete a branch, optionally with force.
      def delete_branch(branch : String, mode : BranchDeletionMode = :safe_delete) : Nil
        case mode
        in .keep?
          # Do nothing
          return
        in .safe_delete?
          args = ["branch", "-d", branch]
        in .force_delete?
          args = ["branch", "-D", branch]
        end
        run_command(args)
      rescue ex : CommandError
        raise ex
      end

      # Prune stale worktree entries.
      def prune_worktrees : Nil
        run_command(["worktree", "prune"])
      rescue CommandError
        # Ignore prune errors (no stale entries is not an error)
      end
    end
  end
end
