# Branch name resolution for switch command shortcuts.
# Ported from vendor/worktrunk/src/commands/worktree/resolve.rs

require "./repository"

module WorkTrees
  module Git
    module BranchResolver
      # Shortcut patterns
      SHORTCUT_DEFAULT  = "^"
      SHORTCUT_PREVIOUS = "-"
      SHORTCUT_CURRENT  = "@"
      PR_PREFIX         = "pr:"
      MR_PREFIX         = "mr:"

      # Resolve a branch argument to its canonical form.
      #
      # Shortcuts:
      #   ^       → default branch (main/master)
      #   @       → current branch
      #   -       → previous branch (reads git config worktrees.previous-branch)
      #   pr:N    → GitHub PR branch (via gh CLI)
      #   mr:N    → GitLab MR branch (via glab CLI)
      #
      # Returns the resolved branch name, or the original string if no shortcut matches.
      def self.resolve(input : String) : String
        case input
        when SHORTCUT_DEFAULT
          repo = Repository.current
          repo.default_branch
        when SHORTCUT_CURRENT
          repo = Repository.current
          repo.current_worktree.current_branch
        when SHORTCUT_PREVIOUS
          resolve_previous
        when .starts_with?(PR_PREFIX)
          resolve_pr(input)
        when .starts_with?(MR_PREFIX)
          resolve_mr(input)
        else
          input
        end
      end

      # Resolve pr:N to branch name using gh CLI, and fetch if needed.
      private def self.resolve_pr(input : String) : String
        number = input.lchop(PR_PREFIX)
        num = number.to_u32? || raise("Invalid PR number: #{number}")

        repo = Repository.current

        # Try fetching full PR metadata via gh api
        if info = PrResolver.fetch_pr_info(num, repo)
          branch = if info.cross_repo?
                     info.prefixed_branch_name || info.source_branch
                   else
                     info.source_branch
                   end

          if info.cross_repo?
            fetch_fork_pr(num, branch, repo)
          else
            fetch_same_repo_pr(info.source_branch, repo)
          end

          return branch
        end

        # Fallback: basic gh pr view
        branch = resolve_pr_fallback(number)
        branch || input
      end

      # Resolve mr:N to branch name using glab CLI.
      private def self.resolve_mr(input : String) : String
        number = input.lchop(MR_PREFIX)
        result = Cmd.new("glab")
          .args(["mr", "view", number, "--json", "sourceBranch", "--jq", ".sourceBranch"])
          .run
        if result.success? && !result.stdout.strip.empty?
          branch = result.stdout.strip
          ensure_branch_exists(branch)
          branch
        else
          input
        end
      end

      # Ensure a branch exists locally, fetching from remote if needed.
      private def self.ensure_branch_exists(branch : String) : Nil
        repo = Repository.current
        return if repo.run_command_check(["rev-parse", "--verify", "refs/heads/#{branch}"])
        # Try to fetch from origin
        Cmd.new("git")
          .args(["fetch", "origin", "#{branch}:#{branch}"])
          .run
      end

      # Save the current branch as the previous branch.
      def self.save_previous(branch : String) : Nil
        Cmd.new("git")
          .args(["config", "--local", "worktrees.previous-branch", branch])
          .run
      end

      # Resolve the - shortcut to the previous branch.
      private def self.resolve_previous : String
        result = Cmd.new("git")
          .args(["config", "--local", "worktrees.previous-branch"])
          .run
        if result.success? && !result.stdout.strip.empty?
          result.stdout.strip
        else
          repo = Repository.current
          repo.default_branch
        end
      end

      # Fetch a same-repo PR branch with explicit refspec.
      private def self.fetch_same_repo_pr(branch : String, repo : Repository) : Nil
        remote = find_origin_remote(repo)
        return unless remote
        PrResolver.fetch_same_repo_branch(branch, remote, repo)
      end

      # Fetch a forked PR and set up the local branch with tracking.
      private def self.fetch_fork_pr(number : UInt32, branch : String, repo : Repository) : Nil
        remote = find_origin_remote(repo)
        return unless remote
        PrResolver.fetch_fork_pr(number, remote, repo)
        PrResolver.setup_fork_branch(branch, remote, number, repo)
      end

      # Fallback PR resolution using `gh pr view` when gh api is unavailable.
      private def self.resolve_pr_fallback(number : String) : String?
        result = Cmd.new("gh")
          .args(["pr", "view", number, "--json", "headRefName", "--jq", ".headRefName"])
          .run
        if result.success? && !result.stdout.strip.empty?
          branch = result.stdout.strip
          ensure_branch_exists(branch)
          branch
        end
      end

      # Find the remote name for "origin" or the first remote.
      private def self.find_origin_remote(repo : Repository) : String?
        result = Cmd.new("git")
          .args(["remote"])
          .current_dir(repo.discovery_path)
          .run
        return nil unless result.success?
        remotes = result.stdout.lines.map(&.strip).reject(&.empty?)
        # Prefer "origin", else first available
        remotes.includes?("origin") ? "origin" : remotes.first?
      end
    end
  end
end
