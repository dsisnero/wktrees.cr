#!/usr/bin/env ruby
# Curate port_inventory.tsv — mark ported/skipped items based on Crystal source mapping.
# Usage: ruby scripts/curate_port_inventory.rb plans/inventory/rust_port_inventory.tsv

inventory_path = ARGV[0] || "plans/inventory/rust_port_inventory.tsv"
unless File.exist?(inventory_path)
  warn "Inventory file not found: #{inventory_path}"
  exit 1
end

# Mapping: upstream Rust source prefix → Crystal source reference template
# The template uses {name} for the item name extracted from source_id
PORTED_MODULES = {
  # Cache
  "src/cache.rs"                => "src/work_trees/cache.cr",
  # Cmd / Shell exec
  "src/shell_exec.rs"           => "src/work_trees/cmd.cr",
  # Sync
  "src/sync.rs"                 => "src/work_trees/sync.cr",
  # Config
  "src/config/user/mod.rs"      => "src/work_trees/config/config.cr",
  "src/config/user/path.rs"     => "src/work_trees/config/config.cr",
  "src/config/user/schema.rs"   => "src/work_trees/config/config.cr",
  "src/config/user/sections.rs" => "src/work_trees/config/sections.cr",
  "src/config/user/accessors.rs"=> "src/work_trees/config/config.cr",
  "src/config/user/merge.rs"    => "src/work_trees/config/sections.cr",
  "src/config/user/mutation.rs" => "src/work_trees/config/config.cr",
  "src/config/user/persistence.rs"=> "src/work_trees/config/config.cr",
  "src/config/user/resolved.rs" => "src/work_trees/config/config.cr",
  # Hooks
  "src/config/commands.rs"      => "src/work_trees/config/hook.cr",
  "src/commands/hooks.rs"       => "src/work_trees/config/hook.cr",
  "src/commands/hook_commands.rs"=> "src/work_trees/cli.cr",
  "src/commands/hook_filter.rs" => "src/work_trees/config/hook.cr",
  "src/commands/hook_announcement.rs"=> "src/work_trees/cli.cr",
  # Git errors
  "src/git/error.rs"            => "src/work_trees/git/error.cr",
  # Repository
  "src/git/repository/mod.rs"   => "src/work_trees/git/repository.cr",
  "src/git/repository/working_tree.rs" => "src/work_trees/git/repository.cr",
  "src/git/repository/worktrees.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/branch.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/branches.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/config.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/diff.rs"  => "src/work_trees/git/repository.cr",
  "src/git/repository/ref_snapshot.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/sha_cache.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/remotes.rs"=> "src/work_trees/git/repository.cr",
  "src/git/repository/tests.rs" => "src/work_trees/git/repository.cr",
  # Worktree info
  "src/git/parse.rs"            => "src/work_trees/git/worktree_info.cr",
  # Branch types live alongside worktree info in upstream mod.rs
  "src/git/mod.rs"              => "src/work_trees/git/branches.cr",
  # Remove
  "src/git/remove.rs"           => "src/work_trees/git/remove.cr",
  # Branch resolver
  "src/commands/worktree/resolve.rs"=> "src/work_trees/git/branch_resolver.cr",
  # Integration
  "src/git/repository/integration.rs"=> "src/work_trees/git/integration.cr",
  # Shell wrappers
  "src/shell/mod.rs"            => "src/work_trees/shell/wrapper.cr",
  "src/shell/detection.rs"      => "src/work_trees/shell/wrapper.cr",
  "src/shell/paths.rs"          => "src/work_trees/shell/wrapper.cr",
  "src/shell/utils.rs"          => "src/work_trees/shell/wrapper.cr",
  # List columns
  "src/commands/list/columns.rs"=> "src/work_trees/list/columns.cr",
  # List model
  "src/commands/list/model/state.rs"=> "src/work_trees/list/model.cr",
  "src/commands/list/model/stats.rs"=> "src/work_trees/list/model.cr",
  "src/commands/list/model/status_symbols.rs"=> "src/work_trees/list/model.cr",
  "src/commands/list/model/statusline_segment.rs"=> "src/work_trees/list/model.cr",
  # Template expansion
  "src/config/expansion.rs"     => "src/work_trees/template/expansion.cr",
  # CLI and commands (consolidated)
  "src/cli/mod.rs"              => "src/work_trees/cli.cr",
  "src/main.rs"                 => "src/cli.cr",
  "src/lib.rs"                  => "src/work_trees.cr",
  "src/cli/config.rs"           => "src/work_trees/cli.cr",
  "src/cli/hook.rs"             => "src/work_trees/cli.cr",
  "src/cli/list.rs"             => "src/work_trees/cli.cr",
  "src/cli/step.rs"             => "src/work_trees/cli.cr",
  "src/commands/alias.rs"       => "src/work_trees/cli.cr",
  "src/commands/commit.rs"      => "src/work_trees/cli.cr",
  "src/commands/list/mod.rs"    => "src/work_trees/cli.cr",
  "src/commands/merge.rs"       => "src/work_trees/cli.cr",
  "src/commands/configure_shell.rs"=> "src/work_trees/cli.cr",
  "src/commands/init.rs"        => "src/work_trees/cli.cr",
  "src/commands/eval.rs"        => "src/work_trees/cli.cr",
  "src/commands/for_each.rs"    => "src/work_trees/cli.cr",
  "src/commands/statusline.rs"  => "src/work_trees/cli.cr",
  "src/commands/step/mod.rs"    => "src/work_trees/cli.cr",
  "src/commands/step/commit.rs" => "src/work_trees/cli.cr",
  "src/commands/step/diff.rs"   => "src/work_trees/cli.cr",
  "src/commands/step/squash.rs" => "src/work_trees/cli.cr",
  "src/commands/step/rebase.rs" => "src/work_trees/cli.cr",
  "src/commands/step/prune.rs"  => "src/work_trees/cli.cr",
  "src/commands/step/copy_ignored.rs"=> "src/work_trees/cli.cr",
  "src/commands/step/promote.rs"=> "src/work_trees/cli.cr",
  "src/commands/step/relocate.rs"=> "src/work_trees/cli.cr",
  "src/commands/step/tether.rs" => "src/work_trees/cli.cr",
  "src/commands/process.rs"     => "src/work_trees/cli.cr",
  "src/commands/config/show.rs" => "src/work_trees/cli.cr",
  "src/commands/config/create.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/state.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/alias.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/mod.rs"  => "src/work_trees/cli.cr",
  "src/commands/config/opencode.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/plugins.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/codex.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/hints.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/update.rs"=> "src/work_trees/cli.cr",
  "src/commands/config/approvals.rs"=> "src/work_trees/cli.cr",
  "src/commands/worktree/switch.rs"=> "src/work_trees/cli.cr",
  "src/commands/worktree/types.rs"=> "src/work_trees/cli.cr",
  "src/commands/worktree/finish.rs"=> "src/work_trees/cli.cr",
  "src/commands/worktree/hooks.rs"=> "src/work_trees/cli.cr",
  "src/commands/worktree/push.rs"=> "src/work_trees/cli.cr",
  "src/commands/command_executor.rs"=> "src/work_trees/cli.cr",
  "src/commands/command_approval.rs"=> "src/work_trees/cli.cr",
  "src/commands/context.rs"     => "src/work_trees/cli.cr",
  "src/commands/pipeline_spec.rs"=> "src/work_trees/config/hook.cr",
  "src/commands/project_config.rs"=> "src/work_trees/config/config.cr",
  "src/commands/custom.rs"      => "src/work_trees/cli.cr",
  "src/commands/run_pipeline.rs"=> "src/work_trees/cli.cr",
  "src/commands/template_vars.rs"=> "src/work_trees/template/context.cr",
  "src/commands/relocate.rs"    => "src/work_trees/cli.cr",
  "src/commands/repository_ext.rs"=> "src/work_trees/git/repository.cr",
  "src/commands/list/json_output.rs"=> "src/work_trees/cli.cr",
  "src/completion.rs"           => "src/work_trees/cli.cr",
  # Styling module (newly ported)
  "src/styling/mod.rs"          => "src/work_trees/styling.cr",
  "src/styling/constants.rs"    => "src/work_trees/styling.cr",
  "src/styling/format.rs"       => "src/work_trees/styling.cr",
  "src/styling/highlighting.rs" => "src/work_trees/styling.cr",
  "src/styling/hyperlink.rs"    => "src/work_trees/styling.cr",
  "src/styling/line.rs"         => "src/work_trees/styling.cr",
  "src/styling/suggest.rs"      => "src/work_trees/styling.cr",
  # Git diff (newly ported)
  "src/git/diff.rs"             => "src/work_trees/git/diff.cr",
  # Branch inventory + RefSnapshot + ShaCache (newly ported)
  "src/git/mod.rs"              => "src/work_trees/git/branches.cr",
  "src/git/repository/branches.rs"=> "src/work_trees/git/branches.cr",
  "src/git/repository/ref_snapshot.rs"=> "src/work_trees/git/ref_snapshot.cr",
  "src/git/repository/sha_cache.rs"=> "src/work_trees/git/sha_cache.cr",
  # Recovery (newly ported)
  "src/commands/worktree/finish.rs"=> "src/work_trees/git/recovery.cr",
  "src/git/recover.rs"             => "src/work_trees/git/recovery.cr",
  # List render (newly ported)
  "src/commands/list/render.rs"     => "src/work_trees/list/render.cr",
}

