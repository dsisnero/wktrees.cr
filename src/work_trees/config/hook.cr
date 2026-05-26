# Hook configuration and execution.
# Ported from vendor/worktrunk/src/commands/hooks.rs

require "toml"
require "../template/expansion"

module WorkTrees
  module Config
    # A single hook command with optional template expansion.
    class HookCommand
      getter name : String
      getter command : String

      def initialize(@name : String, @command : String)
      end

      # Expand template variables in the command.
      def expand(vars : Hash(String, String)) : String
        Template.expand(@command, vars)
      end
    end

    # A group of hooks: either concurrent (named) or sequential (pipeline).
    class HookGroup
      getter kind : Symbol # :concurrent or :sequential
      getter hooks : Array(HookCommand)

      def initialize(@kind : Symbol, @hooks : Array(HookCommand))
      end

      def concurrent? : Bool
        @kind == :concurrent
      end

      def sequential? : Bool
        @kind == :sequential
      end
    end

    # Parse hooks from a TOML string for a given hook section.
    #
    # Two formats supported:
    #   [post-start]              # concurrent named hooks (single table)
    #   server = "npm run dev"
    #   lint = "cargo clippy"
    #
    #   [[post-start]]             # sequential pipeline steps (array of tables)
    #   step1 = "npm install"
    #   [[post-start]]
    #   step2 = "npm run build"
    def self.parse_hooks(toml_str : String, section : String) : Array(HookGroup)
      data = TOML.parse(toml_str)
      section_data = data[section]?
      return [] of HookGroup unless section_data

      raw = section_data.raw

      case raw
      when Hash
        # [section] format: named hooks run concurrently
        cmds = raw.map { |key, value| HookCommand.new(key.to_s, value.raw.to_s) }
        [HookGroup.new(:concurrent, cmds)]
      when Array
        # [[section]] format: pipeline steps run sequentially
        steps = raw.compact_map do |item|
          if item.raw.is_a?(Hash)
            h = item.raw.as(Hash)
            next unless h.size == 1
            key = h.keys.first
            val = h[key].raw.to_s
            HookCommand.new(key.to_s, val)
          end
        end
        # Each step is its own sequential group
        steps.map { |cmd| HookGroup.new(:sequential, [cmd]) }
      else
        [] of HookGroup
      end
    end

    # Whether a hook or alias body came from user config or project config.
    enum HookSource
      User
      Project
    end

    # A parsed name filter, optionally scoped to a specific source.
    #
    # Supports formats:
    # - `"foo"` — matches commands named "foo" from any source
    # - `"user:foo"` — matches only user's command named "foo"
    # - `"project:foo"` — matches only project's command named "foo"
    # - `"user:"` or `"project:"` — matches all commands from that source
    struct ParsedFilter
      getter source : HookSource?
      getter name : String

      def initialize(@source : HookSource?, @name : String)
      end

      def self.parse(filter : String) : ParsedFilter
        if filter.starts_with?("user:")
          new(HookSource::User, filter[5..])
        elsif filter.starts_with?("project:")
          new(HookSource::Project, filter[8..])
        else
          new(nil, filter)
        end
      end

      # Check if this filter matches the given source.
      def matches_source?(source : HookSource) : Bool
        @source.nil? || @source == source
      end
    end
  end
end
