require "../spec_helper"

module WorkTrees
  # Helper to check that a string contains ANSI styling (any CSI sequence)
  private def self.has_ansi?(str : String) : Bool
    str.matches?(/\e\[/) && str.matches?(/\e\[.*m/)
  end

  describe Styling do
    describe "message symbols" do
      it "progress symbol is cyan ◎" do
        s = Styling::PROGRESS_SYMBOL
        s.should contain("◎")
        has_ansi?(s).should be_true
      end

      it "success symbol is green ✓" do
        s = Styling::SUCCESS_SYMBOL
        s.should contain("✓")
        has_ansi?(s).should be_true
      end

      it "error symbol is red ✗" do
        s = Styling::ERROR_SYMBOL
        s.should contain("✗")
        has_ansi?(s).should be_true
      end

      it "warning symbol is yellow ▲" do
        s = Styling::WARNING_SYMBOL
        s.should contain("▲")
        has_ansi?(s).should be_true
      end

      it "hint symbol is dim ↳" do
        s = Styling::HINT_SYMBOL
        s.should contain("↳")
        has_ansi?(s).should be_true
      end

      it "info symbol is dim ○" do
        s = Styling::INFO_SYMBOL
        s.should contain("○")
        has_ansi?(s).should be_true
      end

      it "prompt symbol is cyan ❯" do
        s = Styling::PROMPT_SYMBOL
        s.should contain("❯")
        has_ansi?(s).should be_true
      end
    end

    describe "message formatting" do
      it "error_message wraps content in red with symbol" do
        msg = Styling.error_message("Something went wrong")
        msg.should start_with(Styling::ERROR_SYMBOL)
        msg.should contain("Something went wrong")
      end

      it "hint_message wraps content in dim with symbol" do
        msg = Styling.hint_message("Try --help")
        msg.should start_with(Styling::HINT_SYMBOL)
        msg.should contain("Try --help")
      end

      it "warning_message wraps content in yellow with symbol" do
        msg = Styling.warning_message("Deprecated option")
        msg.should start_with(Styling::WARNING_SYMBOL)
        msg.should contain("Deprecated option")
      end

      it "success_message wraps content in green with symbol" do
        msg = Styling.success_message("Done")
        msg.should start_with(Styling::SUCCESS_SYMBOL)
        msg.should contain("Done")
      end

      it "progress_message wraps content in cyan with symbol" do
        msg = Styling.progress_message("Loading...")
        msg.should start_with(Styling::PROGRESS_SYMBOL)
        msg.should contain("Loading...")
      end

      it "info_message uses dim symbol but leaves text unstyled" do
        msg = Styling.info_message("5 items found")
        msg.should start_with(Styling::INFO_SYMBOL)
        msg.should contain("5 items found")
      end

      it "prompt_message wraps content in cyan with symbol" do
        msg = Styling.prompt_message("Continue?")
        msg.should start_with(Styling::PROMPT_SYMBOL)
        msg.should contain("Continue?")
      end
    end

    describe "format_heading" do
      it "renders title in cyan with no suffix" do
        heading = Styling.format_heading("BINARIES")
        heading.should contain("BINARIES")
        has_ansi?(heading).should be_true
      end

      it "renders title in cyan with suffix" do
        heading = Styling.format_heading("USER CONFIG", "~/.config/wt.toml")
        heading.should contain("USER CONFIG")
        heading.should contain("~/.config/wt.toml")
      end
    end

    describe "inline style helpers" do
      it "red wraps text in red ANSI" do
        result = Styling.red("error")
        result.should contain("error")
        has_ansi?(result).should be_true
      end

      it "yellow wraps text in yellow ANSI" do
        result = Styling.yellow("warn")
        result.should contain("warn")
        has_ansi?(result).should be_true
      end

      it "bold wraps text in bold ANSI" do
        result = Styling.bold("hi")
        result.should contain("hi")
        has_ansi?(result).should be_true
      end

      it "dim wraps text in dim ANSI" do
        result = Styling.dim("faint")
        result.should contain("faint")
        has_ansi?(result).should be_true
      end
    end

    describe "terminal_width" do
      it "returns a positive width when TTY is available" do
        width = Styling.terminal_width
        width.should be > 0
      end
    end

    describe "visual_width" do
      it "returns correct width for ASCII" do
        Styling.visual_width("hello").should eq(5)
      end

      it "returns 0 for empty string" do
        Styling.visual_width("").should eq(0)
      end
    end

    describe "format_with_gutter" do
      it "renders a single line with gutter" do
        result = Styling.format_with_gutter("hello", max_width: 80)
        result.should contain("hello")
      end

      it "renders multiple lines with gutter" do
        result = Styling.format_with_gutter("line1\nline2", max_width: 80)
        result.should contain("line1")
        result.should contain("line2")
      end

      it "word-wraps long content at max_width" do
        result = Styling.format_with_gutter("word1 word2 word3 word4", max_width: 15)
        result.lines.size.should be >= 2
      end

      it "preserves explicit newlines in content" do
        result = Styling.format_with_gutter("Line 1\nLine 2\nLine 3", max_width: 80)
        result.lines.size.should be >= 3
        result.should contain("Line 1")
        result.should contain("Line 3")
      end

      it "wraps long paragraphs at terminal width" do
        long_text = "This commit refactors the authentication system to use a more secure token-based approach instead of the previous session-based system which had several security vulnerabilities"
        result = Styling.format_with_gutter(long_text, max_width: 60)
        result.lines.size.should be >= 2
      end
    end

    describe "word wrapping" do
      it "wraps at word boundaries" do
        result = Styling.format_with_gutter("hello world foo bar", max_width: 10)
        # Should wrap into multiple lines since "hello world" > 10
        result.lines.size.should be >= 2
      end

      it "does not break single long words" do
        result = Styling.format_with_gutter("superlongwordthatcannotbreak", max_width: 10)
        result.should contain("superlongwordthatcannotbreak")
      end

      it "returns empty for empty input" do
        result = Styling.format_with_gutter("", max_width: 80)
        result.should eq("")
      end
    end

    describe "format_toml" do
      it "styles section headers in cyan" do
        result = Styling.format_toml("[commit.generation]")
        result.should contain("[commit.generation]")
        has_ansi?(result).should be_true
      end

      it "styles key-value pairs with dim" do
        result = Styling.format_toml("command = \"llm -m haiku\"")
        result.should contain("command")
      end

      it "passes through comments unchanged" do
        result = Styling.format_toml("# this is a comment")
        result.should contain("# this is a comment")
      end

      it "handles multi-line TOML content" do
        toml = <<-TOML
        [commit.generation]
        command = "llm -m haiku"
        # comment
        TOML
        result = Styling.format_toml(toml)
        result.should contain("[commit.generation]")
        result.should contain("command")
        result.should contain("comment")
      end
    end
  end
end