# Files that are intentionally skipped (build artifacts, docs/demos, etc.)
SKIPPED_PREFIXES = %w[
  build.rs
  docs/demos/
  target/
  tests/
]

lines = File.readlines(inventory_path, chomp: true)
header = lines.first
data_lines = lines[1..]

updated = 0
skipped_count = 0

new_lines = data_lines.map do |line|
  next nil if line.strip.empty? || line.start_with?("#")
  cols = line.split("\t", -1)
  source_id = cols[0]
  kind = cols[1]
  status = cols[2]
  crystal_refs = cols[3]
  notes = cols[4] || ""

  # Skip already ported/skipped/diverged items
  next line unless %w[missing -].include?(status) || status.strip.empty?

  # Check for skipped prefixes
  if SKIPPED_PREFIXES.any? { |p| source_id.start_with?(p) }
    cols[2] = "skipped"
    cols[3] = "-"
    cols[4] = notes == "-" || notes.strip.empty? ? "auto-generated" : notes
    skipped_count += 1
    next cols.join("\t")
  end

  # Check for ported modules
  matched = nil
  PORTED_MODULES.each do |prefix, crystal_ref|
    if source_id.start_with?(prefix)
      matched = crystal_ref
      break
    end
  end

  if matched
    cols[2] = "partial"  # Use "partial" since individual items within modules may vary
    cols[3] = matched
    cols[4] = notes == "-" || notes.strip.empty? ? "ported" : notes
    updated += 1
    next cols.join("\t")
  end

  line
end.compact

output = [header] + new_lines
File.write(inventory_path, output.join("\n") + "\n")

puts "Curated #{inventory_path}"
puts "  Marked #{updated} items as partial (have Crystal refs)"
puts "  Marked #{skipped_count} items as skipped (build/docs artifacts)"
puts "  Remaining items are still 'missing' (not yet ported)"
