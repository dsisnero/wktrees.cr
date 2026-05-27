# Recovery from partial operations — Crystal port of
# worktrunk/src/commands/worktree/finish.rs and resolve.rs
#
# Provides safe worktree removal with backup path generation,
# branch deletion with integration checks, and cleanup result
# tracking for post-merge and post-remove workflows.

require "time"

module WorkTrees
  module Git
    module Recovery
      # Result of a cleanup operation (merge finish, remove).
      struct CleanupResult
        property? worktree_removed : Bool
        property? branch_deleted : Bool
        property cd_path : String?

        def initialize(
          @worktree_removed = false,
          @branch_deleted = false,
          @cd_path : String? = nil,
        )
        end
      end

      # Generate a backup path for a worktree that can't be
      # directly removed (cross-device rename fallback).
      def self.generate_backup_path(original_path : String) : String
        dir = File.dirname(original_path)
        name = File.basename(original_path)
        ts = Time.utc.to_unix
        # Try indexed backup names to avoid collisions
        100.times do |i|
          suffix = i == 0 ? "-#{ts}.trash" : "-#{ts}-#{i}.trash"
          backup = File.join(dir, "#{name}#{suffix}")
          return backup unless File.exists?(backup)
        end
        # Last resort: use unique suffix
        File.join(dir, "#{name}-#{ts}-#{Random.rand(9999)}.trash")
      end

      # Determine the branch deletion result based on integration status.
      #
      # Returns :deleted if the branch was removed, :kept if it was retained,
      # :skipped if no branch was specified.
      def self.safe_delete_result(
        branch : String,
        target : String,
        integrated : Bool,
        force : Bool,
      ) : Symbol
        return :skipped if branch.empty?
        if force || integrated
          :deleted
        else
          :kept
        end
      end

      # Build a cleanup result from the outcome of a remove operation.
      def self.cleanup_result(
        worktree_removed : Bool = false,
        branch_deleted : Bool = false,
        cd_path : String? = nil,
      ) : CleanupResult
        CleanupResult.new(worktree_removed, branch_deleted, cd_path)
      end
    end
  end
end
