# CLI entry point for work_trees — Crystal port of worktrunk
#
# Uses Crystal's built-in OptionParser from stdlib.

require "option_parser"

module WorkTrees
  module CLI
    def self.run(args = ARGV)
      if args.empty?
        print_help
        exit 1
      end

      command = args[0]
      command_args = args[1..]

      case command
      when "list"
        Commands.list(command_args)
      when "switch"
        Commands.switch(command_args)
      when "remove"
        Commands.remove(command_args)
      when "shell"
        Commands.shell(command_args)
      when "config"
        Commands.config(command_args)
      when "step"
        Commands.step(command_args)
      when "merge"
        Commands.merge(command_args)
      when "help", "--help", "-h"
        print_help
        exit 0
      when "--version", "-V"
        puts "work_trees #{WorkTrees::VERSION}"
        exit 0
      else
        STDERR.puts "Unknown command: #{command}"
        STDERR.puts "Run 'work_trees help' for usage."
        exit 1
      end
    end

    def self.print_help
      puts "work_trees #{WorkTrees::VERSION}"
      puts "A CLI for Git worktree management, designed for parallel AI agent workflows."
      puts ""
      puts "USAGE:"
      puts "    work_trees <command> [options]"
      puts ""
      puts "COMMANDS:"
      puts "    list     List all worktrees with branch info"
      puts "    switch   Switch to or create a worktree"
      puts "    remove   Remove a worktree and optionally its branch"
      puts "    shell    Generate shell integration wrapper"
      puts "    config   Show or create configuration"
      puts "    step     Run individual operations (commit, diff)"
      puts "    merge    Merge current branch into target"
      puts "    help     Show this help"
    end
  end

  module Commands
    def self.list(args : Array(String))
      full = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees list [options]"
        parser.on("-f", "--full", "Show full details") { full = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      repo = Git::Repository.current
      worktrees = repo.list_worktrees

      if worktrees.empty?
        puts "No worktrees found."
        return
      end

      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch

      if full
        list_full(worktrees, current_branch)
      else
        list_compact(worktrees, current_branch)
      end
    end

    private def self.list_compact(worktrees, current_branch)
      puts "  %-30s %-20s %s" % ["Branch", "Worktree", "HEAD"]
      puts "-" * 80

      worktrees.each do |worktree|
        marker = worktree.branch == current_branch ? "@" : " "
        branch = worktree.branch || "(detached)"
        name = worktree.dir_name
        short_head = worktree.head[0, 7]

        puts "#{marker} %-30s %-20s %s" % [branch, name, short_head]
      end

      puts ""
      puts "○ Showing #{worktrees.size} worktree(s)"
    end

    private def self.list_full(worktrees, current_branch)
      repo = Git::Repository.current
      default_branch = repo.default_branch

      # Header
      puts "%-2s %-25s %-8s %-7s %6s %6s %-8s %s" % ["", "Branch", "Status", "HEAD±", "main↕", "Remote", "Commit", "Age"]

      worktrees.each do |worktree|
        marker = worktree.branch == current_branch ? "@" : " "
        branch = worktree.branch || "(detached)"
        short_commit = worktree.head[0, 7]

        # Compute status per worktree
        status, changes, ahead, behind, remote_status = worktree_stats(repo, worktree, default_branch)

        puts "%-2s %-25s %-8s %-7s %6s %6s %-8s %s" % [
          marker, truncate(branch, 25), status, changes,
          ahead_to_s(ahead), behind_to_s(behind), short_commit, remote_status,
        ]
      end

      puts ""
      puts "○ Showing #{worktrees.size} worktree(s) • main=#{default_branch}"
    end

    private def self.worktree_stats(repo, worktree, default_branch)
      branch = worktree.branch
      return {"-", "-", 0, 0, ""} unless branch

      # Check working tree status
      wt_path = worktree.path
      dirty = Cmd.new("git")
        .args(["status", "--porcelain"])
        .current_dir(wt_path)
        .run
        .stdout

      status = dirty.empty? ? "clean" : "+"

      # Lines changed since branching (diff from default to branch)
      diff_result = Cmd.new("git")
        .args(["diff", "--shortstat", "#{default_branch}...#{branch}"])
        .run
      changes = if diff_result.success?
                  stat = diff_result.stdout.strip
                  if stat.empty?
                    ""
                  else
                    format_shortstat(stat)
                  end
                else
                  "-"
                end

      # Commits ahead of default
      ahead = count_commits_ahead(default_branch, branch)

      # Commits behind default
      behind = if branch == default_branch
                 0
               else
                 count_commits_ahead(branch, default_branch)
               end

      # Remote tracking
      remote_status = if branch == default_branch
                        remote_ahead(repo)
                      else
                        ""
                      end

      {status, changes, ahead, behind, remote_status}
    end

    private def self.count_commits_ahead(from : String, to : String) : Int32
      result = Cmd.new("git")
        .args(["rev-list", "--count", "#{from}..#{to}"])
        .run
      if result.success?
        result.stdout.strip.to_i32
      else
        0
      end
    end

    private def self.remote_ahead(repo)
      result = Cmd.new("git")
        .args(["rev-list", "--count", "HEAD..@{u}"])
        .current_dir(repo.discovery_path)
        .run
      if result.success? && !result.stdout.strip.empty?
        "⇡#{result.stdout.strip}"
      else
        ""
      end
    end

    private def self.format_shortstat(stat : String) : String
      # Parse "2 files changed, 53 insertions(+), 8 deletions(-)"
      if m = stat.match(/(\d+) insertion.*?(\d+) deletion/)
        "+#{m[1]}/-#{m[2]}"
      elsif m = stat.match(/(\d+) insertion/)
        "+#{m[1]}"
      elsif m = stat.match(/(\d+) deletion/)
        "-#{m[1]}"
      else
        stat
      end
    end

    private def self.truncate(str : String, max : Int32) : String
      if str.size > max
        str[0, max - 1] + "…"
      else
        str
      end
    end

    private def self.ahead_to_s(n : Int32) : String
      n > 0 ? "↑#{n}" : ""
    end

    private def self.behind_to_s(n : Int32) : String
      n > 0 ? "↓#{n}" : ""
    end

    def self.switch(args : Array(String))
      create = false
      base_branch : String? = nil
      branch : String? = nil
      execute_cmd : String? = nil
      config = Config.load_default
      path_template = config.worktree_path_template

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees switch [options] [branch]"
        parser.on("-c", "--create", "Create a new branch and worktree") { create = true }
        parser.on("-b BASE", "--base=BASE", "Base branch for the new worktree") { |b| base_branch = b }
        parser.on("-x CMD", "--execute=CMD", "Execute a command after switching") { |cmd| execute_cmd = cmd }
        parser.on("-p PATH", "--path-template=PATH", "Worktree path template") { |tpl| path_template = tpl }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
        parser.unknown_args do |before, _after|
          branch = before[0]? if before.size > 0
        end
      end

      exec = execute_cmd
      repo = Git::Repository.current
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch

      # Resolve branch shortcuts
      resolved = if b = branch
                   Git::BranchResolver.resolve(b)
                 else
                   current_branch
                 end

      # Save current branch as previous (for - shortcut)
      if resolved != current_branch
        Git::BranchResolver.save_previous(current_branch)
      end

      worktree_path : String? = nil

      if create
        worktree_path = switch_create(repo, resolved, base_branch, path_template)
      else
        worktree_path = switch_to_existing(repo, resolved, current_branch)
      end

      # Execute command if requested
      if exec && (cmd = exec)
        target_path = worktree_path || "."
        puts "Executing: #{cmd}"
        emit_exec_directive(cmd)
        Cmd.new("sh").args(["-c", cmd]).current_dir(target_path).run
      end
    end

    private def self.emit_cd_directive(path : String) : Nil
      if file = ENV["WORKTRUNK_DIRECTIVE_CD_FILE"]?
        File.write(file, path)
      end
    end

    private def self.emit_exec_directive(cmd : String) : Nil
      if file = ENV["WORKTRUNK_DIRECTIVE_EXEC_FILE"]?
        File.write(file, "#{cmd}\n", mode: "a")
      end
    end

    private def self.switch_create(repo, branch, base_branch, path_template)
      unless branch
        STDERR.puts "Error: --create requires a branch name"
        exit 1
      end

      vars = {"branch" => branch, "repo" => File.basename(repo.discovery_path)}
      worktree_path = Template.expand(path_template, vars)
      # Expand ~ to home directory
      if worktree_path.starts_with?("~/")
        home = ENV["HOME"]? || "."
        worktree_path = File.join(home, worktree_path[2..])
      end
      worktree_path = File.expand_path(worktree_path)
      base = base_branch || repo.default_branch

      # Add resolved path to template vars for post-create hooks
      hook_vars = vars.dup
      hook_vars["worktree_path"] = worktree_path
      hook_vars["base"] = base

      if existing = repo.worktree_for_branch(branch)
        STDERR.puts "Error: Worktree already exists for '#{branch}' at #{existing}"
        exit 1
      end

      # Run pre-start hooks if configured
      run_hooks("pre-start", hook_vars)

      puts "◎ Creating worktree for #{branch} from #{base}..."
      puts "  Path: #{worktree_path}"

      begin
        repo.run_command(["worktree", "add", "-b", branch, worktree_path, base])
        puts "✓ Created branch #{branch} from #{base} and worktree @ #{worktree_path}"
        emit_cd_directive(worktree_path)
      rescue ex : Git::CommandError
        STDERR.puts "✗ #{ex.message}"
        exit 1
      end

      # Run post-start hooks if configured
      run_hooks("post-start", hook_vars)

      worktree_path
    end

    private def self.run_hooks(section : String, vars : Hash(String, String))
      config_path = Config.default_config_path
      return unless File.exists?(config_path)

      content = File.read(config_path)
      hooks = Config.parse_hooks(content, section)
      return if hooks.empty?

      hooks.each do |hook|
        expanded = hook.expand(vars)
        puts "  ▶ #{hook.name}: #{expanded}"
        result = Cmd.new("sh").args(["-c", expanded]).run
        if result.success?
          puts "    ✓ #{hook.name} completed"
        else
          STDERR.puts "    ✗ #{hook.name} failed (exit #{result.exit_code})"
        end
      end
    end

    private def self.switch_to_existing(repo, branch, current_branch)
      target = branch || current_branch
      wt_path = repo.worktree_for_branch(target)
      unless wt_path
        STDERR.puts "Error: No worktree found for branch '#{target}'"
        STDERR.puts "Use --create to create a new worktree for this branch."
        exit 1
      end

      switch_vars = {"branch" => target, "worktree_path" => wt_path}

      # Pre-switch hooks
      run_hooks("pre-switch", switch_vars)

      # If shell integration is active, emit cd directive
      emit_cd_directive(wt_path)

      puts "Switching to worktree for #{target} @ #{wt_path}"

      # Post-switch hooks
      run_hooks("post-switch", switch_vars)

      wt_path
    end

    def self.remove(args : Array(String))
      force = false
      force_delete = false
      keep_branch = false
      branch : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees remove [options] [branch]"
        parser.on("-f", "--force", "Force removal of dirty worktree") { force = true }
        parser.on("-D", "--force-delete", "Force delete branch even if not merged") { force_delete = true }
        parser.on("--no-delete-branch", "Keep the branch after removing worktree") { keep_branch = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
        parser.unknown_args do |before, _after|
          branch = before[0]? if before.size > 0
        end
      end

      repo = Git::Repository.current
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch
      target = if b = branch
                 b
               else
                 current_branch
               end

      # Find the worktree for the target branch
      wt_path = repo.worktree_for_branch(target)
      unless wt_path
        STDERR.puts "Error: No worktree found for branch '#{target}'"
        exit 1
      end

      # Don't remove the current worktree
      if wt_path == current_wt.path
        STDERR.puts "Error: Cannot remove the current worktree"
        STDERR.puts "Switch to a different worktree first."
        exit 1
      end

      puts "◎ Removing worktree for #{target} @ #{wt_path}"
      remove_vars = {"branch" => target, "worktree_path" => wt_path}

      begin
        # Run pre-remove hooks
        run_hooks("pre-remove", remove_vars)

        repo.remove_worktree(wt_path, force)
        puts "✓ Removed worktree @ #{wt_path}"

        # Run post-remove hooks
        run_hooks("post-remove", remove_vars)

        # Delete branch unless --no-delete-branch
        unless keep_branch
          mode = force_delete ? Git::BranchDeletionMode::ForceDelete : Git::BranchDeletionMode::SafeDelete
          begin
            repo.delete_branch(target, mode)
            puts "✓ Deleted branch #{target}"
          rescue ex : Git::CommandError
            STDERR.puts "! Could not delete branch: #{ex.message}"
          end
        end
      rescue ex : Git::CommandError
        STDERR.puts "✗ #{ex.message}"
        exit 1
      end
    end

    def self.step(args : Array(String))
      sub = args[0]?

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees step <subcommand>"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      case sub
      when "commit"
        step_commit(args[1..])
      when "diff"
        step_diff
      when "squash"
        step_squash
      when "rebase"
        step_rebase(args[1..])
      when "push"
        step_push(args[1..])
      else
        STDERR.puts "Usage: work_trees step [commit|diff|squash|rebase|push]"
        exit 1
      end
    end

    private def self.step_commit(args : Array(String))
      message : String? = nil
      all = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees step commit [options]"
        parser.on("-m MESSAGE", "--message=MESSAGE", "Commit message") { |msg| message = msg }
        parser.on("-a", "--all", "Stage all changes") { all = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      commit_vars = {"branch" => branch}

      # Pre-commit hooks
      run_hooks("pre-commit", commit_vars)

      # Stage changes
      stage_args = all ? ["add", "-A"] : ["add", "-u"]
      repo.run_command(stage_args)

      # Check if there's anything to commit
      if repo.run_command_check(["diff", "--cached", "--quiet"])
        puts "Nothing to commit."
      else
        # Generate commit message from diff
        commit_msg = if m = message
                       m
                     else
                       generate_commit_message(repo)
                     end
        repo.run_command(["commit", "-m", commit_msg])
        puts "✓ Committed: #{commit_msg.lines.first}"

        # Post-commit hooks
        commit_vars["commit"] = commit_msg
        run_hooks("post-commit", commit_vars)
      end
    end

    private def self.step_diff
      repo = Git::Repository.current
      result = Cmd.new("git").args(["diff", "--stat"]).current_dir(repo.discovery_path).run
      puts result.stdout
    end

    private def self.step_squash
      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      default = repo.default_branch

      # Find the merge-base with default branch
      merge_base = repo.run_command(["merge-base", branch, default]).strip

      if merge_base.empty?
        STDERR.puts "Error: No common ancestor with #{default}"
        exit 1
      end

      # Count commits since branching
      count_output = repo.run_command(["rev-list", "--count", "#{merge_base}..#{branch}"])
      count = count_output.strip.to_i

      if count <= 1
        puts "Nothing to squash (1 commit since branching)."
        return
      end

      puts "◎ Squashing #{count} commits into one..."
      repo.run_command(["reset", "--soft", merge_base])
      puts "✓ Squashed #{count} commits. Ready to commit."
    end

    private def self.step_rebase(args : Array(String))
      target : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees step rebase [target]"
        parser.unknown_args do |before, _after|
          target = before[0]? if before.size > 0
        end
      end

      repo = Git::Repository.current
      target_branch = if t = target
                        t
                      else
                        repo.default_branch
                      end

      puts "◎ Rebasing onto #{target_branch}..."
      begin
        repo.run_command(["rebase", target_branch])
        puts "✓ Rebased onto #{target_branch}"
      rescue ex : Git::CommandError
        STDERR.puts "✗ Rebase conflict: #{ex.message}"
        STDERR.puts "Resolve conflicts and run: git rebase --continue"
        exit 1
      end
    end

    private def self.step_push(args : Array(String))
      target : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees step push [target]"
        parser.unknown_args do |before, _after|
          target = before[0]? if before.size > 0
        end
      end

      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      target_branch = if t = target
                        t
                      else
                        repo.default_branch
                      end

      # Checkout target and fast-forward merge from current branch
      target_path = repo.worktree_for_branch(target_branch)
      unless target_path
        STDERR.puts "Error: No worktree for #{target_branch}"
        exit 1
      end

      puts "◎ Pushing #{branch} → #{target_branch} (fast-forward)..."
      Cmd.new("git").args(["checkout", target_branch]).current_dir(target_path).run!
      Cmd.new("git").args(["merge", "--ff-only", branch]).current_dir(target_path).run!
      puts "✓ Fast-forwarded #{target_branch} to #{branch}"
    end

    private def self.generate_commit_message(repo) : String
      config = Config.load_default
      branch = repo.current_worktree.current_branch

      # Try LLM generation if configured
      if llm = config.llm_command
        msg = try_llm_commit(llm, repo)
        return msg if msg
      end

      # Fallback: derive from branch name
      branch_commit_message(branch)
    end

    private def self.try_llm_commit(llm : String, repo) : String?
      diff = Cmd.new("git")
        .args(["diff", "--cached"])
        .current_dir(repo.discovery_path)
        .run
        .stdout

      return nil if diff.strip.empty?

      prompt = "Generate a concise conventional commit message for this diff. Use types: feat, fix, docs, refactor, test, chore, perf, ci. Return ONLY the commit message, no explanation.\n\ndiff:\n#{diff}"
      result = Cmd.new(llm)
        .stdin_data(prompt)
        .run

      if result.success? && !result.stdout.strip.empty?
        result.stdout.strip.lines.first
      end
    end

    private def self.branch_commit_message(branch : String) : String
      prefix = if branch.includes?('/')
                 branch.split('/').first
               else
                 "chore"
               end

      type = case prefix
             when "feat", "feature"         then "feat"
             when "fix", "bugfix", "hotfix" then "fix"
             when "docs", "doc"             then "docs"
             when "refactor"                then "refactor"
             when "test", "tests"           then "test"
             when "chore"                   then "chore"
             when "perf"                    then "perf"
             when "ci"                      then "ci"
             else                                "feat"
             end

      "#{type}: #{branch}"
    end

    def self.merge(args : Array(String))
      target : String? = nil
      no_commit = false
      no_squash = false
      no_rebase = false
      no_remove = false
      no_ff = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees merge [options] [target]"
        parser.on("--no-commit", "Skip committing before merge") { no_commit = true }
        parser.on("--no-squash", "Skip squashing before merge") { no_squash = true }
        parser.on("--no-rebase", "Skip rebasing onto target") { no_rebase = true }
        parser.on("--no-remove", "Keep worktree after merge") { no_remove = true }
        parser.on("--no-ff", "Skip fast-forward only check") { no_ff = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
        parser.unknown_args do |before, _after|
          target = before[0]? if before.size > 0
        end
      end

      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      target_branch = if t = target
                        t
                      else
                        repo.default_branch
                      end
      merge_vars = {"branch" => branch, "target" => target_branch, "target_worktree_path" => target_branch}

      # Pre-merge hooks
      run_hooks("pre-merge", merge_vars)

      puts "◎ Merging #{branch} into #{target_branch}..."

      # Run merge pipeline
      auto_commit(repo) unless no_commit
      squash_branch(repo, branch, target_branch) unless no_squash
      rebase_branch(repo, target_branch) unless no_rebase
      fast_forward_merge(repo, branch, target_branch, no_ff)
      cleanup_after_merge(repo, branch, target_branch) unless no_remove

      puts "✓ Merged #{branch} into #{target_branch}"

      # Post-merge hooks
      run_hooks("post-merge", merge_vars)
    end

    private def self.auto_commit(repo)
      if !repo.run_command_check(["diff", "--quiet"]) || !repo.run_command_check(["diff", "--cached", "--quiet"])
        puts "  Committing changes..."
        commit_msg = generate_commit_message(repo)
        repo.run_command(["add", "-A"])
        repo.run_command(["commit", "-m", commit_msg])
        puts "  ✓ #{commit_msg.lines.first}"
      end
    end

    private def self.squash_branch(repo, branch, target_branch)
      merge_base = repo.run_command(["merge-base", branch, target_branch]).strip
      return if merge_base.empty?
      count = repo.run_command(["rev-list", "--count", "#{merge_base}..#{branch}"]).strip.to_i
      return if count <= 1
      puts "  Squashing #{count} commits..."
      repo.run_command(["reset", "--soft", merge_base])
      squash_msg = generate_commit_message(repo)
      repo.run_command(["commit", "-m", "squash: #{squash_msg}"])
      puts "  ✓ Squashed into: #{squash_msg.lines.first}"
    end

    private def self.rebase_branch(repo, target_branch)
      puts "  Rebasing onto #{target_branch}..."
      begin
        repo.run_command(["rebase", target_branch])
        puts "  ✓ Rebased"
      rescue ex : Git::CommandError
        STDERR.puts "! Rebase conflict: #{ex.message}"
        STDERR.puts "Resolve conflicts and run: git rebase --continue"
        exit 1
      end
    end

    private def self.fast_forward_merge(repo, branch, target_branch, no_ff)
      target_wt_path = repo.worktree_for_branch(target_branch)
      unless target_wt_path
        STDERR.puts "Error: No worktree for #{target_branch}"
        exit 1
      end
      puts "  Merging into #{target_branch}..."
      merge_args = no_ff ? ["merge", branch] : ["merge", "--ff-only", branch]
      Cmd.new("git").args(merge_args).current_dir(target_wt_path).run!
    end

    private def self.cleanup_after_merge(repo, branch, target_branch)
      puts "◎ Cleaning up #{branch} worktree..."
      if wt_path = repo.worktree_for_branch(branch)
        begin
          repo.remove_worktree(wt_path)
          repo.delete_branch(branch, Git::BranchDeletionMode::SafeDelete)
          puts "✓ Removed #{branch} worktree and branch"
          if target_path = repo.worktree_for_branch(target_branch)
            emit_cd_directive(target_path)
          end
        rescue ex : Git::CommandError
          puts "! Could not remove worktree: #{ex.message}"
        end
      end
    end

    def self.shell(args : Array(String))
      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees shell init [bash|zsh|fish]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      sub = args[0]?
      case sub
      when "init"
        arg = args[1]? || "bash"
        shell_type = case arg
                     when "zsh"  then :zsh
                     when "fish" then :fish
                     else             :bash
                     end
        puts Shell.generate(shell_type)
      when "install"
        shell_install
      when "uninstall"
        shell_uninstall
      else
        STDERR.puts "Usage: work_trees shell [init|install|uninstall] [bash|zsh|fish]"
        exit 1
      end
    end

    def self.config(args : Array(String))
      sub = args[0]?

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees config [show|create]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      case sub
      when "show"
        config_show
      when "create"
        config_create
      else
        config_show
      end
    end

    private def self.config_show
      config_path = Config.default_config_path
      if File.exists?(config_path)
        puts File.read(config_path)
      else
        puts "# No config file found at #{config_path}"
        config = Config::UserConfig.new
        puts "# Default: worktree-path = #{config.worktree_path_template.inspect}"
        puts ""
        puts "# Create one with: work_trees config create"
      end
    end

    private def self.config_create
      config_path = Config.default_config_path
      if File.exists?(config_path)
        STDERR.puts "Config already exists at #{config_path}"
        exit 1
      end

      dir = File.dirname(config_path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      config = Config::UserConfig.new
      toml_content = "# WorkTrees configuration\nworktree-path = \"#{config.worktree_path_template}\"\n\n# Hooks — add commands at lifecycle events:\n# [pre-start]\n# deps = \"npm install\"\n# [post-start]\n# server = \"npm run dev\"\n# [post-remove]\n# cleanup = \"echo 'removed {{ branch }}'\"\n"
      File.write(config_path, toml_content)
      puts "✓ Created config at #{config_path}"
    end

    private def self.shell_install
      rc_file = shell_rc_file
      return unless rc_file

      if File.exists?(rc_file) && File.read(rc_file).includes?("work_trees shell init")
        puts "Shell integration already installed in #{rc_file}"
        return
      end

      line = "eval \"$(work_trees shell init #{shell_type_from_env})\""
      File.open(rc_file, mode: "a") do |file|
        file.puts ""
        file.puts "# WorkTrees shell integration"
        file.puts line
      end

      puts "✓ Installed WorkTrees shell integration in #{rc_file}"
      puts "  Restart your shell or run: source #{rc_file}"
    end

    private def self.shell_uninstall
      rc_file = shell_rc_file
      return unless rc_file

      unless File.exists?(rc_file)
        puts "No shell config found at #{rc_file}"
        return
      end

      content = File.read(rc_file)
      unless content.includes?("work_trees shell init")
        puts "WorkTrees shell integration not found in #{rc_file}"
        return
      end

      cleaned = content.lines.reject { |line| line.includes?("work_trees shell init") || line.strip == "# WorkTrees shell integration" }
      File.write(rc_file, cleaned.join)
      puts "✓ Removed WorkTrees shell integration from #{rc_file}"
      puts "  Restart your shell for changes to take effect."
    end

    private def self.shell_type_from_env
      shell_path = ENV["SHELL"]? || "/bin/bash"
      if shell_path.includes?("zsh")
        :zsh
      elsif shell_path.includes?("fish")
        :fish
      else
        :bash
      end
    end

    private def self.shell_rc_file
      home = ENV["HOME"]? || "."
      case shell_type_from_env
      when :bash then File.join(home, ".bashrc")
      when :zsh  then File.join(home, ".zshrc")
      when :fish then File.join(home, ".config", "fish", "config.fish")
      else            File.join(home, ".bashrc")
      end
    end
  end
end
