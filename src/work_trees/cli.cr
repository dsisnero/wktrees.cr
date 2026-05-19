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
          help     Show this help

      OPTIONS:
          -h, --help     Show this help
          --version      Print version
      HELP
    end
  end

  module Commands
    def self.list(args : Array(String))
      full = false

      OptionParser.parse(args) do |parser|
        parser.banner = "Usage: work_trees list [options]"
        parser.on("-f", "--full", "Show full details (CI status, diff stats)") { full = true }
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
      # Header
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
      # Wider header with more columns
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
  end
end
