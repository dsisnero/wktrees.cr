require "../spec_helper"

module WorkTrees
  describe DisplayUtil do
    describe "format_relative_time_short" do
      it "returns 'now' for recent timestamps" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 30, now).should eq("now")
        DisplayUtil.format_relative_time_impl(now - 59, now).should eq("now")
      end

      it "returns '1m' for 1 minute ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 60, now).should eq("1m")
      end

      it "returns '2m' for 2 minutes ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 120, now).should eq("2m")
      end

      it "returns '59m' for 59 minutes ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 3599, now).should eq("59m")
      end

      it "returns '1h' for 1 hour ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 3600, now).should eq("1h")
      end

      it "returns '2h' for 2 hours ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 7200, now).should eq("2h")
      end

      it "returns '1d' for 1 day ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 86400, now).should eq("1d")
      end

      it "returns '2d' for 2 days ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 172800, now).should eq("2d")
      end

      it "returns '1w' for 1 week ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 604800, now).should eq("1w")
      end

      it "returns '1mo' for 1 month ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 2592000, now).should eq("1mo")
      end

      it "returns '1y' for 1 year ago" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 31536000, now).should eq("1y")
      end

      it "returns 'future' for future timestamps" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now + 1000, now).should eq("future")
      end

      it "returns 'now' for timestamps < 60s" do
        now = Time.utc.to_unix
        result = DisplayUtil.format_relative_time_short(now)
        result.should eq("now")
      end

      # Upstream boundary tests: week takes priority over days
      it "returns '1w' for exactly 604800 seconds (7 days)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 604800, now).should eq("1w")
      end

      it "returns '2w' for exactly 1209600 seconds (14 days)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 1209600, now).should eq("2w")
      end

      it "returns '6d' for 604799 seconds (1s under 1 week)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 604799, now).should eq("6d")
      end

      it "returns '1mo' for exactly 2592000 seconds (30 days)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 2592000, now).should eq("1mo")
      end

      it "returns '4w' for 2419200 seconds (just over 28 days)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 2419200, now).should eq("4w")
      end

      it "returns '1y' for exactly 31536000 seconds (365 days)" do
        now = 1700000000_i64
        DisplayUtil.format_relative_time_impl(now - 31536000, now).should eq("1y")
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
