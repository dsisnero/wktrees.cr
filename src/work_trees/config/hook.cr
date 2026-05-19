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

    # Parse hooks from a TOML string for a given hook section.
    #
    # Hook sections in TOML:
    #   [pre-switch]
    #   build = "cargo build"
    #   test = "cargo test"
    #
    #   [post-start]
    #   server = "npm run dev"
    def self.parse_hooks(toml_str : String, section : String) : Array(HookCommand)
      data = TOML.parse(toml_str)
      section_data = data[section]?
      return [] of HookCommand unless section_data

      hooks = [] of HookCommand
      raw = section_data.raw

      case raw
      when Hash
        raw.each do |key, value|
          hooks << HookCommand.new(key.to_s, value.raw.to_s)
        end
      end

      hooks
    end
  end
end
