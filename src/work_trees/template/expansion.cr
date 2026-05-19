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
    PLACEHOLDER_RE = /\{\{\s*(\w+)\s*(?:\|\s*(\w+)(?:\(([^)]*)\))?\s*)?\}\}/

    # Expand template placeholders with variable values and optional filters.
    #
    # Supported syntax:
    #   {{ branch }}           — simple variable
    #   {{ branch | sanitize }} — variable with filter
    #   {{ branch | codename(2) }}   — filter with numeric argument
    #
    # Unmatched placeholders are left as-is.
    #
    # ```
    # WorkTrees::Template.expand("~/repo.{{ branch }}", {"branch" => "feature-auth"})
    # # => "~/repo.feature-auth"
    # ```
    def self.expand(template : String, vars : Hash(String, String)) : String
      result = template
      template.scan(PLACEHOLDER_RE).each do |match|
        var = match[1].to_s
        value = vars[var]?
        m2 = match[2]?
        if value && m2
          filter = "#{m2}"
          arg_s = match[3]? ? "#{match[3]}" : nil
          value = apply_filter(value, filter, arg_s)
        end
        replacement = value || match[0]
        result = result.sub(match[0], replacement)
      end
      result
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
end
