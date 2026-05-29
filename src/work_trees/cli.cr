# CLI entry point for wktrees — Crystal port of worktrunk
#
# Uses Crystal's built-in OptionParser from stdlib.

require "option_parser"
require "json"
require "time"
require "wait_group"

module WorkTrees
  module CLI
    KNOWN_COMMANDS = %w[list switch remove config hook step merge shell help]

    def self.run(args = ARGV)
      Output.init_from_flags(args)

      # Consume --yes/-y from args (allowed anywhere, acts globally)
      yes = args.reject! { |a| a == "--yes" || a == "-y" }
      ENV["WORKTREES_YES"] = "1" if yes

      # No args: show help and exit
      if args.empty?
        print_help
        exit 1
      end

      first = args[0]

      # If the first arg is NOT a known command, treat it as a global flag
      unless KNOWN_COMMANDS.includes?(first)
        case first
        when "--help", "-h"
          print_help
          exit 0
        when "--version", "-V"
          puts "wktrees #{WorkTrees::VERSION}"
          exit 0
        end
      end

      # If the first arg isn't a known command or flag, it's an error
      unless first.in?(%w[--help -h --version -V]) || KNOWN_COMMANDS.includes?(first)
        STDERR.puts "Unknown command: #{first}"
        STDERR.puts "Run 'wktrees --help' for usage."
        exit 1
      end

      command = args[0]
      command_args = args[1..]

      # Trace main command execution when -vv is active
      Trace.span("cli.#{command}") do
        dispatch(command, command_args)
      end
    end

    private def self.dispatch(command : String, command_args : Array(String))
      case command
      when "list"
        Commands.list(command_args)
      when "switch"
        Commands.switch(command_args)
      when "remove"
        Commands.remove(command_args)
      when "config"
        Commands.config(command_args)
      when "hook"
        Commands.hook_command(command_args)
      when "step"
        Commands.step(command_args)
      when "merge"
        Commands.merge(command_args)
      when "shell"
        Commands.shell(command_args)
      else
        dispatch_unknown(command, command_args)
      end
    end

    private def self.dispatch_unknown(command, args)
      # Check if command is a configured alias
      if run_alias(command, args)
        exit 0
      end

      # Check for custom subcommand wktrees-<command> on PATH
      if run_custom_subcommand(command, args)
        exit 0
      end

      STDERR.puts "Unknown command: #{command}"
      STDERR.puts "Run 'wktrees help' for usage."
      exit 1
    end

    # Try to find and run a wktrees-<name> binary on PATH.
    private def self.run_custom_subcommand(name, args) : Bool
      binary = find_plugin(name)
      return false unless binary

      Process.run(
        binary,
        args,
        input: STDIN,
        output: STDOUT,
        error: STDERR,
      )
      true
    rescue
      false
    end

    # Find a plugin executable: searches .work_trees/bin/ relative to
    # the current directory first, then falls back to PATH.
    def self.find_plugin(name : String) : String?
      return nil if name.empty?

      # First: project-local .work_trees/bin/wktrees-<name>
      local_dir = File.join(Dir.current, ".work_trees", "bin")
      local_bin = File.join(local_dir, "wktrees-#{name}")
      return local_bin if File.executable?(local_bin)

      # Second: PATH search for wktrees-<name>
      path_dirs = ENV["PATH"]?.try(&.split(':')) || [] of String
      path_dirs.each do |dir|
        full_path = File.join(dir, "wktrees-#{name}")
        return full_path if File.executable?(full_path)
      end
      nil
    end

    # Search PATH for an executable by exact name.
    def self.find_on_path(name : String) : String?
      path_dirs = ENV["PATH"]?.try(&.split(':')) || [] of String
      path_dirs.each do |dir|
        full_path = File.join(dir, name)
        return full_path if File.executable?(full_path)
      end
      nil
    end

    private def self.run_alias(name, args) : Bool
      config_path = Config.default_config_path
      return false unless File.exists?(config_path)

      aliases = Config.parse_aliases(File.read(config_path))
      return false unless aliases.has_key?(name)

      cmd = aliases[name]
      puts "▶ #{name}: #{cmd}"

      # Parse the alias body as a wktrees command
      parts = cmd.split(' ', 2)
      alias_cmd = parts[0]
      alias_args = parts[1]?.try(&.split(' ')) || [] of String

      # Dispatch back through the CLI
      CLI.run([alias_cmd] + alias_args + args)
      true
    rescue
      false
    end

    def self.print_help
      puts "wktrees #{WorkTrees::VERSION}"
      puts "A CLI for Git worktree management, designed for parallel AI agent workflows."
      puts ""
      puts "USAGE:"
      puts "    wktrees <command> [options]"
      puts ""
      puts "COMMANDS:"
      puts "    list     List all worktrees with branch info"
      puts "    switch   Switch to or create a worktree"
      puts "    remove   Remove a worktree and optionally its branch"
      puts "    step     Run individual operations (commit, diff, squash, etc.)"
      puts "    merge    Merge current branch into target"
      puts "    hook     Show or run configured hooks"
      puts "    config   Show or create configuration"
      puts "    shell    Generate or install shell integration"
      puts "    help     Show this help"
    end
  end

  module Commands
    def self.list(args : Array(String))
      full = false
      format = "table"
      json_output = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees list [options]"
        parser.on("-f", "--full", "Show full details") { full = true }
        parser.on("--format=FORMAT", "Output format: table or json") { |fmt| format = fmt }
        parser.on("--json", "Output in JSON format") { json_output = true }
        parser.on("--ci-status", "Include CI status (requires gh CLI)") { ENV["WORKTREES_SHOW_CI"] = "1" }
        parser.on("--progressive", "Enable progressive rendering") { ENV["WORKTREES_PROGRESSIVE"] = "1" }
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
      default_branch = repo.default_branch

      if format == "json" || json_output
        list_json_v2(worktrees, current_branch, default_branch, repo)
      elsif format == "full" || full
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

    private def self.list_json_v2(worktrees, current_branch, default_branch, repo)
      puts(JSON.build { |json|
        json.array do
          worktrees.each do |worktree|
            branch = worktree.branch
            symbols, ahead_behind, _divergence = worktree_status_symbols(repo, worktree, default_branch)
            working_diff = working_tree_diff(worktree.path, branch)

            json.object do
              json.field "branch", branch
              json.field "head", worktree.head
              json.field "path", worktree.path
              json.field "bare", worktree.bare?
              json.field "detached", worktree.detached?
              json.field "locked", !worktree.locked.nil?
              json.field "prunable", worktree.prunable?
              json.field "current", branch == current_branch
              json.field "is_main", branch == default_branch

              if wt = symbols.working_tree
                json.field "working_tree" do
                  json.object do
                    json.field "staged", wt.staged?
                    json.field "modified", wt.modified?
                    json.field "untracked", wt.untracked?
                    json.field "dirty", wt.dirty?
                  end
                end
              end

              if ms = symbols.main_state
                json.field "main_state", ms.display
              end

              json.field "ahead", ahead_behind.ahead
              json.field "behind", ahead_behind.behind

              if ud = symbols.upstream_divergence
                json.field "upstream", ud.symbol
              end

              if ws = symbols.worktree_state
                json.field "worktree_state", ws.display
              end

              if os = symbols.operation_state
                json.field "operation_state", os.display
              end

              unless working_diff.empty?
                json.field "working_diff", working_diff
              end

              if Output.verbose? && branch
                ci = ci_status(branch)
                json.field "ci_status", ci unless ci.empty?
              end
            end
          end
        end
      })
    end

    private def self.list_full(worktrees, current_branch)
      repo = Git::Repository.current
      default_branch = repo.default_branch

      # Phase 1: Show skeleton immediately using ColumnKind headers
      show_skeleton_v2(worktrees, current_branch, default_branch)

      # Phase 2: Compute stats concurrently
      wg = WaitGroup.new
      results = Array(Tuple(Int32, String, String, List::StatusSymbols, Int32, Int32, List::AheadBehind, List::Divergence, String, String)).new(worktrees.size)
      mutex = Mutex.new

      worktrees.each_with_index do |worktree, idx|
        wg.spawn do
          branch = worktree.branch || "(detached)"
          short_commit = worktree.head[0, 7]
          symbols, ahead_behind, divergence = worktree_status_symbols(repo, worktree, default_branch)
          working_diff = working_tree_diff(worktree.path, branch)
          branch_diff = branch_to_default_diff(default_branch, branch, worktree.path)
          mutex.synchronize { results << {idx, branch, short_commit, symbols, worktree.locked? ? 1 : 0, 0, ahead_behind, divergence, working_diff, branch_diff} }
        end
      end

      wg.wait
      results.sort_by!(&.[0])

      # Phase 3: Clear skeleton and show real table
      clear_skeleton(worktrees.size)

      render_full_table_v2(results, current_branch, default_branch, worktrees.size)
    end

    private def self.show_skeleton_v2(worktrees, current_branch, default_branch)
      puts "%-2s %-25s %-8s %-7s %-6s %-6s %-8s" % ["", "Branch", "Status", "HEAD±", "main↕", "Remote", "Commit"]
      puts "-" * 75

      worktrees.each do |worktree|
        branch = worktree.branch || "(detached)"
        marker = gutter_symbol(worktree, current_branch, default_branch)
        short_commit = worktree.head[0, 7]
        puts "%-2s %-25s %-8s %-7s %-6s %-6s %-8s" % [
          marker, truncate(branch, 25), dim("· · · · · · ·"),
          dim("..."), dim("..."), dim("..."), short_commit,
        ]
      end
      puts ""
    end

    private def self.clear_skeleton(row_count : Int32)
      lines = row_count + 3
      print "\e[#{lines}A\e[J" if STDOUT.tty?
    end

    private def self.render_full_table_v2(results, current_branch, default_branch, count)
      puts "%-2s %-30s %-8s %-7s %-6s %-6s %-8s" % ["", "Branch", "Status", "HEAD±", "main↕", "Remote", "Commit"]
      puts "-" * 75

      results.each do |_, branch, short_commit, symbols, _locked, _unused, ahead_behind, divergence, working_diff, _branch_diff|
        marker = gutter_from_symbols(branch, current_branch, default_branch)
        status = symbols.render_with_mask
        puts "%-2s %-30s %s %-7s %-6s %-6s %-8s" % [
          marker, truncate(branch, 30), status,
          working_diff, ahead_display(ahead_behind),
          divergence_display(divergence), short_commit,
        ]
      end

      puts ""
      puts dim("○ Showing #{count} worktree(s) • main=#{default_branch}")
    end

    # Gutter symbol: @ for current, ^ for main, + for regular worktree, space for branch-only
    private def self.gutter_symbol(worktree, current_branch, default_branch)
      branch = worktree.branch
      if branch == current_branch
        "@"
      elsif branch == default_branch
        "^"
      else
        "+"
      end
    end

    private def self.gutter_from_symbols(branch, current_branch, default_branch)
      if branch == current_branch
        "@"
      elsif branch == default_branch
        "^"
      elsif branch == "(detached)"
        " "
      else
        "+"
      end
    end

    private def self.ahead_display(ab : List::AheadBehind) : String
      return "" if ab.ahead == 0 && ab.behind == 0
      parts = [] of String
      parts << "↑#{compact_count(ab.ahead)}" if ab.ahead > 0
      parts << "↓#{compact_count(ab.behind)}" if ab.behind > 0
      parts.join(" ")
    end

    private def self.divergence_display(div : List::Divergence) : String
      div.styled || ""
    end

    # Compact number notation: ≥10K → "∞", ≥1K → "NK", ≥100 → "NC", else raw
    private def self.compact_count(n : Int32) : String
      if n >= 10_000
        "∞"
      elsif n >= 1_000
        "#{n // 1_000}K"
      elsif n >= 100
        "#{n // 100}C"
      else
        n.to_s
      end
    end

    # Compute working tree diff (staged + unstaged changes vs HEAD)
    private def self.working_tree_diff(wt_path : String, branch : String?) : String
      return "-" unless branch && File.directory?(wt_path)
      result = Cmd.new("git")
        .args(["diff", "--numstat", "HEAD"])
        .current_dir(wt_path)
        .run
      return "" unless result.success?
      parse_numstat(result.stdout)
    end

    # Compute branch diff vs default branch
    private def self.branch_to_default_diff(default_branch : String, branch : String, wt_path : String) : String
      return "" if branch == default_branch
      return "" unless File.directory?(wt_path)
      result = Cmd.new("git")
        .args(["diff", "--numstat", "#{default_branch}...#{branch}"])
        .run
      return "" unless result.success?
      parse_numstat(result.stdout)
    end

    # Parse git --numstat output: "N\tM\tpath" → "+N -M" with compact notation
    private def self.parse_numstat(output : String) : String
      added = 0
      removed = 0
      output.each_line do |line|
        next if line.strip.empty?
        parts = line.split('\t')
        next unless parts.size >= 2
        added += parts[0].to_i32? || 0
        removed += parts[1].to_i32? || 0
      end
      return "" if added == 0 && removed == 0
      parts = [] of String
      parts << "+#{compact_count(added)}" if added > 0
      parts << "-#{compact_count(removed)}" if removed > 0
      parts.join(" ")
    end

    # Build StatusSymbols for a worktree by running git commands.
    private def self.worktree_status_symbols(repo, worktree, default_branch) : {List::StatusSymbols, List::AheadBehind, List::Divergence}
      symbols = List::StatusSymbols.new
      branch = worktree.branch
      wt_path = worktree.path

      if branch && File.directory?(wt_path)
        build_working_tree_status(symbols, wt_path)
        ahead_behind = build_main_state(symbols, default_branch, branch, wt_path)
        build_worktree_state(symbols, worktree)
        build_upstream_divergence(symbols, repo, branch, default_branch)
      else
        symbols.worktree_state = List::WorktreeState::Branch
        ahead_behind = List::AheadBehind.new
      end

      build_operation_state(symbols, wt_path)
      divergence = symbols.upstream_divergence || List::Divergence::None
      {symbols, ahead_behind, divergence}
    end

    private def self.build_working_tree_status(symbols, wt_path)
      dirty = Cmd.new("git")
        .args(["status", "--porcelain"])
        .current_dir(wt_path)
        .run
        .stdout

      if dirty.empty?
        symbols.working_tree = List::WorkingTreeStatus.new
      else
        staged = dirty.lines.any? { |line| line =~ /^[MADRC]/ }
        modified = dirty.lines.any? { |line| line =~ /^.[MADRC]/ || line =~ /^.M/ }
        untracked = dirty.lines.any?(&.starts_with?("??"))
        symbols.working_tree = List::WorkingTreeStatus.new(
          staged: staged, modified: modified, untracked: untracked
        )
      end
    end

    private def self.build_main_state(symbols, default_branch, branch, wt_path : String) : List::AheadBehind
      # Compute ahead/behind counts
      ahead = count_commits_ahead(default_branch, branch)
      behind = count_commits_ahead(branch, default_branch)
      ahead_behind = List::AheadBehind.new(ahead: ahead, behind: behind)

      if branch == default_branch
        symbols.main_state = List::MainState::IsMain
        return ahead_behind
      end

      # Check if branch is an orphan (no common ancestor with default)
      orphan_check = Cmd.new("git")
        .args(["merge-base", default_branch, branch])
        .run
      is_orphan = !orphan_check.success?

      # Check if same commit as default
      branch_sha = Cmd.new("git")
        .args(["rev-parse", branch])
        .run
        .stdout
        .strip
      default_sha = Cmd.new("git")
        .args(["rev-parse", default_branch])
        .run
        .stdout
        .strip
      is_same_commit = !branch_sha.empty? && branch_sha == default_sha

      # Check integration status
      repo = Git::Repository.current
      integration_reason = Git::Integration.reason(repo, branch, default_branch)

      # Determine main state using priority chain
      if is_orphan
        symbols.main_state = List::MainState::Orphan
      elsif integration_reason
        symbols.main_state = List::MainState::Integrated
      elsif is_same_commit
        if clean_working_tree?(wt_path)
          symbols.main_state = List::MainState::Empty
        else
          symbols.main_state = List::MainState::SameCommit
        end
      elsif ahead > 0 && behind > 0
        symbols.main_state = List::MainState::Diverged
      elsif ahead > 0
        symbols.main_state = List::MainState::Ahead
      elsif behind > 0
        symbols.main_state = List::MainState::Behind
      else
        symbols.main_state = List::MainState::None
      end

      ahead_behind
    end

    # Check if working tree at path is clean (no uncommitted changes)
    private def self.clean_working_tree?(wt_path : String) : Bool
      return true if wt_path.empty?
      result = Cmd.new("git")
        .args(["status", "--porcelain"])
        .current_dir(wt_path)
        .run
      result.success? && result.stdout.strip.empty?
    end

    private def self.build_worktree_state(symbols, worktree)
      if worktree.locked?
        symbols.worktree_state = List::WorktreeState::Locked
      elsif worktree.prunable?
        symbols.worktree_state = List::WorktreeState::Prunable
      elsif worktree.detached?
        symbols.worktree_state = List::WorktreeState::Branch
      end
    end

    private def self.build_upstream_divergence(symbols, repo, branch, default_branch)
      return if branch == default_branch
      remote_ahead_count = remote_ahead_count(repo, branch)
      remote_behind_count = remote_behind_count(repo, branch)
      if remote_ahead_count || remote_behind_count
        a = remote_ahead_count || 0
        b = remote_behind_count || 0
        symbols.upstream_divergence = List::Divergence.from_counts_with_remote(a, b)
      end
    end

    private def self.build_operation_state(symbols, wt_path)
      if File.directory?(File.join(wt_path, ".git", "rebase-merge")) ||
         File.directory?(File.join(wt_path, ".git", "rebase-apply"))
        symbols.operation_state = List::OperationState::Rebase
      elsif File.exists?(File.join(wt_path, ".git", "MERGE_HEAD"))
        symbols.operation_state = List::OperationState::Merge
      end
    end

    private def self.remote_ahead_count(repo, branch) : Int32?
      result = Cmd.new("git")
        .args(["rev-list", "--count", "HEAD..@{u}"])
        .run
      if result.success? && !result.stdout.strip.empty?
        result.stdout.strip.to_i32
      end
    end

    private def self.remote_behind_count(repo, branch) : Int32?
      result = Cmd.new("git")
        .args(["rev-list", "--count", "@{u}..HEAD"])
        .run
      if result.success? && !result.stdout.strip.empty?
        result.stdout.strip.to_i32
      end
    end

    private def self.worktree_stats(repo, worktree, default_branch)
      branch = worktree.branch
      return {"-", "-", 0, 0, "", ""} unless branch

      # Check working tree status
      wt_path = worktree.path
      dirty = Cmd.new("git")
        .args(["status", "--porcelain"])
        .current_dir(wt_path)
        .run
        .stdout

      status = dirty.empty? ? "clean" : "+"

      # Lines changed since branching
      diff_result = Cmd.new("git")
        .args(["diff", "--shortstat", "#{default_branch}...#{branch}"])
        .run
      changes = if diff_result.success?
                  stat = diff_result.stdout.strip
                  stat.empty? ? "" : format_shortstat(stat)
                else
                  "-"
                end

      # Commits ahead/behind
      ahead = count_commits_ahead(default_branch, branch)
      behind = branch == default_branch ? 0 : count_commits_ahead(branch, default_branch)

      # Remote tracking
      remote_status = branch == default_branch ? remote_ahead(repo) : ""

      # CI status (GitHub Actions)
      ci = ci_status(branch)

      {status, changes, ahead, behind, remote_status, ci}
    end

    # Detect CI platform from a git remote URL.
    def self.platform_for_branch(remote_url : String) : CiPlatform
      url = Git::GitRemoteUrl.parse(remote_url)
      return CiPlatform::Unknown unless url
      CiPlatform.detect(url)
    end

    private def self.ci_status(branch : String) : String
      # Get the remote URL for the repo
      repo = Git::Repository.current rescue nil
      return "" unless repo

      result = Cmd.new("git")
        .args(["remote", "get-url", "origin"])
        .current_dir(repo.discovery_path)
        .run
      return "" unless result.success?
      remote_url = result.stdout.strip
      return "" if remote_url.empty?

      # Detect platform and fetch status
      platform = platform_for_branch(remote_url)
      return "" if platform.unknown?

      status = CiStatus.fetch_ci_status(branch, platform)
      return "" unless status

      status.symbol
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
      path_template_override : String? = nil
      no_hooks = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees switch [options] [branch]"
        parser.on("-c", "--create", "Create a new branch and worktree") { create = true }
        parser.on("-b BASE", "--base=BASE", "Base branch for the new worktree") { |b| base_branch = b }
        parser.on("-x CMD", "--execute=CMD", "Execute a command after switching") { |cmd| execute_cmd = cmd }
        parser.on("-p PATH", "--path-template=PATH", "Worktree path template") { |tpl| path_template_override = tpl }
        parser.on("--no-hooks", "Skip running hooks") { no_hooks = true }
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
      ENV["WORKTREES_NO_HOOKS"] = "1" if no_hooks
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch

      # Resolve the target branch (shortcuts, fzf picker, or explicit)
      resolved, create = resolve_switch_target(repo, branch, current_branch, create)

      # Save current branch as previous (for - shortcut)
      if resolved != current_branch
        Git::BranchResolver.save_previous(current_branch)
      end

      # Load merged config for path template
      merged_config = Config.load_merged(repo.discovery_path)
      path_template = if override = path_template_override
                        override
                      else
                        merged_config.worktree_path_template
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

    private def self.resolve_switch_target(repo, branch, current_branch, create)
      # Interactive picker: if no branch and no --create, use fzf
      if !branch && !create
        if selected = interactive_picker(repo, current_branch)
          if selected != current_branch && !repo.worktree_for_branch(selected)
            return {selected, true}
          end
          return {selected, false}
        else
          exit 0
        end
      end

      # Resolve branch shortcuts
      resolved = if b = branch
                   Git::BranchResolver.resolve(b)
                 else
                   current_branch
                 end
      {resolved, create}
    end

    private def self.interactive_picker(repo, current_branch) : String?
      worktrees = repo.list_worktrees
      return nil if worktrees.empty?
      result = Picker.handle_picker(worktrees, current_branch)
      result.branch
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
        home = Path.home.to_s
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
        # Create a new branch from the base
        repo.run_command(["worktree", "add", "-b", branch, worktree_path, base])
        puts green("✓ Created branch #{branch} from #{base} and worktree @ #{worktree_path}")
        emit_cd_directive(worktree_path)
      rescue ex : Git::CommandError | CmdError
        STDERR.puts red("✗ #{ex.message}")
        exit 1
      end

      # Run post-start hooks if configured
      run_hooks("post-start", hook_vars)

      worktree_path
    end

    private def self.quiet? : Bool
      ENV["WORKTREES_YES"]? == "1"
    end

    # Color helpers
    private def self.green(text) : String
      text.colorize.green.to_s
    end

    private def self.red(text) : String
      Styling.red(text)
    end

    private def self.yellow(text) : String
      Styling.yellow(text)
    end

    private def self.bold(text) : String
      Styling.bold(text)
    end

    private def self.dim(text) : String
      Styling.dim(text)
    end

    private def self.run_hooks(section : String, vars : Hash(String, String))
      return if ENV["WORKTREES_NO_HOOKS"]? == "1"
      repo = Git::Repository.current rescue nil
      groups = [] of Config::HookGroup

      # Load from user config
      user_path = Config.default_config_path
      if File.exists?(user_path)
        groups.concat Config.parse_hooks(File.read(user_path), section)
      end

      # Load from project config
      if repo
        project_path = Config.project_config_path(repo.discovery_path)
        if File.exists?(project_path)
          groups.concat Config.parse_hooks(File.read(project_path), section)
        end
      end

      return if groups.empty?

      groups.each do |group|
        if group.concurrent?
          run_concurrent_hooks(group.hooks, vars)
        else
          run_sequential_hooks(group.hooks, vars)
        end
      end
    end

    private def self.run_concurrent_hooks(hooks, vars)
      wg = WaitGroup.new
      chan = Channel(Tuple(String, String, Bool, Int32)).new(hooks.size)

      hooks.each do |hook_cmd|
        wg.spawn do
          expanded = hook_cmd.expand(vars)
          result = Cmd.new("sh").args(["-c", expanded]).run
          chan.send({hook_cmd.name, expanded, result.success?, result.exit_code})
        end
      end

      wg.wait
      chan.close

      while result = chan.receive?
        name, expanded, success, exit_code = result
        puts "  ▶ #{name}: #{expanded}"
        if success
          puts green("    ✓ #{name} completed")
        else
          STDERR.puts red("    ✗ #{name} failed (exit #{exit_code})")
        end
      end
    end

    private def self.run_sequential_hooks(hooks, vars)
      hooks.each do |hook|
        expanded = hook.expand(vars)
        puts "  ▶ #{hook.name}: #{expanded}"
        result = Cmd.new("sh").args(["-c", expanded]).run
        if result.success?
          puts green("    ✓ #{name} completed")
        else
          STDERR.puts "    ✗ #{hook.name} failed (exit #{result.exit_code})"
          break # Stop pipeline on failure
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
        parser.banner = "Usage: wktrees remove [options] [branch]"
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

        repo.stage_worktree_removal(wt_path, force)
        puts green("✓ Staged removal for worktree @ #{wt_path}")
        puts dim("  (cleanup runs in background)")

        # Run post-remove hooks
        run_hooks("post-remove", remove_vars)

        # Delete branch unless --no-delete-branch
        unless keep_branch
          mode = force_delete ? Git::BranchDeletionMode::ForceDelete : Git::BranchDeletionMode::SafeDelete
          begin
            # Check integration before deleting
            safe = if mode.safe_delete?
                     Git::Integration.check(repo, target, repo.default_branch)
                   else
                     true
                   end
            if safe
              repo.delete_branch(target, mode)
              puts "✓ Deleted branch #{target}"
            else
              STDERR.puts "! Branch #{target} is not merged into #{repo.default_branch}"
              STDERR.puts "  Use -D to force delete, or merge first."
            end
          rescue ex : Git::CommandError | CmdError
            STDERR.puts "! Could not delete branch: #{ex.message}"
          end
        end
      rescue ex : Git::CommandError | CmdError
        STDERR.puts red("✗ #{ex.message}")
        exit 1
      end
    end

    def self.step(args : Array(String))
      sub = args[0]?
      sub_args = args[1..]

      # Show step-level help when --help/-h is for the step command itself
      if sub.nil? || %w[--help -h].includes?(sub)
        puts "Usage: wktrees step <subcommand>"
        puts "Subcommands: commit diff squash rebase push for-each eval prune copy-ignored promote relocate tether statusline"
        exit 0
      end

      dispatch_step(sub, sub_args)
    end

    STEP_HELP = {
      "commit"       => "Usage: wktrees step commit [options]\n\n  Commit staged changes.\n\n  Options:\n    -m MESSAGE, --message=MESSAGE  Commit message\n    -a, --all                      Stage all changes\n    -h, --help                     Show this help",
      "diff"         => "Usage: wktrees step diff [--stat]\n\n  Show the diff of the current worktree.\n\n  Options:\n    --stat  Show diffstat instead of full diff\n    -h, --help  Show this help",
      "squash"       => "Usage: wktrees step squash\n\n  Squash all commits on the current branch since branching.\n  Uses the merge-base with the default branch.",
      "rebase"       => "Usage: wktrees step rebase [target]\n\n  Rebase current branch onto the given target (default: default branch).",
      "push"         => "Usage: wktrees step push [target]\n\n  Push (fast-forward merge) current branch into the target (default: default branch).",
      "for-each"     => "Usage: wktrees step for-each [options] <command>\n\n  Run a command in every worktree.\n\n  Options:\n    --concurrent     Run concurrently\n    -j N, --jobs=N   Max concurrent jobs (default: 8)\n    --dry-run        Show what would be run\n    -h, --help       Show this help",
      "eval"         => "Usage: wktrees step eval <template>\n\n  Evaluate a template expression.\n  Example: wktrees step eval '{{ branch | sanitize }}'",
      "prune"        => "Usage: wktrees step prune\n\n  Remove worktrees for branches that have been merged into the default branch.",
      "copy-ignored" => "Usage: wktrees step copy-ignored [options]\n\n  Copy gitignored files to a new worktree.\n\n  Options:\n    -f, --force  Overwrite existing files\n    -h, --help   Show this help",
      "promote"      => "Usage: wktrees step promote [options]\n\n  Promote the current branch content to another branch.\n\n  Options:\n    -b BRANCH, --branch=BRANCH  Target branch (default: default branch)\n    -h, --help                 Show this help",
      "relocate"     => "Usage: wktrees step relocate\n\n  Move worktrees to their expected paths based on config template.",
      "tether"       => "Usage: wktrees step tether <command>\n\n  Run a command tethered to the current worktree.\n  The command is killed when the worktree is removed.",
      "statusline"   => "Usage: wktrees step statusline\n\n  Print a compact status line for the current worktree.",
    }

    private def self.dispatch_step(sub, sub_args)
      if sub_args.includes?("--help") || sub_args.includes?("-h")
        if help = STEP_HELP[sub]?
          puts help
          exit 0
        end
      end

      # Group 1: commit operations
      case sub
      when "commit" then step_commit(sub_args)
      when "diff"   then step_diff
      when "squash" then step_squash
      when "rebase" then step_rebase(sub_args)
      when "push"   then step_push(sub_args)
      else
        dispatch_step2(sub, sub_args)
      end
    end

    private def self.dispatch_step2(sub, sub_args)
      if sub_args.includes?("--help") || sub_args.includes?("-h")
        if help = STEP_HELP[sub]?
          puts help
          exit 0
        end
      end

      case sub
      when "for-each"     then step_for_each(sub_args)
      when "eval"         then step_eval(sub_args)
      when "prune"        then step_prune
      when "copy-ignored" then step_copy_ignored(sub_args)
      when "promote"      then step_promote(sub_args)
      when "relocate"     then step_relocate
      when "tether"       then step_tether(sub_args)
      when "statusline"   then step_statusline
      else
        STDERR.puts "Usage: wktrees step [commit|diff|squash|rebase|push|for-each|eval|prune|copy-ignored|promote|relocate|tether|statusline]"
        exit 1
      end
    end

    private def self.step_commit(args : Array(String))
      message : String? = nil
      all = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees step commit [options]"
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
        puts green("✓ Committed: #{commit_msg.lines.first}")

        # Post-commit hooks
        commit_vars["commit"] = commit_msg
        run_hooks("post-commit", commit_vars)
      end
    end

    private def self.step_diff
      repo = Git::Repository.current
      args = ["diff"]

      # Check if there are extra args (e.g. --stat, --numstat, branch name)
      # For simplicity, support --stat flag
      if ARGV.includes?("--stat")
        args << "--stat"
      end

      result = Cmd.new("git").args(args).current_dir(repo.discovery_path).run
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
        parser.banner = "Usage: wktrees step rebase [target]"
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
      rescue ex : Git::CommandError | CmdError
        STDERR.puts "✗ Rebase conflict: #{ex.message}"
        STDERR.puts "Resolve conflicts and run: git rebase --continue"
        exit 1
      end
    end

    private def self.step_push(args : Array(String))
      target : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees step push [target]"
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

    private def self.step_for_each(args : Array(String))
      concurrent = false
      max_jobs = 8
      dry_run = false

      # Parse flags; remaining args become the command
      remaining = args.dup
      OptionParser.parse(remaining) do |parser|
        parser.banner = "Usage: wktrees step for-each [options] <command>"
        parser.on("--concurrent", "Run command concurrently across worktrees") { concurrent = true }
        parser.on("-j N", "--jobs=N", "Maximum concurrent jobs (default: 8)") { |num| max_jobs = num.to_i }
        parser.on("--dry-run", "Show what would be executed without running") { dry_run = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      command = remaining.join(" ")

      if command.strip.empty?
        STDERR.puts "Error: No command specified. Usage: wktrees step for-each <command>"
        exit 1
      end

      repo = Git::Repository.current
      worktrees = repo.list_worktrees
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch

      if dry_run
        puts "◎ Would run '#{command}' in #{worktrees.size} worktree(s)..."
        worktrees.each do |worktree|
          branch = worktree.branch || "(detached)"
          marker = worktree.branch == current_branch ? "@" : " "
          puts "  #{marker} #{branch}: #{worktree.path}"
        end
        return
      end

      if concurrent
        step_for_each_concurrent(worktrees, command, current_branch, max_jobs)
      else
        step_for_each_sequential(worktrees, command, current_branch)
      end
    end

    private def self.step_for_each_sequential(worktrees, command, current_branch)
      puts "◎ Running '#{command}' in #{worktrees.size} worktree(s)..."
      puts ""

      worktrees.each do |worktree|
        branch = worktree.branch || "(detached)"
        marker = worktree.branch == current_branch ? "@" : " "

        print "#{marker} #{branch}..."

        result = Cmd.new("sh")
          .args(["-c", command])
          .current_dir(worktree.path)
          .run

        if result.success?
          puts " ✓"
          unless result.stdout.strip.empty?
            result.stdout.each_line { |line| puts "    #{line}" }
          end
        else
          puts " ✗ (exit #{result.exit_code})"
          unless result.stderr.strip.empty?
            result.stderr.each_line { |line| puts "    #{line}" }
          end
        end
      end

      puts ""
      puts "○ Done."
    end

    private def self.step_for_each_concurrent(worktrees, command, current_branch, max_jobs)
      puts "◎ Running '#{command}' in #{worktrees.size} worktree(s) concurrently (max #{max_jobs})..."
      puts ""

      sem = Sync::Semaphore.new(max_jobs)
      done = Channel(Nil).new
      results_mutex = Mutex.new
      results = [] of Tuple(String, String, Bool, Int32)

      worktrees.each do |worktree|
        spawn do
          sem.acquire do
            branch = worktree.branch || "(detached)"
            result = Cmd.new("sh")
              .args(["-c", command])
              .current_dir(worktree.path)
              .run

            output = result.success? ? result.stdout : result.stderr
            results_mutex.synchronize do
              results << {branch, output.strip, result.success?, result.exit_code}
            end
          end
          done.send(nil)
        end
      end

      worktrees.size.times { done.receive }

      # Sort results by branch name for consistent display
      results.sort_by!(&.[0])
      results.each do |branch, output, success, exit_code|
        marker = branch == current_branch ? "@" : " "
        if success
          puts "#{marker} #{branch} ✓"
        else
          puts "#{marker} #{branch} ✗ (exit #{exit_code})"
        end
        output.each_line { |line| puts "    #{line}" } unless output.empty?
      end

      puts ""
      succeeded = results.count { |_, _, success, _| success }
      puts "○ #{succeeded}/#{worktrees.size} succeeded."
    end

    private def self.step_eval(args : Array(String))
      template = args.join(" ")

      if template.strip.empty?
        STDERR.puts "Usage: wktrees step eval <template>"
        STDERR.puts "  Evaluates a template expression with available variables."
        STDERR.puts "  Example: wktrees step eval '{{ branch | sanitize }}'"
        exit 1
      end

      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      worktree_path = repo.current_worktree.path

      vars = {
        "branch"         => branch,
        "worktree_path"  => worktree_path,
        "worktree_name"  => File.basename(worktree_path),
        "repo"           => File.basename(repo.discovery_path),
        "repo_path"      => repo.discovery_path,
        "default_branch" => repo.default_branch,
        "commit"         => repo.current_worktree.head_sha,
        "short_commit"   => repo.current_worktree.head_sha[0, 7],
      }

      result = Template.expand(template, vars)
      puts result
    end

    private def self.step_prune
      repo = Git::Repository.current
      default_branch = repo.default_branch
      worktrees = repo.list_worktrees
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch

      removed = 0
      skipped = 0

      puts "◎ Checking for merged worktrees to prune..."
      puts ""

      worktrees.each do |worktree|
        branch = worktree.branch
        next unless branch
        next if branch == default_branch
        next if branch == current_branch

        # Check if branch is merged (ancestor of default)
        if repo.run_command_check(["merge-base", "--is-ancestor", branch, default_branch])
          puts "  Pruning #{branch} (merged into #{default_branch})..."
          begin
            repo.remove_worktree(worktree.path)
            repo.delete_branch(branch, Git::BranchDeletionMode::SafeDelete)
            puts "  ✓ Pruned #{branch}"
            removed += 1
          rescue ex : Git::CommandError | CmdError
            puts "  ! Could not prune #{branch}: #{ex.message}"
            skipped += 1
          end
        end
      end

      # Also run git worktree prune to clean up stale entries
      repo.prune_worktrees

      puts ""
      puts "○ Pruned #{removed} worktree(s), skipped #{skipped}"
    end

    private def self.generate_commit_message(repo) : String
      config = Config.load_merged(repo.discovery_path)
      branch = repo.current_worktree.current_branch

      # Try LLM generation if configured
      if llm = config.llm_command
        msg = try_llm_commit(llm, config, repo)
        return msg if msg
      end

      # Fallback: derive from branch name
      branch_commit_message(branch)
    end

    private def self.try_llm_commit(llm : String, config : Config::UserConfig, repo) : String?
      diff = Cmd.new("git")
        .args(["diff", "--cached"])
        .current_dir(repo.discovery_path)
        .run
        .stdout

      return nil if diff.strip.empty?

      # Build prompt from config template or default
      base = config.llm_template || "Generate a concise conventional commit message for this diff. Use types: feat, fix, docs, refactor, test, chore, perf, ci. Return ONLY the commit message, no explanation."
      prompt = "#{base}\n\ndiff:\n#{diff}"

      # Append user guidance
      if append = config.llm_template_append
        prompt += "\n\n#{append}"
      end

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

    # -- LLM helpers ----------------------------------------------------------

    SHELL_METACHARACTERS = "&|;<>$`'\"(){}*?[]~!\\"

    # Prepare a diff for LLM consumption by truncating large diffs.
    #
    # Limits: max_chars (default 400K), max_lines_per_file (50), max_files (50).
    def self.prepare_diff(
      diff : String,
      max_chars : Int32 = 400_000,
      max_lines_per_file : Int32 = 50,
      max_files : Int32 = 50,
    ) : String
      return "" if diff.empty?

      # Under threshold: return as-is
      return diff if diff.size <= max_chars

      # Split into per-file diffs
      chunks = diff.split("diff --git ")
      header = chunks.shift || ""
      result = String::Builder.new
      result << header
      file_count = 0

      chunks.each do |chunk|
        break if file_count >= max_files
        file_lines = chunk.lines.to_a
        if file_lines.size > max_lines_per_file + 1
          result << "diff --git "
          result << file_lines.first(max_lines_per_file).join('\n')
          result << "\n... (truncated #{file_lines.size - max_lines_per_file} lines)\n"
        else
          result << "diff --git " << chunk
        end
        file_count += 1
      end

      result.to_s
    end

    # Wrap a command with shell escaping if it contains metacharacters.
    #
    # Simple commands like "llm -m haiku" pass through unchanged.
    # Complex commands get wrapped: "sh -c 'complex && command'"
    def self.shell_wrap_command(command : String) : String
      needs_shell = command.chars.any? { |char| SHELL_METACHARACTERS.includes?(char) }
      return command unless needs_shell

      escaped = command.gsub("'", "'\\''")
      "sh -c '#{escaped}'"
    end

    # Build a branch summary prompt for LLM-based diff summarization.
    #
    # Follows the upstream format: subject line + body summary.
    # Returns empty string for empty diffs (no summary to generate).
    def self.build_summary_prompt(diff : String) : String
      return "" if diff.strip.empty?

      <<-PROMPT
      Summarize the changes in this branch diff. Format your response as:

      <subject>: one sentence, max 80 chars, describing what the branch does
      <body>: 2-4 bullet points explaining the key changes

      diff:
      #{diff}
      PROMPT
    end

    # Generate a branch summary using the configured LLM command.
    #
    # Gets the combined diff for a branch, pipes it to the LLM,
    # and returns the first line as the summary subject.
    def self.generate_branch_summary(diff : String) : String?
      return nil if diff.strip.empty?

      config = Config.load_default
      llm = config.llm_command || ENV["WORKTREES_LLM"]? || "llm"
      prompt = build_summary_prompt(diff)

      result = Cmd.new(llm)
        .stdin_data(prompt)
        .run

      if result.success? && !result.stdout.strip.empty?
        first_line = result.stdout.strip.lines.first.strip
        first_line unless first_line.empty?
      end
    end

    def self.merge(args : Array(String))
      target : String? = nil
      no_commit = false
      no_squash = false
      no_rebase = false
      no_remove = false
      no_ff = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees merge [options] [target]"
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
      rescue ex : Git::CommandError | CmdError
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
      result = Git::Recovery::CleanupResult.new

      if wt_path = repo.worktree_for_branch(branch)
        begin
          repo.remove_worktree(wt_path)
          result.worktree_removed = true

          integrated = Git::Integration.check(repo, branch, target_branch)
          if integrated
            repo.delete_branch(branch, Git::BranchDeletionMode::SafeDelete)
            result.branch_deleted = true
            puts "✓ Removed #{branch} worktree and branch"
          else
            puts "✓ Removed #{branch} worktree (branch kept — not integrated)"
          end

          if target_path = repo.worktree_for_branch(target_branch)
            result.cd_path = target_path
            emit_cd_directive(target_path)
          end
        rescue ex : Git::CommandError | CmdError
          STDERR.puts Styling.warning_message("Could not remove worktree: #{ex.message}")
          # Try staged removal as fallback
          begin
            repo.stage_worktree_removal(wt_path, force: false)
            result.worktree_removed = true
            STDERR.puts Styling.hint_message("Worktree staged for background removal")
          rescue
            STDERR.puts Styling.error_message("Failed to stage worktree for removal")
          end
        end
      end

      result
    end

    def self.shell(args : Array(String))
      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees shell init [bash|zsh|fish]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      sub = args[0]?
      case sub
      when "init"
        arg = args[1]?
        shell_type = if arg
                       case arg
                       when "zsh", "z"         then :zsh
                       when "fish", "f"        then :fish
                       when "nu", "nushell"    then :nu
                       when "ps", "powershell" then :ps
                       else                         :bash
                       end
                     else
                       shell_type_from_env
                     end
        puts Shell.generate(shell_type)
      when "install"
        shell_install
      when "uninstall"
        shell_uninstall
      when "completions"
        shell_completions(args[1..])
      else
        STDERR.puts "Usage: wktrees shell [init|install|uninstall|completions] [bash|zsh|fish]"
        exit 1
      end
    end

    def self.config(args : Array(String))
      project = false
      full = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees config [show|create] [--project] [--full]"
        parser.on("--project", "Create project config (.config/wt.toml)") { project = true }
        parser.on("--full", "Show resolved config with defaults and hooks") { full = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      sub = args[0]?

      case sub
      when "show"
        if project
          config_show_project
        elsif full
          config_show_resolved
        else
          config_show
        end
      when "create"
        config_create(project)
      when "state"
        config_state(args[1..])
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
        puts "# Create one with: wktrees config create"
      end
    end

    private def self.config_create(project = false)
      if project
        repo = Git::Repository.current
        config_path = Config.project_config_path(repo.discovery_path)
      else
        config_path = Config.default_config_path
      end

      if File.exists?(config_path)
        STDERR.puts "Config already exists at #{config_path}"
        exit 1
      end

      dir = File.dirname(config_path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      config = Config::UserConfig.new
      toml_content = "# WorkTrees configuration\nworktree-path = \"#{config.worktree_path_template}\"\n\n# Hooks — add commands at lifecycle events:\n# [pre-start]\n# deps = \"npm install\"\n# [post-start]\n# server = \"npm run dev\"\n# [post-remove]\n# cleanup = \"echo 'removed {{ branch }}'\"\n"
      File.write(config_path, toml_content)
      puts "✓ Created #{project ? "project " : ""}config at #{config_path}"
    end

    private def self.config_show_resolved
      user_path = Config.default_config_path
      user_config = Config.load_default
      repo = Git::Repository.current rescue nil
      project_config = repo ? Config.load_project(repo.discovery_path) : nil

      puts "=== Resolved Configuration ==="
      puts ""

      show_resolved_path(user_config, project_config, user_path)
      show_resolved_hooks(repo, project_config, user_path)
      show_resolved_aliases(user_path)
      show_resolved_state
    end

    private def self.show_resolved_path(user_config, project_config, user_path)
      puts "[worktree-path]"
      puts "  default: #{Config::UserConfig::DEFAULT_PATH_TEMPLATE}"
      puts "  user:    #{user_config.worktree_path_template}" if File.exists?(user_path)
      if project_config && (pt = project_config.worktree_path_template)
        puts "  project: #{pt}"
      end
      merged = project_config.try(&.worktree_path_template) || user_config.worktree_path_template
      puts "  => #{merged}"
      puts ""
    end

    private def self.show_resolved_hooks(repo, project_config, user_path)
      puts "[commit.generation]"
      user_config = Config.load_default
      puts "  command: #{user_config.llm_command || "(not set)"}"
      if project_config && (llm = project_config.llm_command)
        puts "  project: #{llm}"
      end
      puts ""

      puts "[hooks]"
      Config::HOOK_SECTIONS.each do |section|
        user_groups = Config.parse_hooks(File.read(user_path), section) rescue [] of Config::HookGroup
        project_groups = if project_config && repo
                           project_path = Config.project_config_path(repo.discovery_path)
                           Config.parse_hooks(File.read(project_path), section) rescue [] of Config::HookGroup
                         else
                           [] of Config::HookGroup
                         end
        user_hooks = user_groups.flat_map(&.hooks)
        project_hooks = project_groups.flat_map(&.hooks)
        next if user_hooks.empty? && project_hooks.empty?
        puts "  [#{section}]"
        user_hooks.each { |hook| puts "    user.#{hook.name}: #{hook.command}" }
        project_hooks.each { |hook| puts "    project.#{hook.name}: #{hook.command}" }
      end
      puts ""
    end

    private def self.show_resolved_aliases(user_path)
      if File.exists?(user_path)
        aliases = Config.parse_aliases(File.read(user_path))
        unless aliases.empty?
          puts "[aliases]"
          aliases.each { |key, value| puts "  #{key} = #{value}" }
          puts ""
        end
      end
    end

    private def self.show_resolved_state
      puts "[state]"
      repo = Git::Repository.current rescue nil
      if repo
        puts "  default-branch: #{repo.default_branch}"
        prev = Cmd.new("git")
          .args(["config", "--local", "worktrees.history"])
          .run
        if prev.success? && !prev.stdout.strip.empty?
          puts "  previous-branch: #{prev.stdout.strip}"
        end
      end
      puts ""
      puts "[state vars (current branch)]"
      vars_result = Cmd.new("git")
        .args(["config", "--local", "--get-regexp", "^worktrees\\.state\\."])
        .run rescue nil
      if vars_result && vars_result.success? && !vars_result.stdout.strip.empty?
        vars_result.stdout.each_line { |line| puts "  #{line.strip}" }
      else
        puts "  (none)"
      end
    end

    private def self.config_show_project
      repo = Git::Repository.current
      project_path = Config.project_config_path(repo.discovery_path)
      if File.exists?(project_path)
        puts File.read(project_path)
      else
        puts "No project config at #{project_path}"
        puts "Create with: wktrees config create --project"
      end
    end

    private def self.config_state(args : Array(String))
      sub = args[0]?

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees config state <key> [action]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          puts ""
          puts "Keys:"
          puts "  vars            Manage per-branch state variables"
          puts "  default-branch  Get, set, or clear the default branch"
          puts "  previous-branch Get, set, or clear the previous branch"
          exit 0
        end
      end

      case sub
      when "vars"
        state_vars(args[1..])
      when "default-branch"
        state_default_branch(args[1..])
      when "previous-branch"
        state_previous_branch(args[1..])
      else
        STDERR.puts "Usage: wktrees config state <key> [action]"
        STDERR.puts "Keys: vars, default-branch, previous-branch"
        STDERR.puts "Run: wktrees config state --help"
        exit 1
      end
    end

    private def self.state_vars(args : Array(String))
      action = args[0]?
      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      prefix = "worktrees.state.#{branch}.vars"

      case action
      when "set"
        key = args[1]?
        value = args[2]?
        unless key && value
          STDERR.puts "Usage: wktrees config state vars set <key> <value>"
          exit 1
        end
        repo.run_command(["config", "--local", "#{prefix}.#{key}", value])
        puts "✓ Set #{key}=#{value} for #{branch}"
      when "get"
        key = args[1]?
        unless key
          STDERR.puts "Usage: wktrees config state vars get <key>"
          exit 1
        end
        result = Cmd.new("git")
          .args(["config", "--local", "#{prefix}.#{key}"])
          .run
        if result.success?
          puts result.stdout.strip
        else
          puts "(unset)"
        end
      when "list"
        result = Cmd.new("git")
          .args(["config", "--local", "--get-regexp", "^#{prefix}\\."])
          .run
        if result.success? && !result.stdout.strip.empty?
          result.stdout.each_line do |line|
            k, v = line.split(' ', 2).map(&.strip)
            short_key = k.lchop("#{prefix}.")
            puts "  #{short_key} = #{v}"
          end
        else
          puts "No state variables for #{branch}"
        end
      when "clear"
        result = Cmd.new("git")
          .args(["config", "--local", "--get-regexp", "^#{prefix}\\."])
          .run
        if result.success?
          result.stdout.each_line do |line|
            key = line.split(' ', 2).first
            Cmd.new("git").args(["config", "--local", "--unset", key]).run
          end
          puts "✓ Cleared state variables for #{branch}"
        else
          puts "No state variables to clear for #{branch}"
        end
      else
        STDERR.puts "Usage: wktrees config state vars [set|get|list|clear]"
        exit 1
      end
    end

    private def self.state_default_branch(args : Array(String))
      action = args[0]? || "get"
      repo = Git::Repository.current

      case action
      when "get"
        default = repo.default_branch
        puts default
      when "set"
        value = args[1]?
        unless value
          STDERR.puts "Usage: wktrees config state default-branch set <branch>"
          exit 1
        end
        repo.run_command(["config", "--local", "worktrees.default-branch", value])
        puts "✓ Set default branch to #{value}"
      when "clear"
        result = Cmd.new("git")
          .args(["config", "--local", "--unset", "worktrees.default-branch"])
          .run
        if result.success?
          puts "✓ Cleared default branch cache"
        else
          puts "No default branch cache to clear"
        end
      else
        STDERR.puts "Usage: wktrees config state default-branch [get|set|clear]"
        exit 1
      end
    end

    private def self.state_previous_branch(args : Array(String))
      action = args[0]? || "get"
      repo = Git::Repository.current

      case action
      when "get"
        result = Cmd.new("git")
          .args(["config", "--local", "worktrees.history"])
          .run
        if result.success?
          puts result.stdout.strip
        else
          puts ""
        end
      when "set"
        value = args[1]?
        unless value
          STDERR.puts "Usage: wktrees config state previous-branch set <branch>"
          exit 1
        end
        repo.run_command(["config", "--local", "worktrees.history", value])
        puts "✓ Set previous branch to #{value}"
      when "clear"
        result = Cmd.new("git")
          .args(["config", "--local", "--unset", "worktrees.history"])
          .run
        if result.success?
          puts "✓ Cleared previous branch"
        else
          puts "No previous branch to clear"
        end
      else
        STDERR.puts "Usage: wktrees config state previous-branch [get|set|clear]"
        exit 1
      end
    end

    private def self.shell_install
      rc_file = shell_rc_file
      return unless rc_file

      if File.exists?(rc_file) && File.read(rc_file).includes?("wktrees shell init")
        puts "Shell integration already installed in #{rc_file}"
        return
      end

      line = "eval \"$(wktrees shell init #{shell_type_from_env})\""
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
      unless content.includes?("wktrees shell init")
        puts "WorkTrees shell integration not found in #{rc_file}"
        return
      end

      cleaned = content.lines.reject { |line| line.includes?("wktrees shell init") || line.strip == "# WorkTrees shell integration" }
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
      elsif shell_path.includes?("nu")
        :nu
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
      when :nu   then File.join(home, ".config", "nushell", "config.nu")
      when :ps   then File.join(home, "Documents", "PowerShell", "Microsoft.PowerShell_profile.ps1")
      else            File.join(home, ".bashrc")
      end
    end

    private def self.shell_completions(args : Array(String))
      arg = args[0]?
      shell = if arg
                case arg
                when "zsh"  then :zsh
                when "fish" then :fish
                else             :bash
                end
              else
                shell_type_from_env
              end

      case shell
      when :bash then puts bash_completions
      when :zsh  then puts zsh_completions
      when :fish then puts fish_completions
      end
    end

    def self.bash_completions : String
      <<-BASH
      _wktrees_complete() {
          local cur prev words cword
          _init_completion || return
          local step_subs
          step_subs="commit diff squash rebase push for-each eval prune copy-ignored promote relocate tether statusline"
          if [[ "${prev}" == "step" ]]; then
              COMPREPLY=($(compgen -W "$step_subs" -- "$cur"))
          else
              COMPREPLY=($(compgen -W "list switch remove step merge hook config shell help" -- "$cur"))
          fi
      }
      complete -F _wktrees_complete wktrees
      BASH
    end

    private def self.zsh_completions : String
      <<-ZSH
      #compdef wktrees
      local -a step_subs
      step_subs=(commit diff squash rebase push for-each eval prune copy-ignored promote relocate tether statusline)
      _wktrees() {
          _arguments \\
              '1:command:(list switch remove step merge hook config shell help)' \\
              '*::arg:->args'
          case $state in
              args)
                  case $words[1] in
                      step)
                          _values 'step subcommand' $step_subs
                          ;;
                  esac
                  ;;
          esac
      }
      _wktrees
      ZSH
    end

    private def self.fish_completions : String
      <<-FISH
      complete -c wktrees -f
      complete -c wktrees -a "list switch remove step merge hook config shell help"
      set -l step_subs commit diff squash rebase push for-each eval prune copy-ignored promote relocate tether statusline
      complete -c wktrees -n "__fish_seen_subcommand_from step" -a "$step_subs"
      FISH
    end

    def self.hook_command(args : Array(String))
      sub = args[0]?

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees hook [show|run] [filter]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      case sub
      when "show"
        hook_show(args[1..])
      when "run"
        hook_run(args[1..])
      else
        hook_show(args[1..])
      end
    end

    private def self.hook_show(filters : Array(String) = [] of String)
      repo = Git::Repository.current
      user_path = Config.default_config_path
      project_path = Config.project_config_path(repo.discovery_path)
      branch = repo.current_worktree.current_branch

      parsed_filters = filters.map { |filter| Config::ParsedFilter.parse(filter) }

      puts "=== Hooks ==="
      puts ""

      # Show user hooks
      if File.exists?(user_path)
        show_user = parsed_filters.empty? || parsed_filters.any?(&.matches_source?(Config::HookSource::User))
        if show_user
          puts "User (#{user_path}):"
          Config::HOOK_SECTIONS.each do |section|
            groups = Config.parse_hooks(File.read(user_path), section)
            hooks = groups.flat_map(&.hooks)
            filtered = filter_hooks_by_name(hooks, parsed_filters)
            unless filtered.empty?
              puts "  [#{section}]"
              filtered.each { |hook| puts "    #{hook.name}: #{hook.command}" }
            end
          end
          puts ""
        end
      end

      # Show project hooks
      if File.exists?(project_path)
        show_project = parsed_filters.empty? || parsed_filters.any?(&.matches_source?(Config::HookSource::Project))
        if show_project
          puts "Project (#{project_path}):"
          Config::HOOK_SECTIONS.each do |section|
            groups = Config.parse_hooks(File.read(project_path), section)
            hooks = groups.flat_map(&.hooks)
            filtered = filter_hooks_by_name(hooks, parsed_filters)
            unless filtered.empty?
              puts "  [#{section}]"
              filtered.each { |hook| puts "    #{hook.name}: #{hook.command}" }
            end
          end
          puts ""
        end
      end

      unless File.exists?(user_path) || File.exists?(project_path)
        puts "No hooks configured."
        puts "Add hooks to ~/.config/worktrees/config.toml or .config/wt.toml"
      end

      puts "Available variables: branch, worktree_path, worktree_name,"
      puts "  repo, repo_path, commit, short_commit, default_branch,"
      puts "  base (switch), target (merge/remove), hook_type, hook_name"
      puts ""
      puts "Current: branch=#{branch}"
    end

    # Filter hooks by parsed name+source filters.
    # An empty filters list passes all hooks through.
    private def self.filter_hooks_by_name(hooks : Array(Config::HookCommand), filters : Array(Config::ParsedFilter)) : Array(Config::HookCommand)
      return hooks if filters.empty?
      hooks.select do |hook|
        filters.any? do |filter|
          filter.name.empty? || hook.name == filter.name
        end
      end
    end

    private def self.hook_run(args : Array(String))
      hook_type = args[0]?

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees hook run <type>"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          puts ""
          puts "Hook types: pre-start, post-start, pre-switch, post-switch,"
          puts "  pre-commit, post-commit, pre-merge, post-merge,"
          puts "  pre-remove, post-remove"
          exit 0
        end
      end

      unless hook_type
        STDERR.puts "Error: No hook type specified."
        STDERR.puts "Usage: wktrees hook run <type>"
        STDERR.puts ""
        STDERR.puts "Hook types: pre-start, post-start, pre-switch, post-switch,"
        STDERR.puts "  pre-commit, post-commit, pre-merge, post-merge,"
        STDERR.puts "  pre-remove, post-remove"
        exit 1
      end

      repo = Git::Repository.current
      branch = repo.current_worktree.current_branch
      vars = {
        "branch"         => branch,
        "worktree_path"  => repo.current_worktree.path,
        "repo"           => File.basename(repo.discovery_path),
        "default_branch" => repo.default_branch,
      }

      puts "◎ Running #{hook_type} hooks..."
      run_hooks(hook_type, vars)
      puts "✓ Done."
    end

    private def self.step_copy_ignored(args : Array(String))
      source : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees step copy-ignored [--source BRANCH]"
        parser.on("--source=BRANCH", "Source branch (default: default branch)") { |src| source = src }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      repo = Git::Repository.current
      current_path = repo.current_worktree.path
      current_branch = repo.current_worktree.current_branch

      source_branch = if s = source
                        s
                      else
                        repo.default_branch
                      end

      source_path = repo.worktree_for_branch(source_branch)
      unless source_path
        STDERR.puts "Error: No worktree for #{source_branch}"
        exit 1
      end

      puts "◎ Copying gitignored files from #{source_branch} → #{current_branch}..."

      # Use rsync to copy gitignored files (respects .gitignore)
      # --exclude='.git' --filter=':- .gitignore'
      result = Cmd.new("rsync")
        .args(["-a", "--filter=:- .gitignore", "--exclude=.git", "#{source_path}/", "#{current_path}/"])
        .run

      if result.success?
        puts "✓ Copied gitignored files from #{source_branch}"
      else
        STDERR.puts "! rsync failed (rsync may not be installed)"
        STDERR.puts "  #{result.stderr.lines.first?}"
      end
    end

    private def self.step_promote(args : Array(String))
      target : String? = nil

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: wktrees step promote [target-branch]"
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
        parser.unknown_args do |before, _after|
          target = before[0]? if before.size > 0
        end
      end

      repo = Git::Repository.current
      current_branch = repo.current_worktree.current_branch
      default_branch = repo.default_branch
      target_branch = if t = target
                        t
                      else
                        default_branch
                      end

      target_path = repo.worktree_for_branch(target_branch)
      unless target_path
        STDERR.puts "Error: No worktree for #{target_branch}"
        exit 1
      end

      current_path = repo.current_worktree.path

      puts "◎ Swapping #{current_branch} ↔ #{target_branch}..."

      # Checkout target in current worktree, feature in target worktree
      Cmd.new("git").args(["checkout", target_branch]).current_dir(current_path).run!
      Cmd.new("git").args(["checkout", current_branch]).current_dir(target_path).run!

      puts "✓ #{current_branch} is now in #{target_path}"
      puts "  #{target_branch} is now in #{current_path}"
    end

    private def self.step_relocate
      repo = Git::Repository.current
      config = Config.load_merged(repo.discovery_path)
      worktrees = repo.list_worktrees
      relocated = 0

      puts "◎ Checking worktree paths..."

      worktrees.each do |worktree|
        branch = worktree.branch
        next unless branch

        # Compute expected path from config template
        vars = {"branch" => branch, "repo" => File.basename(repo.discovery_path)}
        expected_path = Template.expand(config.worktree_path_template, vars)
        expected_path = if expected_path.starts_with?("~/")
                          File.join(Path.home.to_s, expected_path[2..])
                        else
                          File.expand_path(expected_path)
                        end

        # Skip if already at expected path
        current_path = worktree.path
        next if current_path == expected_path

        if Dir.exists?(expected_path)
          puts "  #{branch}: skipping (target exists: #{expected_path})"
        else
          puts "  #{branch}: #{worktree.path} → #{expected_path}"
          begin
            File.rename(worktree.path, expected_path)
            Cmd.new("git").args(["worktree", "repair"]).current_dir(expected_path).run
            relocated += 1
          rescue ex : File::Error
            puts "    ! Cannot move: #{ex.message}"
          end
        end
      end

      if relocated > 0
        puts ""
        puts "✓ Relocated #{relocated} worktree(s)"
      else
        puts "○ All worktrees at expected paths."
      end
    end

    private def self.step_tether(args : Array(String))
      command = args.join(" ")

      if command.strip.empty?
        STDERR.puts "Usage: wktrees step tether <command>"
        STDERR.puts "  Runs a command and kills it when the worktree is removed."
        exit 1
      end

      repo = Git::Repository.current
      worktree_path = repo.current_worktree.path
      branch = repo.current_worktree.current_branch

      puts "◎ Tethered: #{command}"
      puts "  Worktree: #{branch} @ #{worktree_path}"
      puts "  (kill with: wktrees remove #{branch})"
      puts ""

      # Run command in background, monitor worktree dir
      process = Process.new(
        "sh",
        ["-c", command],
        chdir: worktree_path,
        input: Process::Redirect::Close,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      # Monitor worktree — if directory is removed, kill the process
      spawn do
        loop do
          sleep 2.seconds
          unless Dir.exists?(worktree_path)
            puts ""
            puts "! Worktree removed, terminating tethered process..."
            process.signal(Signal::TERM) rescue nil
            sleep 1.second
            process.signal(Signal::KILL) rescue nil
            break
          end
        end
      end

      process.wait
      puts ""
      puts "○ Tethered process exited."
    end

    private def self.step_statusline
      repo = Git::Repository.current
      worktree = repo.current_worktree
      branch = worktree.current_branch
      default_branch = repo.default_branch
      wt_path = worktree.path

      # Build a lightweight WorktreeInfo-compatible object for status computation
      wt_info = Git::WorktreeInfo.new(wt_path, worktree.head_sha, branch)

      # Build status symbols for the current worktree
      symbols, ahead_behind, _divergence = worktree_status_symbols(repo, wt_info, default_branch)
      working_diff = working_tree_diff(wt_path, branch)

      # Build segments in priority order (matches ColumnKind priority)
      segments = [] of String

      # Branch name
      segments << branch

      # Status
      status = symbols.format_compact
      segments << status unless status.strip.empty?

      # Working diff
      segments << working_diff unless working_diff.empty?

      # Ahead/behind
      if ahead_behind.ahead > 0
        segments << "↑#{ahead_behind.ahead}"
      end
      if ahead_behind.behind > 0
        segments << "↓#{ahead_behind.behind}"
      end

      # Upstream
      if ud = symbols.upstream_divergence
        s = ud.styled || ud.symbol
        segments << s unless s.empty?
      end

      # Operation state
      if os = symbols.operation_state
        s = os.styled || os.display
        segments << s unless s.empty?
      end

      puts "[#{segments.join(" ")}]"
    end

    # Render minimal markdown to ANSI-styled text for CLI help output.
    #
    # Supports: headings (#, ##, ###), bold (**text**), inline code (`text`),
    # fenced code blocks (```), bullet lists (- or *), and HTML comment skipping.
    def self.render_markdown(text : String) : String
      result = String::Builder.new
      in_code_block = false
      code_lines = [] of String

      text.each_line do |line|
        trimmed = line.strip

        # Skip HTML comments
        if trimmed.starts_with?("<!--") && trimmed.ends_with?("-->")
          next
        end

        # Handle code fences
        if trimmed.starts_with?("```")
          if !in_code_block
            in_code_block = true
            code_lines.clear
          else
            in_code_block = false
            unless code_lines.empty?
              content = code_lines.join('\n')
              result << Styling.format_with_gutter(content, max_width: nil)
              result << '\n'
            end
          end
          next
        end

        if in_code_block
          code_lines << line
          next
        end

        # Render inline formatting
        rendered = render_inline_formatting(line)
        result << rendered
        result << '\n'
      end

      # Unclosed code fence — render accumulated lines
      if in_code_block && !code_lines.empty?
        content = code_lines.join('\n')
        result << Styling.format_with_gutter(content, max_width: nil)
        result << '\n'
      end

      result.to_s.rstrip('\n')
    end

    # Render inline markdown formatting within a single line.
    private def self.render_inline_formatting(line : String) : String
      # Headings: # Title → green Title
      if line.starts_with?("### ")
        return Styling.green(line[4..])
      elsif line.starts_with?("## ")
        return Styling.format_heading(line[3..])
      elsif line.starts_with?("# ")
        return Styling.format_heading(line[2..])
      end

      # Bullet list items
      if matched = line.match(/^(\s*)([-*])\s+(.+)/)
        indent = matched[1]
        content = matched[3]
        return "#{indent}  #{render_inline_formatting(content)}"
      end

      # Bold: **text** → bold text
      line = line.gsub(/\*\*(.+?)\*\*/) { Styling.bold($1) }

      # Inline code: `text` → dim text
      line = line.gsub(/`([^`]+)`/) { Styling.dim($1) }

      line
    end

    # -- Column layout for list tables -----------------------------------------

    # Calculate column widths based on terminal width and content sizes.
    #
    # Returns an array of widths (one per column) that sums to `terminal`.
    # Wider content gets proportionally more space. Short content gets
    # a minimum width equal to its header length.
    def self.calculate_column_widths(
      headers : Array(String),
      data : Array(Array(String)),
      terminal : Int32,
    ) : Array(Int32)
      n = headers.size
      return [] of Int32 if n == 0

      # Find max content width per column
      max_widths = headers.map(&.size)
      data.each do |row|
        row.each_with_index do |cell, i|
          break if i >= n
          max_widths[i] = {max_widths[i], cell.size}.max if cell
        end
      end

      # Distribute terminal width proportionally
      total_max = max_widths.sum
      if total_max <= terminal
        # All columns fit — distribute extra space evenly
        extra = terminal - total_max
        per_col = extra // n
        remainder = extra % n
        return max_widths.map_with_index { |width, idx| width + per_col + (idx < remainder ? 1 : 0) }
      end

      # Need to compress — allocate proportionally based on max widths
      widths = max_widths.map do |max_w|
        {((max_w.to_f32 / total_max) * terminal).to_i, 1}.max
      end

      # Fix rounding so they sum to terminal
      delta = terminal - widths.sum
      i = 0
      while delta > 0
        widths[i] += 1
        i = (i + 1) % n
        delta -= 1
      end
      while delta < 0 && widths.any? { |width| width > 1 }
        idx = widths.index { |width| width > 1 } || 0
        widths[idx] -= 1
        delta += 1
      end

      widths
    end

    # Build a lipgloss-styled table for list output.
    #
    # Renders headers and data rows using lipgloss StyleTable with
    # terminal-width-aware column sizing.
    def self.build_list_table(
      headers : Array(String),
      rows : Array(Array(String)),
      terminal : Int32,
    ) : String
      table = Lipgloss::StyleTable::Table.new
        .border(Lipgloss::Border.hidden)

      # Set headers (up to 8 columns, pad with empty strings)
      h = headers
      table.headers(
        h.fetch(0, ""), h.fetch(1, ""), h.fetch(2, ""), h.fetch(3, ""),
        h.fetch(4, ""), h.fetch(5, ""), h.fetch(6, ""), h.fetch(7, ""),
      )

      rows.each { |row| table.row(row) }
      table.width(terminal)
      table.render
    end
  end
end
