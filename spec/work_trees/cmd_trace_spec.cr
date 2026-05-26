require "../spec_helper"

module WorkTrees
  describe Cmd do
    describe "trace emission" do
      it "produces a valid trace record for successful command" do
        result = Cmd.new("echo").arg("hello").run
        result.success?.should be_true

        # Format a trace record manually (normally done by Cmd.run)
        trace = Trace.format_command(
          "echo", "hello", Trace.now_us, Trace.thread_id,
          1000_u64, ok: true, context: "test")
        trace.should contain("[wt-trace]")
        trace.should contain("cmd=\"echo hello\"")
        trace.should contain("ok=true")
        trace.should contain("context=test")
        trace.should contain("dur_us=")
      end

      it "produces a trace record for failed command" do
        result = Cmd.new("nonexistent_command_xyz").arg("--help").run
        result.success?.should be_false

        trace = Trace.format_command(
          "nonexistent_command_xyz", "--help", Trace.now_us, Trace.thread_id,
          500_u64, ok: false)
        trace.should contain("[wt-trace]")
        trace.should contain("ok=false")
        trace.should_not contain("context=")
      end

      it "format_span produces correct duration" do
        span = Trace.format_span("config_load", 100_u64, 2_u64, 8200_u64)
        span.should contain("span=\"config_load\"")
        span.should contain("dur_us=8200")
      end
    end
  end
end
