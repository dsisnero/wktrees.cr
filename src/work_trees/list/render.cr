# List rendering helpers — Crystal port of worktrunk/src/commands/list/render.rs
#
# Provides compact number formatting, diff display, placeholder symbols,
# and skeleton row rendering for wt list output.

module WorkTrees
  module List
    module Render
      PLACEHOLDER       = "·"
      PLACEHOLDER_BLANK = " "

      # Format a number in compact notation.
      #
      # Under 100: raw number
      # 100-999: raw number (:signs variant) or NC (:arrows variant)
      # 1000-9999: NK (e.g., 2500 → 2K)
      # 10K+: ∞
      def self.compact_number(value : Int32, variant : Symbol = :signs) : String
        return "0" if value == 0

        if value >= 10_000
          "∞"
        elsif value >= 1_000
          "#{value // 1_000}K"
        elsif value >= 100 && variant == :arrows
          "#{value // 100}C"
        else
          value.to_s
        end
      end

      # Format added/deleted counts as styled diff string.
      #
      # Returns empty string when both are zero.
      def self.format_diff(added : Int32, deleted : Int32) : String
        parts = [] of String
        parts << Styling.green("+#{compact_number(added)}") if added > 0
        parts << Styling.red("-#{compact_number(deleted)}") if deleted > 0
        parts.join(" ")
      end

      # Render a skeleton row with placeholder symbols for all columns.
      #
      # Used during progressive rendering before data loads.
      def self.skeleton_row(column_count : Int32) : String
        columns = (1..column_count).map { PLACEHOLDER_BLANK }.join("  ")
        Styling.dim(columns)
      end

      # Render a header line with column names.
      def self.header_line(columns : Array(String)) : String
        columns.map { |col| Styling.bold(col) }.join("  ")
      end
    end
  end
end
