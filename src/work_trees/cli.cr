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
      when "help", "--help", "-h"
        print_help
        exit 0
      else
        STDERR.puts "Unknown command: #{command}"
        STDERR.puts "Run 'work_trees help' for usage."
        exit 1
      end
    end

    def self.print_help
      puts <<-HELP
      work_trees #{WorkTrees::VERSION}
      A CLI for Git worktree management, designed for parallel AI agent workflows.

      USAGE:
          work_trees <command> [options]

      COMMANDS:
          list     List all worktrees with branch info
          switch   Switch to or create a worktree
          remove   Remove a worktree and optionally its branch
          help     Show this help

      OPTIONS:
          -h, --help     Show this help
      HELP
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
      puts "  %-30s %-20s %-8s %-5s %s" % ["Branch", "Worktree", "HEAD", "Bare?", "SHA"]
      puts "-" * 90

      worktrees.each do |worktree|
        marker = worktree.branch == current_branch ? "@" : " "
        branch = worktree.branch || "(detached)"
        name = worktree.dir_name
        short_head = worktree.head[0, 7]
        bare = worktree.bare? ? "yes" : "no"

        puts "#{marker} %-30s %-20s %-8s %-5s %s" % [branch, name, short_head, bare, worktree.head]
      end

      puts ""
      puts "○ Showing #{worktrees.size} worktree(s)"
    end

    def self.switch(args : Array(String))
      create = false
      base_branch : String? = nil
      branch : String? = nil
      execute_cmd : String? = nil
      path_template = "~/worktrees/{{ branch | sanitize }}"

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
        parser.unknown_args do |_before, after|
          branch = after[0]? if after.size > 0
        end
      end

      exec = execute_cmd
      repo = Git::Repository.current
      current_wt = repo.current_worktree
      current_branch = current_wt.current_branch
      worktree_path : String? = nil

      if create
        worktree_path = switch_create(repo, branch, base_branch, path_template)
      else
        worktree_path = switch_to_existing(repo, branch, current_branch)
      end

      # Execute command if requested
      if exec && (cmd = exec)
        target_path = worktree_path || "."
        puts "Executing: #{cmd}"
        Cmd.new("sh").args(["-c", cmd]).current_dir(target_path).run
      end
    end

    private def self.switch_create(repo, branch, base_branch, path_template)
      unless branch
        STDERR.puts "Error: --create requires a branch name"
        exit 1
      end

      vars = {"branch" => branch, "repo" => File.basename(repo.discovery_path)}
      worktree_path = Template.expand(path_template, vars)
      worktree_path = File.expand_path(worktree_path)
      base = base_branch || repo.default_branch

      if existing = repo.worktree_for_branch(branch)
        STDERR.puts "Error: Worktree already exists for '#{branch}' at #{existing}"
        exit 1
      end

      puts "◎ Creating worktree for #{branch} from #{base}..."
      puts "  Path: #{worktree_path}"

      begin
        repo.run_command(["worktree", "add", "-b", branch, worktree_path, base])
        puts "✓ Created branch #{branch} from #{base} and worktree @ #{worktree_path}"
      rescue ex : Git::CommandError
        STDERR.puts "✗ #{ex.message}"
        exit 1
      end
      worktree_path
    end

    private def self.switch_to_existing(repo, branch, current_branch)
      target = branch || current_branch
      wt_path = repo.worktree_for_branch(target)
      unless wt_path
        STDERR.puts "Error: No worktree found for branch '#{target}'"
        STDERR.puts "Use --create to create a new worktree for this branch."
        exit 1
      end

      puts "Switching to worktree for #{target} @ #{wt_path}"
      puts "(cd #{wt_path} to switch manually — shell integration coming soon)"
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
        parser.unknown_args do |_before, after|
          branch = after[0]? if after.size > 0
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

      begin
        repo.remove_worktree(wt_path, force)
        puts "✓ Removed worktree @ #{wt_path}"

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
  end
end
