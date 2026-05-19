# Template variable definitions and context types.
#
# Ported from vendor/worktrunk/src/config/expansion.rs
#
# Template variables available in different hook/alias scopes.
# See upstream `src/config/expansion.rs` lines 37-191 for the full spec.

require "./filters"

module WorkTrees
  module Template
    # Active-context vars: point at the branch the operation acts on.
    ACTIVE_VARS = %w[branch worktree_path worktree_name commit short_commit upstream]

    # Repo/remote-metadata vars: describe the repository.
    REPO_VARS = %w[repo repo_path owner primary_worktree_path default_branch remote remote_url]

    # Exec-context vars always available outside hook infrastructure.
    EXEC_BASE_VARS = %w[cwd]

    # Hook infrastructure vars added by the hook runner itself.
    HOOK_INFRASTRUCTURE_VARS = %w[hook_type hook_name]

    # Alias args key stored as JSON in the context map.
    ALIAS_ARGS_KEY = "args"

    # Deprecated template variable aliases (still valid for backward compatibility).
    DEPRECATED_TEMPLATE_VARS = {
      "main_worktree"      => "repo",
      "repo_root"          => "repo_path",
      "worktree"           => "worktree_path",
      "main_worktree_path" => "primary_worktree_path",
    }

    # The context in which a template will be expanded.
    enum ValidationScope
      # A hook of the given type.
      Hook
      # The `--execute` template for `wt switch --create`.
      SwitchExecute
      # An alias body.
      Alias
    end

    # Hook types, matching the upstream `HookType` enum.
    enum HookType
      PreSwitch
      PostSwitch
      PreStart
      PostStart
      PreCommit
      PostCommit
      PreMerge
      PostMerge
      PreRemove
      PostRemove

      # Returns the operation-context vars for this hook type.
      def extra_vars : Array(String)
        case self
        in .pre_switch?, .post_switch?, .pre_start?, .post_start?
          %w[base base_worktree_path target target_worktree_path pr_number pr_url]
        in .pre_commit?, .post_commit?
          %w[target]
        in .pre_merge?, .post_merge?, .pre_remove?, .post_remove?
          %w[target target_worktree_path]
        end
      end

      # Human-readable name for display.
      def display_name : String
        to_s.underscore.gsub('_', '-')
      end
    end

    # All base vars (active + repo + exec).
    def self.base_vars : Array(String)
      ACTIVE_VARS + REPO_VARS + EXEC_BASE_VARS
    end

    # All template variables available in a given scope.
    def self.vars_available_in(scope : ValidationScope, hook_type : HookType? = nil) : Array(String)
      vars = base_vars
      case scope
      in .hook?
        if ht = hook_type
          vars += HOOK_INFRASTRUCTURE_VARS
          vars += ht.extra_vars
          vars << ALIAS_ARGS_KEY
        end
      in .switch_execute?
        vars += %w[base base_worktree_path]
      in .alias?
        vars << ALIAS_ARGS_KEY
      end
      vars += DEPRECATED_TEMPLATE_VARS.keys
      vars
    end
  end
end
