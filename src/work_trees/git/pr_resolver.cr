# PR/MR fetch-and-checkout resolver — Crystal port of
# vendor/worktrunk/src/commands/worktree/switch.rs (pr/mr resolution)
# and vendor/worktrunk/src/git/remote_ref/ (provider infrastructure)
#
# Handles:
#   - Fetching PR/MR metadata via gh/glab CLI
#   - Detecting same-repo vs cross-repo (fork) PRs
#   - Fetching remote refs with proper refspecs
#   - Creating local branches from remote refs with tracking config
#   - PR context display (title, author, state, URL)

require "json"
require "./repository"

module WorkTrees
  module Git
    module PrResolver
      # PR/MR metadata fetched from the remote API.
      struct RemoteRefInfo
        getter number : UInt32
        getter title : String
        getter author : String
        getter state : String
        getter source_branch : String
        getter base_branch : String
        getter url : String
        getter head_sha : String
        getter base_sha : String
        getter? cross_repo : Bool

        def initialize(
          @number, @title, @author, @state, @source_branch, @base_branch,
          @url, @head_sha, @base_sha, @cross_repo,
        )
        end

        def cross_repo? : Bool
          @cross_repo
        end

        def prefixed_branch_name : String?
          if cross_repo?
            # Use author/branch pattern for cross-repo to avoid name collisions
            "#{@author}/#{@source_branch}"
          end
        end

        def display_summary(ref_type : Symbol) : String
          symbol = ref_type == :pr ? "PR" : "MR"
          draft = @state == "draft" ? " [draft]" : ""
          "#{symbol} ##{@number}: #{@title} (by #{@author}, #{@state}#{draft})"
        end
      end

      # Parse GitHub `gh api repos/{owner}/{repo}/pulls/{N}` JSON response.
      def self.parse_github_pr_response(json : JSON::Any, number : UInt32) : RemoteRefInfo
        title = json["title"].as_s
        author = json.dig?("user", "login").try(&.as_s) || "unknown"
        state = json["state"].as_s
        draft = json["draft"]?.try(&.as_bool) || false

        head = json["head"]
        base = json["base"]
        source_branch = head["ref"].as_s
        base_branch = base["ref"].as_s
        head_sha = head["sha"].as_s
        base_sha = base["sha"].as_s
        url = json["html_url"].as_s

        head_owner = head.dig?("repo", "owner", "login").try(&.as_s) || ""
        base_owner = base.dig?("repo", "owner", "login").try(&.as_s) || ""
        head_repo = head.dig?("repo", "name").try(&.as_s) || ""
        base_repo = base.dig?("repo", "name").try(&.as_s) || ""

        cross_repo = !head_owner.empty? && !base_owner.empty? &&
                     (head_owner != base_owner || head_repo != base_repo)

        displayed_state = if draft
                            "draft"
                          else
                            state
                          end

        RemoteRefInfo.new(
          number, title, author, displayed_state,
          source_branch, base_branch,
          url, head_sha, base_sha, cross_repo,
        )
      end

      # Fetch PR info from GitHub API via `gh api`.
      def self.fetch_pr_info(number : UInt32, repo : Repository) : RemoteRefInfo?
        # Determine owner/repo from the repository's GitHub remote
        owner_repo = github_owner_repo(repo)
        return nil unless owner_repo

        owner, repo_name = owner_repo
        result = Cmd.new("gh")
          .args(["api", "repos/#{owner}/#{repo_name}/pulls/#{number}"])
          .run

        return nil unless result.success?
        json = JSON.parse(result.stdout)
        parse_github_pr_response(json, number)
      rescue ex : JSON::ParseException
        nil
      end

      # Build a ref path for fetching PR/MR head via `git fetch`.
      #
      # GitHub PRs:   `pull/<N>/head` → refs/pull/N/head
      # GitLab MRs:   `merge-requests/<N>/head` → refs/merge-requests/N/head
      def self.ref_path_for(ref_type : Symbol, number : UInt32) : String
        case ref_type
        when :pr then "pull/#{number}/head"
        when :mr then "merge-requests/#{number}/head"
        else          "pull/#{number}/head"
        end
      end

      # Build a fetch refspec for a fork PR.
      #
      # Fetches `refs/pull/{N}/head` from the remote (usually the base repo's
      # remote) and stores it as a remote-tracking ref under `refs/remotes/pull/{N}/head`
      # so git knows it's not a dangling FETCH_HEAD reference.
      def self.fork_refspec(number : UInt32) : String
        "+refs/pull/#{number}/head:refs/remotes/pull/#{number}/head"
      end

      # Fetch a forked PR head ref into the local repository.
      #
      # Uses the base repo's remote. After fetch, the commit is at FETCH_HEAD
      # and under refs/remotes/pull/{N}/head.
      def self.fetch_fork_pr(number : UInt32, remote : String, repo : Repository) : Bool
        refspec = fork_refspec(number)
        repo.run_command_check(["fetch", "--", remote, refspec])
      end

      # Fetch a same-repo PR branch into remote-tracking refs.
      #
      # Uses an explicit refspec so the branch is available even in
      # single-branch clones or bare repos.
      def self.fetch_same_repo_branch(branch : String, remote : String, repo : Repository) : Bool
        refspec = "+refs/heads/#{branch}:refs/remotes/#{remote}/#{branch}"
        repo.run_command_check(["fetch", "--", remote, refspec])
      end

      # Create a local branch from FETCH_HEAD and configure tracking for a fork PR.
      #
      # 1. `git branch -- <branch> FETCH_HEAD` — creates local branch
      # 2. `git config branch.<branch>.remote <remote>` — tracking remote
      # 3. `git config branch.<branch>.merge refs/pull/{N}/head` — tracking ref
      def self.setup_fork_branch(
        branch : String,
        remote : String,
        number : UInt32,
        repo : Repository,
      ) : Bool
        # Create branch from FETCH_HEAD
        return false unless repo.run_command_check(["branch", "--", branch, "FETCH_HEAD"])

        # Configure tracking
        ref_path = "refs/#{ref_path_for(:pr, number)}"
        repo.run_command_check(["config", "branch.#{branch}.remote", remote])
        repo.run_command_check(["config", "branch.#{branch}.merge", ref_path])

        true
      end

      # Try to determine GitHub owner/repo from the repository's remotes.
      # Returns `{owner, repo}` or nil.
      private def self.github_owner_repo(repo : Repository) : {String, String}?
        # Try `git remote get-url origin` and parse for github.com
        result = Cmd.new("git")
          .args(["remote", "get-url", "origin"])
          .current_dir(repo.discovery_path)
          .run
        return nil unless result.success?

        url = result.stdout.strip
        parse_github_url(url)
      end

      # Parse a GitHub URL into owner/repo.
      # Handles: https://github.com/owner/repo.git, git@github.com:owner/repo.git
      private def self.parse_github_url(url : String) : {String, String}?
        if url.includes?("github.com")
          # Strip protocol, trailing .git, etc.
          path = url
            .sub(/^https?:\/\//, "")
            .sub(/^git@/, "")
            .sub("github.com:", "github.com/")
            .sub("github.com/", "")
            .sub(/\.git$/, "")
            .strip
          parts = path.split('/')
          return {parts[0], parts[1]} if parts.size >= 2
        end
        nil
      end

      # Display PR/MR context information for the user.
      def self.display_pr_context(info : RemoteRefInfo, ref_type : Symbol) : String
        state_marker = case info.state
                       when "open", "opened"   then Styling.green("●")
                       when "closed", "merged" then Styling.red("●")
                       when "draft"            then Styling.dim("○")
                       else                         Styling.yellow("●")
                       end

        lines = [] of String
        lines << "#{state_marker} #{info.display_summary(ref_type)}"
        lines << Styling.dim("    #{info.url}")
        lines << Styling.dim("    branch: #{info.source_branch} → #{info.base_branch}")
        lines.join('\n')
      end

      # Build the full tracking ref path (e.g., "refs/pull/123/head").
      def self.tracking_ref(ref_type : Symbol, number : UInt32) : String
        "refs/#{ref_path_for(ref_type, number)}"
      end

      # Generate the local branch name for a remote ref.
      # Uses the source branch name directly (vendor behavior).
      def self.local_branch_name(source_branch : String) : String
        source_branch
      end
    end
  end
end
