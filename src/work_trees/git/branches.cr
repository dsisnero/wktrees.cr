# Branch inventory — Crystal port of worktrunk/src/git/mod.rs (branch types) and
# src/git/repository/branches.rs (branch scanning).
#
# Provides LocalBranch, RemoteBranch, and parsing of `git for-each-ref` output.
# Used by RefSnapshot to capture an immutable view of repository ref state.

module WorkTrees
  module Git
    # A single local branch entry from the branch inventory.
    struct LocalBranch
      getter name : String
      getter commit_sha : String
      getter committer_ts : Int64
      getter upstream_short : String?

      def initialize(@name, @commit_sha, @committer_ts, @upstream_short)
      end
    end

    # A single remote-tracking branch entry from the branch inventory.
    struct RemoteBranch
      getter short_name : String
      getter commit_sha : String
      getter committer_ts : Int64
      getter remote_name : String
      getter local_name : String

      def initialize(@short_name, @commit_sha, @committer_ts, @remote_name, @local_name)
      end
    end

    module Branches
      FIELD_SEP = '\0'

      LOCAL_BRANCH_FORMAT = "--format=%(refname:lstrip=2)%00%(objectname)%00%(committerdate:unix)%00%(upstream:short)%00%(upstream:track)"

      REMOTE_BRANCH_FORMAT = "--format=%(refname:lstrip=2)%00%(objectname)%00%(committerdate:unix)"

      # Parse one record from the local-branch scan.
      def self.parse_local_branch_line(line : String) : LocalBranch?
        parts = line.split(FIELD_SEP)
        name = parts[0]?
        commit_sha = parts[1]?
        ts_str = parts[2]?
        upstream_short_raw = parts[3]?
        upstream_track = parts[4]?
        return nil unless name && commit_sha && ts_str && upstream_short_raw && upstream_track

        committer_ts = ts_str.to_i64?
        return nil unless committer_ts

        upstream_short = if upstream_short_raw.empty? || upstream_track == "[gone]"
                           nil
                         else
                           upstream_short_raw
                         end

        LocalBranch.new(name, commit_sha, committer_ts, upstream_short)
      end

      # Parse one record from the remote-branch scan.
      def self.parse_remote_branch_line(line : String) : RemoteBranch?
        parts = line.split(FIELD_SEP)
        short_name = parts[0]?
        commit_sha = parts[1]?
        ts_str = parts[2]?
        return nil unless short_name && commit_sha && ts_str

        committer_ts = ts_str.to_i64?
        return nil unless committer_ts

        slash_pos = short_name.index('/')
        return nil unless slash_pos

        remote_name = short_name[0...slash_pos]
        local_name = short_name[(slash_pos + 1)..]
        return nil if local_name == "HEAD"

        RemoteBranch.new(short_name, commit_sha, committer_ts, remote_name, local_name)
      end

      # Local-branch inventory with O(1) single-branch lookup.
      class LocalBranchInventory
        getter entries : Array(LocalBranch)

        private getter by_name : Hash(String, Int32)

        def initialize(@entries)
          @by_name = {} of String => Int32
          @entries.each_with_index do |b, i|
            @by_name[b.name] = i
          end
        end

        def get(name : String) : LocalBranch?
          idx = @by_name[name]?
          idx ? @entries[idx] : nil
        end
      end
    end
  end
end
