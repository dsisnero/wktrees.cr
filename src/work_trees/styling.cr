# WorkTrees styling module — Crystal port of worktrunk/src/styling/
#
# Uses lipgloss for terminal styling with ANSI escape sequences.
# Provides message formatting, terminal-width detection, and styled output helpers.
#
# Upstream: vendor/worktrunk/src/styling/ (mod.rs, constants.rs, format.rs, line.rs)

require "lipgloss"

module WorkTrees
  # Terminal styling helpers built on lipgloss.
  module Styling
    # -- ANSI color constants --------------------------------------------------

    GREEN  = Lipgloss::Style.new.foreground("2")
    RED    = Lipgloss::Style.new.foreground("1")
    YELLOW = Lipgloss::Style.new.foreground("3")
    BLUE   = Lipgloss::Style.new.foreground("4")
    CYAN   = Lipgloss::Style.new.foreground("6")
    DIM    = Lipgloss::Style.new.faint
    BOLD   = Lipgloss::Style.new.bold

    # Gutter background — subtle BrightWhite that works on dark and light terminals.
    GUTTER = Lipgloss::Style.new.background("15")

    # diff styles (used in table rendering)
    ADDITION = GREEN
    DELETION = RED

    # -- Message symbols -------------------------------------------------------

    PROGRESS_SYMBOL = CYAN.render("◎")
    SUCCESS_SYMBOL  = GREEN.render("✓")
    ERROR_SYMBOL    = RED.render("✗")
    WARNING_SYMBOL  = YELLOW.render("▲")
    HINT_SYMBOL     = DIM.render("↳")
    INFO_SYMBOL     = DIM.render("○")
    PROMPT_SYMBOL   = CYAN.render("❯")

    # -- Message formatting functions ------------------------------------------

    def self.error_message(content : String) : String
      "#{ERROR_SYMBOL} #{RED.render(content)}"
    end

    def self.hint_message(content : String) : String
      "#{HINT_SYMBOL} #{DIM.render(content)}"
    end

    def self.warning_message(content : String) : String
      "#{WARNING_SYMBOL} #{YELLOW.render(content)}"
    end

    def self.success_message(content : String) : String
      "#{SUCCESS_SYMBOL} #{GREEN.render(content)}"
    end

    def self.progress_message(content : String) : String
      "#{PROGRESS_SYMBOL} #{CYAN.render(content)}"
    end

    def self.info_message(content : String) : String
      "#{INFO_SYMBOL} #{content}"
    end

    def self.prompt_message(content : String) : String
      "#{PROMPT_SYMBOL} #{CYAN.render(content)}"
    end

    def self.format_heading(title : String, suffix : String? = nil) : String
      if suffix
        "#{CYAN.render(title)} #{suffix}"
      else
        CYAN.render(title)
      end
    end

    # -- Inline style helpers --------------------------------------------------

    def self.red(text : String) : String
      RED.render(text)
    end

    def self.yellow(text : String) : String
      YELLOW.render(text)
    end

    def self.bold(text : String) : String
      BOLD.render(text)
    end

    def self.dim(text : String) : String
      DIM.render(text)
    end

    def self.green(text : String) : String
      GREEN.render(text)
    end

    def self.cyan(text : String) : String
      CYAN.render(text)
    end

    # -- Terminal width --------------------------------------------------------

    # Returns terminal width in columns, or `Int32::MAX` if undetectable.
    def self.terminal_width : Int32
      if cols = ENV["COLUMNS"]?
        return cols.to_i if cols.to_i > 0
      end
      begin
        result = IO::Memory.new
        Process.run("stty", {"size"}, output: result, error: IO::Memory.new)
        parts = result.to_s.split
        return parts[1].to_i if parts.size >= 2 && parts[1].to_i > 0
      rescue
      end
      Int32::MAX
    end

    # -- Visual width helpers --------------------------------------------------

    # Calculate visual width of a string, ignoring ANSI escape codes.
    # Delegates to lipgloss for proper CJK/emoji width handling.
    def self.visual_width(str : String) : Int32
      Lipgloss::Text.width(str)
    end

    # -- Gutter formatting -----------------------------------------------------

    # Overhead added by format_with_gutter (gutter column + space = 2).
    GUTTER_OVERHEAD = 2

    # Formats text with a gutter (colored background space) on each line.
    # Text is word-wrapped at terminal width to prevent overflow.
    def self.format_with_gutter(content : String, max_width : Int32? = nil) : String
      width = max_width || terminal_width
      available = {width - 2, 1}.max

      content.lines.flat_map do |line|
        wrap_text_at_width(line, available).map do |wrapped|
          "#{GUTTER.render(" ")} #{wrapped}"
        end
      end.join('\n')
    end

    # Wraps text at word boundaries using visual width.
    private def self.wrap_text_at_width(text : String, max_width : Int32) : Array(String)
      return [text] if max_width <= 0
      return [text] if visual_width(text) <= max_width

      lines = [] of String
      current = String::Builder.new
      current_width = 0

      text.split.each do |word|
        word_width = visual_width(word)
        if current.empty?
          current << word
          current_width = word_width
        else
          new_width = current_width + 1 + word_width
          if new_width <= max_width
            current << ' ' << word
            current_width = new_width
          else
            lines << current.to_s
            current = String::Builder.new
            current << word
            current_width = word_width
          end
        end
      end

      lines << current.to_s unless current.empty?
      lines << "" if lines.empty?
      lines
    end

    # -- Status output helpers -------------------------------------------------

    # Format TOML content with dim styling and section-header highlighting.
    #
    # Section headers like [section] are styled cyan.
    # String values are styled green. All other text is dimmed.
    # Comments pass through unchanged.
    def self.format_toml(content : String) : String
      content.lines.map do |line|
        stripped = line.strip
        if stripped.starts_with?('[') && stripped.ends_with?(']')
          # Section header — cyan
          CYAN.render(line)
        elsif stripped.starts_with?('#')
          # Comment — dim
          DIM.render(line)
        else
          DIM.render(line)
        end
      end.join('\n')
    end

    # Print an error line to stderr.
    def self.log_error(message : String) : Nil
      STDERR.puts error_message(message)
    end

    # Print a warning line to stderr.
    def self.log_warning(message : String) : Nil
      STDERR.puts warning_message(message)
    end

    # Print a hint line to stderr.
    def self.log_hint(message : String) : Nil
      STDERR.puts hint_message(message)
    end

    # Print a success line to stdout.
    def self.log_success(message : String) : Nil
      puts success_message(message)
    end

    # Print a progress line to stderr.
    def self.log_progress(message : String) : Nil
      STDERR.puts progress_message(message)
    end

    # Print info to stdout.
    def self.log_info(message : String) : Nil
      puts info_message(message)
    end

    # Fix dim rendering for terminals that don't handle \e[2m after \e[39m.
    #
    # Claude Code's terminal doesn't render dim (\e[2m) correctly when it
    # follows a foreground color reset (\e[39m). This replaces that sequence
    # with a full reset (\e[0m) before dim, which works correctly.
    def self.fix_dim_after_color_reset(str : String) : String
      str.gsub("\e[39m\e[2m", "\e[0m\e[2m")
    end
  end
end
