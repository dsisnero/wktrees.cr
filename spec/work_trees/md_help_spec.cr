require "../spec_helper"

module WorkTrees
  describe "Markdown help rendering" do
    describe "render_markdown" do
      it "renders green headers" do
        result = Commands.render_markdown("# My Header")
        result.should contain("My Header")
        # Headers should contain ANSI green escape
        result.should contain("\e[")
      end

      it "renders bold text" do
        result = Commands.render_markdown("Use **--force** carefully")
        result.should contain("--force")
        result.should contain("\e[")
        result.should_not contain("**")
      end

      it "renders inline code as dim" do
        result = Commands.render_markdown("Run `cargo build` first")
        result.should contain("cargo build")
        result.should contain("\e[")
        result.should_not contain("`")
      end

      it "renders code fences as gutter blocks" do
        result = Commands.render_markdown("```\necho hello\n```")
        result.should contain("echo hello")
        result.should_not contain("```")
      end

      it "renders bullet lists" do
        result = Commands.render_markdown("- Item one\n- Item two")
        result.should contain("Item one")
        result.should contain("Item two")
      end

      it "skips HTML comments" do
        result = Commands.render_markdown("<!-- this is a comment -->\nvisible text")
        result.should contain("visible text")
        result.should_not contain("comment")
      end

      it "passes through plain text unchanged" do
        result = Commands.render_markdown("plain text here")
        result.should contain("plain text here")
      end

      it "renders sub-headings" do
        result = Commands.render_markdown("## Subsection\ncontent")
        result.should contain("Subsection")
        result.should contain("\e[")
      end
    end
  end
end
