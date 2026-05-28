# Runtime template expansion for user/project config templates.
#
# Ported from vendor/worktrunk/src/config/expansion.rs
#
# Supports {{ var }} and {{ var | filter }} and {{ var | filter(args) }} syntax.
# Filters are the same ones from filters.cr: sanitize, sanitize_db, sanitize_hash,
# hash, hash_port, codename(n), dirname, basename.

require "./filters"
require "./codename"

module WorkTrees
  module Template
    # Regex matches {{ var }} or {{ var | filter }} or {{ var | filter(args) }}
    # Also matches dotted keys like {{ vars.port }}
    PLACEHOLDER_RE = /\{\{\s*([\w.]+)\s*(?:\|\s*(\w+)(?:\(([^)]*)\))?\s*)?\}\}/

    # Expand template placeholders with variable values and optional filters.
    #
    # Supports `{{ vars.key }}` for per-branch state variables stored in git config.
    def self.expand(template : String, vars : Hash(String, String)) : String
      Trace.span("template.expand") do
        do_expand(template, vars)
      end
    end

    private def self.do_expand(template : String, vars : Hash(String, String)) : String
      # Inject per-branch state vars if template references vars.*
      expanded_vars = vars.dup
      if template.includes?("vars.") && expanded_vars["branch"]?
        load_state_vars(expanded_vars["branch"], expanded_vars)
      end

      result = template
      template.scan(PLACEHOLDER_RE).each do |match|
        var = match[1].to_s
        value = expanded_vars[var]?
        if value && (m2 = match[2]?)
          filter = m2.to_s
          arg = match[3]?.try(&.to_s)
          value = apply_filter(value, filter, arg)
        end
        replacement = value || match[0].to_s
        result = result.sub(match[0].to_s, replacement)
      end
      result
    end

    # Load per-branch state variables from git config into the vars hash.
    private def self.load_state_vars(branch : String, vars : Hash(String, String)) : Nil
      result = Cmd.new("git")
        .args(["config", "--local", "--get-regexp", "^worktrees\\.state\\.#{branch}\\.vars\\."])
        .run
      return unless result.success?

      result.stdout.each_line do |line|
        parts = line.split(' ', 2)
        next unless parts.size >= 2
        key = parts[0].split('.').last
        value = parts[1].strip
        vars["vars.#{key}"] = value
      end
    end

    # Apply a named filter to a value.
    private def self.apply_filter(value : String, filter : String, arg : String?) : String
      case filter
      when "sanitize"
        sanitize(value)
      when "sanitize_db"
        sanitize_db(value)
      when "sanitize_hash"
        sanitize_hash(value)
      when "hash"
        short_hash(value)
      when "hash_port"
        hash_port(value).to_s
      when "codename"
        words = arg.try(&.to_i?) || 2
        codename(value, words)
      when "dirname"
        dirname(value)
      when "basename"
        basename(value)
      else
        value
      end
    end
  end

  # Force-String helper for Regex::MatchData captures.
  private def self.str(value) : String
    value.to_s
  end
end
