# TemplateVars builder — Crystal port of worktrunk/src/commands/template_vars.rs
#
# Canonical assembly of hook template variables. Replaces ad-hoc
# Hash(String, String) reconstructions across hook call sites.
# Owns its strings and emits variable pairs with proper naming.

module WorkTrees
  class TemplateVars
    @base : String?
    @base_worktree_path : String?
    @target : String?
    @target_worktree_path : String?
    @active_worktree_path : String?
    @active_worktree_name : String?
    @active_commit : String?
    @active_short_commit : String?
    @pr_number : String?
    @pr_url : String?

    def initialize
      @base = nil
      @base_worktree_path = nil
      @target = nil
      @target_worktree_path = nil
      @active_worktree_path = nil
      @active_worktree_name = nil
      @active_commit = nil
      @active_short_commit = nil
      @pr_number = nil
      @pr_url = nil
    end

    # -- Setters (fluent API) ------------------------------------------------

    # Set base branch (source) and its worktree path.
    def with_base(branch : String, worktree_path : String) : self
      @base = branch
      @base_worktree_path = worktree_path
      self
    end

    # Set base from strings that may be nil (skipped when nil).
    def with_base_strs(branch : String?, worktree_path : String?) : self
      @base = branch if branch
      @base_worktree_path = worktree_path if worktree_path
      self
    end

    # Set target branch (destination).
    def with_target(branch : String) : self
      @target = branch
      self
    end

    # Set target worktree path.
    def with_target_worktree_path(path : String) : self
      @target_worktree_path = path
      self
    end

    # Override active worktree identity (path, name, deprecated alias).
    def with_active_worktree(path : String) : self
      @active_worktree_path = path
      name = File.basename(path)
      # Root path ("/") returns "/" — treat as "unknown" (vendor behavior)
      @active_worktree_name = (name == "/" || name.empty?) ? "unknown" : name
      self
    end

    # Override commit SHA and abbreviated form.
    def with_active_commit(commit : String, short_commit : String) : self
      @active_commit = commit
      @active_short_commit = short_commit
      self
    end

    # Set PR/MR number and URL.
    def with_pr(number : UInt32?, url : String?) : self
      @pr_number = number.try(&.to_s)
      @pr_url = url
      self
    end

    # -- Materialization -----------------------------------------------------

    # Emit (name, value) pairs. Includes deprecated `worktree` alias
    # for `worktree_path` once, here.
    def as_extra_vars : Array({String, String})
      out = [] of {String, String}
      if v = @base
        out << {"base", v}
      end
      if v = @base_worktree_path
        out << {"base_worktree_path", v}
      end
      if v = @target
        out << {"target", v}
      end
      if v = @target_worktree_path
        out << {"target_worktree_path", v}
      end
      if v = @active_worktree_path
        out << {"worktree_path", v}
        out << {"worktree", v} # deprecated alias
      end
      if v = @active_worktree_name
        out << {"worktree_name", v}
      end
      if v = @active_commit
        out << {"commit", v}
      end
      if v = @active_short_commit
        out << {"short_commit", v}
      end
      if v = @pr_number
        out << {"pr_number", v}
      end
      if v = @pr_url
        out << {"pr_url", v}
      end
      out
    end
  end
end
