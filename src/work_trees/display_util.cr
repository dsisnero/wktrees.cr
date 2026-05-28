# Display utilities — Crystal port of vendor/worktrunk/src/display.rs
#
# Relative time formatting and visual-width-aware text truncation.

module WorkTrees
  module DisplayUtil
    MINUTE = 60_i64
    HOUR   = MINUTE * 60
    DAY    = HOUR * 24
    WEEK   = DAY * 7
    MONTH  = DAY * 30
    YEAR   = DAY * 365

    UNITS = [
      {YEAR, "y"},
      {MONTH, "mo"},
      {WEEK, "w"},
      {DAY, "d"},
      {HOUR, "h"},
      {MINUTE, "m"},
    ]

    # Format a Unix timestamp as abbreviated relative time.
    def self.format_relative_time_short(timestamp : Int64) : String
      format_relative_time_impl(timestamp, Time.utc.to_unix)
    end

    # Internal: format with explicit `now` timestamp for testing.
    def self.format_relative_time_impl(timestamp : Int64, now : Int64) : String
      seconds_ago = now - timestamp

      return "future" if seconds_ago < 0
      return "now" if seconds_ago < MINUTE

      UNITS.each do |(unit, abbrev)|
        value = seconds_ago // unit
        return "#{value}#{abbrev}" if value > 0
      end

      "now"
    end

    # Truncate text to max_width visual columns, appending "…" when truncated.
    def self.truncate_to_width(text : String, max_width : Int32) : String
      return text if Styling.visual_width(text) <= max_width

      target = max_width - 1 # account for "…"
      target = 0 if target < 0
      width = 0
      last_idx = 0

      text.each_char.with_index do |char, idx|
        char_width = Styling.visual_width(char.to_s)
        break if width + char_width > target
        width += char_width
        last_idx = idx + char.bytesize
      end

      truncated = text[0...last_idx].rstrip
      "#{truncated}…"
    end
  end
end
