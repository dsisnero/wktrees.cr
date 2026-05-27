require "../../spec_helper"

module WorkTrees
  describe List::Render do
    describe "compact_number" do
      it "shows raw numbers under 100" do
        List::Render.compact_number(42).should eq("42")
        List::Render.compact_number(0).should eq("0")
        List::Render.compact_number(99).should eq("99")
      end

      it "shows raw numbers 100-999 for diffs" do
        List::Render.compact_number(100).should eq("100")
        List::Render.compact_number(648).should eq("648")
      end

      it "shows K for thousands" do
        List::Render.compact_number(1000).should eq("1K")
        List::Render.compact_number(2500).should eq("2K")
        List::Render.compact_number(9999).should eq("9K")
      end

      it "shows ∞ for values >= 10K" do
        List::Render.compact_number(10_000).should eq("∞")
        List::Render.compact_number(100_000).should eq("∞")
      end

      it "shows C for commit counts 100-999" do
        List::Render.compact_number(500, variant: :arrows).should eq("5C")
        List::Render.compact_number(100, variant: :arrows).should eq("1C")
      end
    end

    describe "format_diff" do
      it "formats added/deleted with + and -" do
        result = List::Render.format_diff(5, 3)
        result.should contain("+5")
        result.should contain("-3")
      end

      it "returns empty for zero changes" do
        List::Render.format_diff(0, 0).should eq("")
      end

      it "shows only additions when no deletions" do
        result = List::Render.format_diff(10, 0)
        result.should contain("+")
        result.should_not contain("-")
      end
    end

    describe "PLACEHOLDER" do
      it "is a middle dot" do
        List::Render::PLACEHOLDER.should eq("·")
      end

      it "PLACEHOLDER_BLANK is a space" do
        List::Render::PLACEHOLDER_BLANK.should eq(" ")
      end
    end
  end
end
