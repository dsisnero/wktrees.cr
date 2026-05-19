# Core error types for git and worktree operations.
#
# Ported from vendor/worktrunk/src/git/error.rs
#
# Two-layer error architecture:
#   - `CommandError`: structured subprocess failure (program, args, stderr, stdout, exit_code)
#   - `GitError`: abstract base for typed domain errors
#   - `WorktrunkError`: semantic errors with exit codes

module WorkTrees
  module Git
    # Platform-specific reference type (PR vs MR).
    #
    # Port of `RefType` (error.rs:41).
    enum RefType
      Pr
      Mr

      def symbol : String
        case self
        in .pr? then "#"
        in .mr? then "!"
        end
      end

      def name : String
        case self
        in .pr? then "PR"
        in .mr? then "MR"
        end
      end

      def name_plural : String
        case self
        in .pr? then "PRs"
        in .mr? then "MRs"
        end
      end

      def syntax : String
        case self
        in .pr? then "pr:"
        in .mr? then "mr:"
        end
      end

      def display(number : UInt32) : String
        "#{name} #{symbol}#{number}"
      end
    end

    # Typed leaf error for a command that exited non-zero.
    #
    # Port of `CommandError` (error.rs:202).
    class CommandError < Exception
      getter program : String
      getter args : Array(String)
      getter stderr : String
      getter stdout : String
      getter exit_code : Int32?

      def initialize(@program, @args, @stderr, @stdout, @exit_code)
        msg = build_message
        super(msg)
      end

      def command_string : String
        if @args.empty?
          @program
        else
          "#{@program} #{@args.join(" ")}"
        end
      end

      def combined_output : String
        pieces = [@stderr.strip, @stdout.strip].reject(&.empty?)
        pieces.join('\n')
      end

      private def build_message : String
        cmd = @args.empty? ? @program : "#{@program} #{@args.join(" ")}"
        if code = @exit_code
          "#{cmd} failed (exit #{code})"
        else
          "#{cmd} failed"
        end
      end
    end

    # Abstract base for typed Git errors.
    abstract class GitError < Exception
    end

    # --- Git state errors ---

    class DetachedHead < GitError
      getter action : String?

      def initialize(@action : String?)
        msg = "Cannot #{action}: not on a branch (detached HEAD)".gsub("Cannot : ", "Not on a branch (detached HEAD)")
        super(msg)
      end
    end

    class UncommittedChanges < GitError
      getter action : String?
      getter branch : String?
      getter? force_hint : Bool
      getter dirty_files : Array(String)

      def initialize(@action : String?, @branch : String?, @force_hint : Bool, @dirty_files : Array(String))
        msg = if @action && @branch
                "Cannot #{@action}: #{@branch} has uncommitted changes"
              elsif @action
                "Cannot #{@action}: working tree has uncommitted changes"
              elsif @branch
                "#{@branch} has uncommitted changes"
              else
                "Working tree has uncommitted changes"
              end
        super(msg)
      end
    end

    class BranchAlreadyExists < GitError
      getter branch : String

      def initialize(@branch : String)
        super("Branch #{branch} already exists")
      end
    end

    class BranchNotFound < GitError
      getter branch : String
      getter? show_create_hint : Bool
      getter last_fetch_ago : String?
      getter pr_mr_platform : RefType?

      def initialize(@branch : String, @show_create_hint : Bool, @last_fetch_ago : String?, @pr_mr_platform : RefType?)
        super("Branch #{branch} does not exist")
      end
    end

    class ReferenceNotFound < GitError
      getter reference : String

      def initialize(@reference : String)
        super("Reference #{reference} not found")
      end
    end

    class StaleDefaultBranch < GitError
      getter branch : String

      def initialize(@branch : String)
        super("Default branch #{branch} no longer exists locally")
      end
    end

    class NotInWorktree < GitError
      getter action : String?

      def initialize(@action : String?)
        if a = action
          super("Cannot #{a}: not in a worktree")
        else
          super("Not in a worktree")
        end
      end
    end

    class WorktreeMissing < GitError
      getter branch : String

      def initialize(@branch : String)
        super("Worktree for #{branch} not found")
      end
    end

    class RemoteOnlyBranch < GitError
      getter branch : String
      getter remote : String

      def initialize(@branch : String, @remote : String)
        super("Branch #{branch} only exists on remote #{remote}")
      end
    end

    class WorktreePathOccupied < GitError
      getter branch : String
      getter path : String
      getter occupant : String?

      def initialize(@branch : String, @path : String, @occupant : String?)
        super("Path for #{branch} is occupied")
      end
    end

    class WorktreePathExists < GitError
      getter branch : String
      getter path : String
      getter? create : Bool

      def initialize(@branch : String, @path : String, @create : Bool)
        super("Path for #{branch} already exists")
      end
    end

    class WorktreeCreationFailed < GitError
      getter branch : String
      getter base_branch : String?
      getter error : String

      def initialize(@branch : String, @base_branch : String?, @error : String)
        super("Failed to create worktree for #{branch}")
      end
    end

    class WorktreeRemovalFailed < GitError
      getter branch : String
      getter path : String
      getter error : String
      getter remaining_entries : Array(String)?

      def initialize(@branch : String, @path : String, @error : String, @remaining_entries : Array(String)?)
        super("Failed to remove worktree for #{branch}")
      end
    end

    class CannotRemoveMainWorktree < GitError
      def initialize
        super("Cannot remove the main worktree")
      end
    end

    class CannotRemoveDefaultBranch < GitError
      getter branch : String

      def initialize(@branch : String)
        super("Cannot remove the default branch #{branch}")
      end
    end

    class WorktreeLocked < GitError
      getter branch : String
      getter path : String
      getter reason : String?

      def initialize(@branch : String, @path : String, @reason : String?)
        super("Worktree for #{branch} is locked")
      end
    end

    class ConflictingChanges < GitError
      getter target_branch : String
      getter files : Array(String)
      getter worktree_path : String

      def initialize(@target_branch : String, @files : Array(String), @worktree_path : String)
        super("Conflicting changes with #{target_branch}")
      end
    end

    class NotFastForward < GitError
      getter target_branch : String
      getter commits_formatted : String
      getter? in_merge_context : Bool

      def initialize(@target_branch : String, @commits_formatted : String, @in_merge_context : Bool)
        super("Not fast-forward to #{target_branch}")
      end
    end

    class RebaseConflict < GitError
      getter target_branch : String
      getter git_output : String

      def initialize(@target_branch : String, @git_output : String)
        super("Rebase conflict with #{target_branch}")
      end
    end

    class NotRebased < GitError
      getter target_branch : String

      def initialize(@target_branch : String)
        super("Not rebased onto #{target_branch}")
      end
    end

    class PushFailed < GitError
      getter target_branch : String
      getter error : String

      def initialize(@target_branch : String, @error : String)
        super("Push to #{target_branch} failed")
      end
    end

    class NotInteractive < GitError
      def initialize
        super("Interactive operation not available")
      end
    end

    class HookCommandNotFound < GitError
      getter name : String
      getter available : Array(String)

      def initialize(@name : String, @available : Array(String))
        super("Hook command #{name} not found")
      end
    end

    class ParseError < GitError
      getter parse_message : String

      def initialize(@parse_message : String)
        super(@parse_message)
      end
    end

    class WorktreeIncludeParseError < GitError
      getter error : String

      def initialize(@error : String)
        super("Worktree include parse error: #{error}")
      end
    end

    class LlmCommandFailed < GitError
      getter command : String
      getter error : String

      def initialize(@command : String, @error : String)
        super("LLM command #{command} failed")
      end
    end

    class ProjectConfigNotFound < GitError
      getter config_path : String

      def initialize(@config_path : String)
        super("Project config not found: #{config_path}")
      end
    end

    class WorktreeNotFound < GitError
      getter branch : String

      def initialize(@branch : String)
        super("Worktree for #{branch} not found")
      end
    end

    class RefCreateConflict < GitError
      getter ref_type : RefType
      getter number : UInt32
      getter branch : String

      def initialize(@ref_type : RefType, @number : UInt32, @branch : String)
        super("Ref create conflict: #{ref_type.name} #{ref_type.symbol}#{number}")
      end
    end

    class RefBaseConflict < GitError
      getter ref_type : RefType
      getter number : UInt32

      def initialize(@ref_type : RefType, @number : UInt32)
        super("Ref base conflict: #{ref_type.name} #{ref_type.symbol}#{number}")
      end
    end

    class BranchTracksDifferentRef < GitError
      getter branch : String
      getter ref_type : RefType
      getter number : UInt32

      def initialize(@branch : String, @ref_type : RefType, @number : UInt32)
        super("Branch #{branch} tracks different #{ref_type.name} #{ref_type.symbol}#{number}")
      end
    end

    class NoRemoteForRepo < GitError
      getter owner : String
      getter repo : String
      getter suggested_url : String

      def initialize(@owner : String, @repo : String, @suggested_url : String)
        super("No remote for #{owner}/#{repo}")
      end
    end

    class CliApiError < GitError
      getter ref_type : RefType
      getter cli_message : String
      getter stderr : String

      def initialize(@ref_type : RefType, @cli_message : String, @stderr : String)
        super("#{ref_type.name} API error: #{cli_message}")
      end
    end

    class OtherError < GitError
      getter error_message : String

      def initialize(@error_message : String)
        super(@error_message)
      end
    end

    # Semantic errors with exit codes for loop abortion.
    #
    # Port of `WorktrunkError` (error.rs).
    abstract class WorktrunkError < Exception
      abstract def exit_code : Int32
    end

    class AlreadyDisplayed < WorktrunkError
      getter exit_code : Int32

      def initialize(@exit_code : Int32)
        super("Error (exit #{@exit_code})")
      end
    end

    class ChildProcessExited < WorktrunkError
      getter exit_code : Int32
      getter program : String
      getter signal : Int32?

      def initialize(@program : String, @exit_code : Int32, @signal : Int32?)
        if sig = @signal
          super("#{@program} exited (signal #{sig}, exit #{@exit_code})")
        else
          super("#{@program} exited (exit #{@exit_code})")
        end
      end
    end
  end
end
