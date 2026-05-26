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

      # Results of scanning content for deprecations.
      struct Deprecations
        property deprecated_sections : Array(String)
        property replaced_vars : Array({String, String})
        property? legacy_approved_commands : Bool

        def initialize(
          @deprecated_sections = [] of String,
          @replaced_vars = [] of {String, String},
          @legacy_approved_commands = false,
        )
        end

        def has_any? : Bool
          !@deprecated_sections.empty? || !@replaced_vars.empty? || @legacy_approved_commands
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

        deps
      end
    end
  end
end
