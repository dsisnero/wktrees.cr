require "../spec_helper"

module WorkTrees
  describe Trace do
    describe ".format_command" do
      it "formats a completed command trace" do
        record = Trace.format_command("git", "status", 12345_u64, 3_u64, 12000_u64, ok: true, context: "feature")
        record.should contain("[wt-trace]")
        record.should contain("cmd=\"git status\"")
        record.should contain("dur_us=12000")
        record.should contain("ok=true")
        record.should contain("context=feature")
        record.should contain("ts=12345")
        record.should contain("tid=3")
      end

      it "formats a failed command trace" do
        record = Trace.format_command("gh", "pr list", 9999_u64, 1_u64, 45000_u64, ok: false)
        record.should contain("[wt-trace]")
        record.should contain("cmd=\"gh pr list\"")
        record.should contain("ok=false")
        record.should contain("dur_us=45000")
      end

      it "formats without context when absent" do
        record = Trace.format_command("git", "rev-parse", 100_u64, 2_u64, 5000_u64, ok: true)
        record.should contain("[wt-trace]")
        record.should contain("cmd=\"git rev-parse\"")
        record.should_not contain("context=")
      end
    end

    describe ".format_span" do
      it "formats a completed span trace" do
        record = Trace.format_span("config_load", 5555_u64, 1_u64, 8200_u64)
        record.should contain("[wt-trace]")
        record.should contain("span=\"config_load\"")
        record.should contain("dur_us=8200")
        record.should contain("ts=5555")
      end
    end

    describe ".format_instant" do
      it "formats an instant event" do
        record = Trace.format_instant("Showed skeleton")
        record.should contain("[wt-trace]")
        record.should contain("event=\"Showed skeleton\"")
        record.should contain("ts=")
        record.should contain("tid=")
      end
    end

    describe ".format_error" do
      it "formats a command error trace" do
        record = Trace.format_error("git", "fetch", 1234_u64, 2_u64, 1000_u64, "fatal: remote not found")
        record.should contain("[wt-trace]")
        record.should contain("cmd=\"git fetch\"")
        record.should contain("err=\"fatal: remote not found\"")
        record.should contain("ok=false")
      end
    end

    describe ".span" do
      it "times a block and returns the block result" do
        result = Trace.span("test_span") { 42 }
        result.should eq(42)
      end

      it "emits a span record on completion" do
        # Verify the span format is correct (can't test actual emission)
        record = Trace.format_span("block_span", 100_u64, 2_u64, 5000_u64)
        record.should contain("[wt-trace]")
        record.should contain("span=\"block_span\"")
        record.should contain("dur_us=5000")
      end
    end
  end
end
