# CI status detection — Crystal port of worktrunk/src/commands/list/ci_status/
#
# Detects CI platform from git remote URLs and fetches CI status
# via CLI tools (gh, glab, az, tea). Supports GitHub, GitLab, Azure, Gitea.
#
# Status symbols: ✓ (success), ✗ (failure), ○ (pending), ? (unknown)

require "json"

module WorkTrees
  enum CiPlatform
    GitHub
    GitLab
    Azure
    Gitea
    Unknown

    # Detect CI platform from a parsed git remote URL.
    def self.detect(url : Git::GitRemoteUrl) : CiPlatform
      case
      when url.github? then GitHub
      when url.gitlab? then GitLab
      when url.azure?  then Azure
      when url.gitea?  then Gitea
      else                  Unknown
      end
    end
  end

  enum CiStatus
    Success
    Failure
    Pending
    Unknown

    # ANSI-styled status symbol for display.
    def symbol : String
      case self
      in .success? then Styling.green("✓")
      in .failure? then Styling.red("✗")
      in .pending? then Styling.dim("○")
      in .unknown? then Styling.dim("?")
      end
    end

    # True if the status is a terminal (final) state.
    def terminal? : Bool
      success? || failure?
    end

    # Fetch CI status for a branch from a specific platform.
    #
    # Returns nil when the CLI tool is unavailable or the query fails.
    def self.fetch_ci_status(branch : String, platform : CiPlatform) : CiStatus?
      case platform
      when .git_hub? then fetch_github_status(branch)
      when .git_lab? then fetch_gitlab_status(branch)
      when .azure?   then fetch_azure_status(branch)
      when .gitea?   then fetch_gitea_status(branch)
      else                nil
      end
    end

    # Fetch GitHub CI status via `gh run list`.
    private def self.fetch_github_status(branch : String) : CiStatus?
      result = Cmd.new("gh")
        .args(["run", "list", "--branch", branch, "--limit", "1", "--json", "status,conclusion", "--jq", ".[0].conclusion // .[0].status"])
        .run
      return nil if !result.success? || result.stdout.strip.empty?

      parse_github_conclusion(result.stdout.strip)
    end

    # Parse GitHub conclusion/status into CiStatus.
    private def self.parse_github_conclusion(status : String) : CiStatus
      case status
      when "success"         then Success
      when "failure"         then Failure
      when "cancelled"       then Failure
      when "skipped"         then Pending
      when "timed_out"       then Failure
      when "action_required" then Pending
      when "neutral"         then Success
      else                        Pending
      end
    end

    # Fetch GitLab CI status via `glab ci list`.
    private def self.fetch_gitlab_status(branch : String) : CiStatus?
      result = Cmd.new("glab")
        .args(["ci", "list", "--branch", branch, "--limit", "1", "--output", "json"])
        .run
      return nil if !result.success? || result.stdout.strip.empty?

      begin
        json = JSON.parse(result.stdout)
        if json.as_a? && !json.as_a.empty?
          status = json[0]["status"]?.try(&.as_s)
          return parse_gitlab_status(status) if status
        end
      rescue JSON::ParseException
      end
      nil
    end

    private def self.parse_gitlab_status(status : String) : CiStatus
      case status
      when "success"  then Success
      when "failed"   then Failure
      when "canceled" then Failure
      when "skipped"  then Pending
      when "running", "pending", "created", "waiting_for_resource", "preparing", "manual", "scheduled"
        Pending
      else
        Unknown
      end
    end

    # Fetch Azure DevOps CI status via `az pipelines runs list`.
    private def self.fetch_azure_status(branch : String) : CiStatus?
      result = Cmd.new("az")
        .args(["pipelines", "runs", "list", "--branch", branch, "--top", "1", "--query", "[0].result", "-o", "tsv"])
        .run
      return nil if !result.success? || result.stdout.strip.empty?

      parse_azure_result(result.stdout.strip)
    end

    private def self.parse_azure_result(result : String) : CiStatus
      case result
      when "succeeded"          then Success
      when "failed"             then Failure
      when "canceled"           then Failure
      when "partiallySucceeded" then Success
      when .empty?              then Pending
      else                           Pending
      end
    end

    # Fetch Gitea CI status via `tea pulls list` or commit status API.
    private def self.fetch_gitea_status(branch : String) : CiStatus?
      # Gitea CLI is less standardized; try tea CLI if available
      result = Cmd.new("tea")
        .args(["pulls", "list", "--state", "open", "--limit", "1"])
        .run
      return nil unless result.success?
      # For now, return pending as Gitea CI integration is best-effort
      Pending
    end

    # Auto-detect platform from a git remote URL and fetch status.
    def self.fetch_for_branch(branch : String, remote_url : String) : CiStatus?
      url = Git::GitRemoteUrl.parse(remote_url)
      return nil unless url
      platform = CiPlatform.detect(url)
      fetch_ci_status(branch, platform)
    end
  end
end
