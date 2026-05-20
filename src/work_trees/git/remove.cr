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

      # Stage a worktree for fast removal: rename to trash, then remove in background.
      # Returns immediately — the actual deletion happens asynchronously.
      def stage_worktree_removal(path : String, force : Bool = false) : Nil
        trash_dir = File.join(@git_common_dir, "wt", "trash")
        Dir.mkdir_p(trash_dir) unless Dir.exists?(trash_dir)

        name = File.basename(path)
        ts = Time.utc.to_unix
        staged = File.join(trash_dir, "#{name}-#{ts}")

        # Fast: rename to trash (same filesystem = instant)
        begin
          File.rename(path, staged)
        rescue File::Error
          # Cross-device or permission error — fall back to direct removal
          remove_worktree(path, force)
          return
        end

        # Background: actually remove the directory
        spawn do
          if force
            # Force remove: just delete the trash
            rm_rf(staged)
          else
            # Try git worktree remove, fall back to rm
            Cmd.new("git").args(["worktree", "remove", staged]).run
            rm_rf(staged) if Dir.exists?(staged)
          end
        end
      end

      # Recursively remove a directory tree.
      private def rm_rf(path : String) : Nil
        if Dir.exists?(path)
          Dir.children(path).each do |child|
            child_path = File.join(path, child)
            if File.directory?(child_path)
              rm_rf(child_path)
            else
              File.delete(child_path) rescue nil
            end
          end
          Dir.delete(path) rescue nil
        end
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
