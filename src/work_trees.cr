# WorkTrees — Crystal port of Worktrunk (https://github.com/max-sixty/worktrunk)
#
# A CLI for Git worktree management, designed for parallel AI agent workflows.

require "./work_trees/template/filters"
require "./work_trees/template/codename"
require "./work_trees/template/context"
require "./work_trees/cmd"

module WorkTrees
  VERSION = "0.1.0"
end
