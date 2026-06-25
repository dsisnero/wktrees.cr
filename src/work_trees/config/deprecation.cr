# Config deprecation detection and migration — Crystal port of
# vendor/worktrunk/src/config/deprecation.rs
#
# Scans config content for deprecated patterns:
# - Deprecated template variables (repo_root → repo_path, etc.)
# - Deprecated config sections ([commit-generation] → [commit.generation])
# - Deprecated [ci] section → [forge]
# - Legacy [[approved-commands]] format
#
# Detection is in-memory only. Migration writes happen via `wt config update`.

require "toml"

module WorkTrees
  module Config
    module Deprecation
      # Mapping from deprecated variable name to its replacement.
      DEPRECATED_VARS = [
        {"repo_root", "repo_path"},
        {"worktree", "worktree_path"},
        {"main_worktree", "repo"},
        {"main_worktree_path", "primary_worktree_path"},
      ]

      # Metadata for a deprecated top-level section key.
      DEPRECATED_SECTION_KEYS = [
        {
          key:               "commit-generation",
          canonical_top_key: "commit",
          canonical_display: "[commit.generation]",
        },
        {
          key:               "select",
          canonical_top_key: "switch",
          canonical_display: "[switch.picker]",
        },
        {
          key:               "ci",
          canonical_top_key: "forge",
          canonical_display: "[forge]",
        },
      ]

      # Error message emitted when a config contains the removed `post-create`
      # hook key. Mirrors vendor/worktrunk/src/config/deprecation.rs
      # (POST_CREATE_REMOVED_MSG).
      POST_CREATE_REMOVED_MSG = "`post-create` hook was renamed to `pre-start` in v0.32.0 and the silent rewrite has been removed. Rename `post-create` to `pre-start` in your config."

      # Labeled message for a removed `post-create` key, e.g.
      # "User config: `post-create` hook was renamed ...". The label is
      # "User config" or "Project config", matching upstream's
      # check_and_migrate error/`config show` rendering.
      def self.post_create_message(label : String) : String
        "#{label}: #{POST_CREATE_REMOVED_MSG}"
      end

      # Results of scanning content for deprecations.
      struct Deprecations
        property deprecated_sections : Array(String)
        property replaced_vars : Array({String, String})
        property? legacy_approved_commands : Bool
        # Has `[post-create]` (renamed to `[pre-start]`) without a sibling `pre-start`.
        property? post_create : Bool

        def initialize(
          @deprecated_sections = [] of String,
          @replaced_vars = [] of {String, String},
          @legacy_approved_commands = false,
          @post_create = false,
        )
        end

        def has_any? : Bool
          !@deprecated_sections.empty? || !@replaced_vars.empty? ||
            @legacy_approved_commands || @post_create
        end
      end

      # Normalize a template string by replacing deprecated variables with their canonical names.
      def self.normalize_template_vars(template : String) : String
        result = template
        DEPRECATED_VARS.each do |(old_name, new_name)|
          result = result.gsub(/\b#{Regex.escape(old_name)}\b/, new_name)
        end
        result
      end

      # Scan content for deprecated patterns. Returns a Deprecations summary.
      def self.detect_deprecations(content : String) : Deprecations
        deps = Deprecations.new

        # Check for deprecated template variables
        DEPRECATED_VARS.each do |(old_name, new_name)|
          if content.includes?("{{ #{old_name} }}") || content.includes?("{{#{old_name}}}") || content.includes?("{{ #{old_name}|")
            deps.replaced_vars << {old_name, new_name}
          end
        end

        # Check for deprecated section keys
        DEPRECATED_SECTION_KEYS.each do |section|
          key = section[:key]
          # Check if the deprecated section key appears as a TOML header
          if content.includes?("[#{key}]")
            deps.deprecated_sections << key
          end
        end

        # Check for legacy [[approved-commands]] format
        if content.includes?("[[approved-commands]]")
          deps.legacy_approved_commands = true
        end

        # Check for removed `post-create` hook key
        deps.post_create = find_post_create_deprecation(content)

        deps
      end

      # Detect a removed `post-create` hook key that needs renaming to `pre-start`.
      #
      # Mirrors vendor/worktrunk/src/config/deprecation.rs `find_post_create_from_doc`:
      # flagged when `pre-start` is absent and a non-empty `post-create` is present,
      # either at the top level (project config / flattened user config) or inside any
      # `[projects."id"]` table (user config per-project overrides). An empty
      # `[post-create]` table is a no-op and is not flagged.
      def self.find_post_create_deprecation(content : String) : Bool
        data = begin
          TOML.parse(content)
        rescue TOML::ParseException
          return false
        end

        # Top-level (project config, or flattened user config)
        if data["pre-start"]?.nil? && non_empty_item?(data["post-create"]?.try(&.raw))
          return true
        end

        # Per-project overrides (user config): hooks flattened into [projects."id"]
        projects = data["projects"]?.try(&.raw)
        if projects.is_a?(Hash)
          projects.each_value do |project_value|
            inner = project_value.raw
            next unless inner.is_a?(Hash)
            next if inner.has_key?("pre-start")
            return true if non_empty_item?(inner["post-create"]?.try(&.raw))
          end
        end

        false
      end

      # Whether a parsed TOML value counts as a non-empty hook entry.
      # Tables/inline-tables must have entries; strings and other scalars are
      # always "non-empty"; absence (nil) is empty.
      private def self.non_empty_item?(value) : Bool
        case value
        when Nil
          false
        when Hash
          !value.empty?
        else
          true
        end
      end

      # Apply structural TOML migrations to config content.
      #
      # Handles deprecated section renames and boolean inversions:
      # - [commit-generation] → [commit.generation]
      # - [ci] → [forge]
      # - [select] → [switch.picker]
      # - merge.no-ff → merge.ff (inverted)
      #
      # Returns the migrated content. If no migrations apply, returns
      # a copy of the original unchanged.
      def self.migrate_content(content : String) : String
        result = content

        # Rename deprecated sections (multiline: ^ matches line start)
        result = result.gsub(/^\[commit-generation\]/m, "[commit.generation]")
        result = result.gsub(/^\[ci\]/m, "[forge]")
        result = result.gsub(/^\[select\]/m, "[switch.picker]")

        # Invert no-ff → ff (boolean inversion)
        # Only applies inside [merge] sections
        in_merge = false
        lines = result.lines.map do |line|
          stripped = line.strip
          if stripped == "[merge]"
            in_merge = true
          elsif stripped.starts_with?('[') && stripped.ends_with?(']')
            in_merge = false
          end
          if in_merge && stripped.starts_with?("no-ff")
            indent = line[/^(\s*)/, 1]
            if stripped.includes?("true")
              "#{indent}ff = false"
            elsif stripped.includes?("false")
              "#{indent}ff = true"
            else
              line
            end
          else
            line
          end
        end
        result = lines.join('\n')

        result
      end

      # Result of check_and_migrate: detection info plus migrated content.
      struct CheckAndMigrateResult
        getter deprecations : Deprecations
        getter migrated_content : String
        getter original_content : String

        @has_deprecations : Bool

        def initialize(
          @has_deprecations,
          @deprecations,
          @migrated_content,
          @original_content,
        )
        end

        def has_deprecations? : Bool
          @has_deprecations
        end
      end

      # Combined detection + structural migration for a config file.
      #
      # Performs the full check-and-migrate workflow:
      # 1. Detect deprecated patterns
      # 2. Apply structural TOML migrations
      # 3. Return result with deprecation info and migrated content
      def self.check_and_migrate(content : String, user_config : Bool) : CheckAndMigrateResult
        deps = detect_deprecations(content)
        migrated = if deps.has_any?
                     compute_migrated_content(content)
                   else
                     content
                   end
        CheckAndMigrateResult.new(deps.has_any?, deps, migrated, content)
      end

      # Apply full structural and template-var migration.
      #
      # Combines migrate_content (section renames, boolean inversions)
      # with normalize_template_vars (deprecated template variable replacement).
      def self.compute_migrated_content(content : String) : String
        migrated = migrate_content(content)
        normalize_template_vars(migrated)
      end
    end
  end
end
