# Integration detection for safe branch operations.
# Ported from vendor/worktrunk/src/git/repository/integration.rs
#
# Checks whether a branch is fully integrated (merged) into a target branch.
# Used by 'remove' to safely delete branches and by 'merge' to detect completion.
#
# Detection levels (ordered by cost, cheapest first):
#   1. SameCommit — identical HEAD SHAs
#   2. Ancestor — merge-base --is-ancestor check
#   3. TreeMatch — identical tree SHAs
#   4. NoDiff — empty diff between branches

require "./repository"

module WorkTrees
  module Git
    module Integration
      # Reason why a branch is considered integrated.
      enum Reason
        SameCommit
        Ancestor
        TreeMatch
        NoDiff

        def to_s(io : IO) : Nil
          case self
          in .same_commit? then io << "same commit"
          in .ancestor?    then io << "ancestor"
          in .tree_match?  then io << "identical tree"
          in .no_diff?     then io << "no diff"
          end
        end
      end

      # Check if `branch` is fully integrated into `target`.
      # Returns true if the branch can be safely deleted.
      def self.check(repo : Repository, branch : String, target : String) : Bool
        !reason(repo, branch, target).nil?
      end

      # Return the reason why `branch` is integrated into `target`, or nil.
      def self.reason(repo : Repository, branch : String, target : String) : Reason?
        # Level 1: Same commit
        branch_sha = branch_sha(repo, branch)
        target_sha = branch_sha(repo, target)
        if branch_sha && target_sha && branch_sha == target_sha
          return Reason::SameCommit
        end

        # Level 2: Ancestor check
        if repo.run_command_check(["merge-base", "--is-ancestor", branch, target])
          return Reason::Ancestor
        end

        # Level 3: Tree match
        if trees_match?(repo, branch, target)
          return Reason::TreeMatch
        end

        # Level 4: Empty diff
        if no_diff?(repo, branch, target)
          return Reason::NoDiff
        end

        nil
      end

      # Get the SHA for a branch, returning nil if it doesn't exist.
      private def self.branch_sha(repo, branch) : String?
        result = Cmd.new("git")
          .args(["rev-parse", "--verify", "refs/heads/#{branch}"])
          .run
        result.success? ? result.stdout.strip : nil
      end

      # Check if two branches have identical tree SHAs.
      private def self.trees_match?(repo, branch, target) : Bool
        b_tree = tree_sha(repo, branch)
        return false unless b_tree
        t_tree = tree_sha(repo, target)
        return false unless t_tree
        b_tree == t_tree
      end

      private def self.tree_sha(repo, ref) : String?
        result = Cmd.new("git")
          .args(["rev-parse", "#{ref}^{tree}"])
          .run
        result.success? ? result.stdout.strip : nil
      end

      # Check if diff between branches is empty.
      private def self.no_diff?(repo, branch, target) : Bool
        repo.run_command_check(["diff", "--quiet", "#{target}...#{branch}"])
      end
    end
  end
end
