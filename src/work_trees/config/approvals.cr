# Config approvals — Crystal port of vendor/worktrunk/src/config/approvals.rs
#
# Manages per-project approved commands stored in `approvals.toml`
# (sibling of `config.toml`). Falls back to legacy `[[approved-commands]]`
# format in config.toml when approvals.toml doesn't exist.
#
# File format (approvals.toml):
# ```toml
# [projects."github.com/user/repo"]
# approved-commands = ["npm install", "npm test"]
# ```

require "toml"
require "json"

module WorkTrees
  module Config
    class Approvals
      private getter projects : Hash(String, Array(String))

      def initialize(@projects = {} of String => Array(String))
      end

      # -- Queries ------------------------------------------------------------

      # Check if a command is approved for the given project.
      def command_approved?(project : String, command : String) : Bool
        cmds = @projects[project]?
        return false unless cmds
        cmds.includes?(command)
      end

      # Return approved commands for a project (empty if none).
      def project_commands(project : String) : Array(String)
        @projects[project]? || [] of String
      end

      # All project IDs with at least one approved command.
      def project_ids : Array(String)
        @projects.keys.reject { |id| @projects[id].empty? }
      end

      # -- Mutations ----------------------------------------------------------

      # Approve a single command for a project.
      def approve_command(project : String, command : String) : Nil
        @projects[project] ||= [] of String
        cmds = @projects[project]
        cmds << command unless cmds.includes?(command)
      end

      # Approve multiple commands for a project.
      def approve_commands(project : String, commands : Array(String)) : Nil
        commands.each { |cmd| approve_command(project, cmd) }
      end

      # Remove all approvals for a project.
      def revoke_project(project : String) : Nil
        @projects.delete(project)
      end

      # Clear all approvals.
      def clear_all : Nil
        @projects.clear
      end

      # -- Serialization ------------------------------------------------------

      # Serialize to approvals.toml format.
      def to_toml : String
        return "" if @projects.empty?
        String.build do |io|
          io << "[projects]\n"
          @projects.each do |project_id, commands|
            next if commands.empty?
            io << "[projects.\"#{project_id}\"]\n"
            io << "approved-commands = [\n"
            commands.each do |cmd|
              escaped = cmd.gsub("\\", "\\\\").gsub("\"", "\\\"")
              io << "  \"#{escaped}\",\n"
            end
            io << "]\n"
          end
        end
      end

      # Deserialize from approvals.toml format.
      def self.from_toml(content : String) : Approvals
        approvals = new
        begin
          data = TOML.parse(content)
          if projects_table = data["projects"]?.try(&.raw)
            if projects_table.is_a?(Hash)
              projects_table.each do |project_id, project_data|
                if project_data.raw.is_a?(Hash)
                  if cmds = project_data.raw.as(Hash)["approved-commands"]?
                    raw_cmds = cmds.raw
                    if raw_cmds.is_a?(Array)
                      commands = raw_cmds.map(&.to_s)
                      approvals.approve_commands(project_id.to_s, commands)
                    end
                  end
                end
              end
            end
          end
        rescue TOML::ParseException
          # Return empty approvals on parse failure
        end
        approvals
      end

      # Deserialize from legacy config.toml `[[approved-commands]]` format.
      def self.from_config_toml(content : String) : Approvals
        approvals = new
        begin
          data = TOML.parse(content)
          entries = data["approved-commands"]?.try(&.raw)
          if entries.is_a?(Array)
            entries.each do |entry|
              if entry.raw.is_a?(Hash)
                h = entry.raw.as(Hash)
                project = h["project"]?.try(&.raw.to_s)
                command = h["command"]?.try(&.raw.to_s)
                if project && command && !project.empty? && !command.empty?
                  approvals.approve_command(project, command)
                end
              end
            end
          end
        rescue TOML::ParseException
          # Return empty approvals on parse failure
        end
        approvals
      end

      # -- Persistence --------------------------------------------------------

      # Path to approvals.toml (sibling of config.toml).
      def self.approvals_path : String
        if path = ENV["WORKTRUNK_APPROVALS_PATH"]?
          return path
        end
        config_path = Config.default_config_path
        dir = File.dirname(config_path)
        File.join(dir, "approvals.toml")
      end

      # Load approvals from disk with fallback to legacy config.toml.
      def self.load : Approvals
        path = approvals_path

        # 1. Try approvals.toml
        if File.exists?(path)
          return from_toml(File.read(path))
        end

        # 2. Fallback to config.toml legacy format
        config_path = Config.default_config_path
        if File.exists?(config_path)
          content = File.read(config_path)
          return from_config_toml(content)
        end

        # 3. Empty
        new
      end

      # Save approvals to disk.
      def save(path : String? = nil) : Nil
        save_path = if p = path
                      p
                    else
                      Approvals.approvals_path
                    end
        toml = to_toml
        dir = File.dirname(save_path)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)
        File.write(save_path, toml)
      end

      # Save atomically: write to temp file, then rename.
      #
      # Prevents readers from seeing a partially-written file.
      def save_atomic(path : String? = nil) : Nil
        save_path = if p = path
                      p
                    else
                      Approvals.approvals_path
                    end
        toml_str = to_toml
        dir = File.dirname(save_path)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)
        tmp = "#{save_path}.tmp"
        begin
          File.write(tmp, toml_str)
          File.rename(tmp, save_path)
        rescue File::Error
          File.write(save_path, toml_str)
        end
      end

      # Approve multiple commands and save atomically in one step.
      def approve_and_save(project : String, commands : Array(String), path : String? = nil) : Nil
        approve_commands(project, commands)
        save_atomic(path)
      end

      # Iterate over all projects and their approved commands.
      def each_project(&)
        @projects.each do |project_id, cmds|
          next if cmds.empty?
          yield project_id, cmds
        end
      end
    end
  end
end
