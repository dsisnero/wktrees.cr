# Always-on command logging — Crystal port of vendor/worktrunk/src/command_log.rs
#
# Logs hook execution and LLM commands to .git/wt/logs/commands.jsonl
# as JSONL. Provides audit trail without requiring -vv.
#
# Growth control: rotates at 1MB, keeping old file as commands.jsonl.old.

require "json"
require "time"

module WorkTrees
  module CommandLog
    MAX_LOG_SIZE   = 1_048_576 # 1MB
    MAX_CMD_LENGTH =      2000

    @@log_path : String?
    @@wt_command : String?
    @@file : File?

    # Initialize the command log for a repository.
    # Called once at startup.
    def self.init(log_dir : String, wt_command : String) : Nil
      @@log_path = File.join(log_dir, "commands.jsonl")
      @@wt_command = wt_command
      @@file = nil
    end

    # Log an external command execution.
    #
    # label: what triggered this command (e.g. "pre-merge user:lint")
    # exit_code: nil for background commands
    # duration_ms: nil for background commands
    def self.log_command(
      label : String,
      command : String,
      exit_code : Int32? = nil,
      duration_ms : Int64? = nil,
    ) : Nil
      path = @@log_path
      return unless path

      rotate_if_needed(path)
      ensure_file_open(path)

      cmd_display = truncate_cmd(command)
      ts = Time.utc.to_rfc3339(fraction_digits: 0)
      wt = @@wt_command || "wt"

      entry = {
        "ts"     => ts,
        "wt"     => wt,
        "label"  => label,
        "cmd"    => cmd_display,
        "exit"   => exit_code,
        "dur_ms" => duration_ms,
      }.to_json

      f = @@file
      return unless f
      f.puts entry
      f.flush
    rescue
      # Silently degrade — logging is best-effort
    end

    # Truncate a command string to MAX_CMD_LENGTH characters,
    # appending "…" if truncated.
    def self.truncate_cmd(command : String) : String
      return command if command.size <= MAX_CMD_LENGTH
      # Truncate at character boundary for multibyte safety
      chars = command.chars
      if chars.size > MAX_CMD_LENGTH
        chars.first(MAX_CMD_LENGTH).join + "…"
      else
        command
      end
    end

    # -- Private helpers -------------------------------------------------------

    private def self.rotate_if_needed(path : String) : Nil
      return unless File.exists?(path)
      if File.size(path) > MAX_LOG_SIZE
        old_path = path.gsub(/(\.jsonl)$/, ".jsonl.old")
        begin
          File.rename(path, old_path)
        rescue
          File.delete(path) rescue nil
        end
        @@file = nil # Force re-open
      end
    end

    private def self.ensure_file_open(path : String) : Nil
      return if @@file
      dir = File.dirname(path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)
      @@file = File.open(path, mode: "a")
    rescue
      nil
    end
  end
end
