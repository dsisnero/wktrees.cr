# WorkTrees — Crystal port of Worktrunk (https://github.com/max-sixty/worktrunk)
#
# A CLI for Git worktree management, designed for parallel AI agent workflows.

require "./work_trees/template/filters"
require "./work_trees/template/codename"
require "./work_trees/template/context"
require "./work_trees/template/expansion"
require "./work_trees/cmd"
require "./work_trees/git/error"
require "./work_trees/git/repository"
require "./work_trees/git/worktree_info"
require "./work_trees/git/remove"
require "./work_trees/git/branch_resolver"
require "./work_trees/shell/wrapper"
require "./work_trees/config/config"
require "./work_trees/cli"

module WorkTrees
  VERSION = "0.1.0"
end
