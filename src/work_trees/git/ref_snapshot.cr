# RefSnapshot — Crystal port of worktrunk/src/git/repository/ref_snapshot.rs
#
# An immutable snapshot of repository ref state, captured by running
# `git for-each-ref refs/heads/` and `git for-each-ref refs/remotes/`.
# Provides point-in-time SHA resolution, ahead/behind caching, and
# O(1) local branch lookup.

module WorkTrees
  module Git
    struct RefSnapshot
      # Ref name → commit SHA. Keyed by short and qualified forms.
      private getter commits : Hash(String, String)

      # Local branch entries sorted by committer timestamp descending.
      private getter locals : Array(LocalBranch)

      # Local branch name → index for O(1) lookup.
      private getter locals_by_name : Hash(String, Int32)

      # Remote-tracking branch entries.
      private getter remotes : Array(RemoteBranch)

      # Ahead/behind counts keyed by (base, head) ref names.
      private getter ahead_behind_map : Hash({String, String}, {Int32, Int32})

      def self.build(
        locals : Array(LocalBranch),
        remotes : Array(RemoteBranch),
        ahead_behind : Hash({String, String}, {Int32, Int32}),
      ) : RefSnapshot
        commits = {} of String => String
        locals.each do |b|
          commits[b.name] = b.commit_sha
          commits["refs/heads/#{b.name}"] = b.commit_sha
        end
        remotes.each do |remote|
          commits[remote.short_name] = remote.commit_sha
          commits["refs/remotes/#{remote.short_name}"] = remote.commit_sha
        end
        by_name = {} of String => Int32
        locals.each_with_index { |b, i| by_name[b.name] = i }
        new(commits, locals, by_name, remotes, ahead_behind)
      end

      def initialize(
        @commits,
        @locals,
        @locals_by_name,
        @remotes,
        @ahead_behind_map,
      )
      end

      # Resolve a ref name to its commit SHA at capture time.
      def resolve(name : String) : String?
        @commits[name]?
      end

      # Resolve and error on missing ref.
      def must_resolve(name : String) : String
        @commits[name]
      end

      # Upstream short name for a local branch.
      def upstream_of(branch : String) : String?
        local_branch(branch).try(&.upstream_short)
      end

      # Cached ahead/behind counts for a (base, head) pair.
      def ahead_behind(base : String, head : String) : {Int32, Int32}?
        @ahead_behind_map[{base, head}]?
      end

      # All local branches at capture time.
      def local_branches : Array(LocalBranch)
        @locals
      end

      # O(1) lookup of a local branch by short name.
      def local_branch(name : String) : LocalBranch?
        idx = @locals_by_name[name]?
        idx ? @locals[idx] : nil
      end

      # All remote-tracking branches at capture time.
      def remote_branches : Array(RemoteBranch)
        @remotes
      end
    end
  end
end
