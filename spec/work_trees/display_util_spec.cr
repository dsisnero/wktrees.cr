require "../spec_helper"

module WorkTrees
  describe DisplayUtil do
    describe "format_relative_time_short" do
      it "returns 'now' for recent timestamps" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now)
        result.should eq("now")
      end

      it "returns '5m' for 5 minutes ago" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now - 300)
        result.should contain("m")
      end

      it "returns '2h' for 2 hours ago" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now - 7200)
        result.should contain("h")
      end

      it "returns '3d' for 3 days ago" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now - 259200)
        result.should contain("d")
      end

      it "handles future timestamps" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now + 1000)
        result.should_not be_empty
      end
    end

    describe "truncate_to_width" do
      it "returns text unchanged when under max_width" do
        result = DisplayUtil.truncate_to_width("hello", 20)
        result.should eq("hello")
      end

      it "truncates with ellipsis when over max_width" do
        result = DisplayUtil.truncate_to_width("This is a very long message", 15)
        result.should end_with("…")
        Styling.visual_width(result).should be <= 15
      end

      it "truncates mid-word if needed" do
        result = DisplayUtil.truncate_to_width("hello world", 6)
        result.should end_with("…")
      end

      it "handles unicode characters correctly" do
        result = DisplayUtil.truncate_to_width("café latte", 8)
        result.should end_with("…")
      end
    end
  end
end
