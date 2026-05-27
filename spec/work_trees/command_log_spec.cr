require "../spec_helper"

module WorkTrees
  describe CommandLog do
    it "truncates long ASCII commands" do
      long_cmd = "x" * (2100)
      result = CommandLog.truncate_cmd(long_cmd)
      result.size.should be <= 2001 # 2000 + "…"
      result.should end_with("…")
    end

    it "does not truncate short commands" do
      CommandLog.truncate_cmd("echo hello").should eq("echo hello")
    end

    it "handles multibyte truncation" do
      long_cmd = "é" * 2100
      result = CommandLog.truncate_cmd(long_cmd)
      result.should end_with("…")
    end

    it "safely no-ops when not initialized" do
      # Should not crash
      CommandLog.log_command("test", "echo hi", exit_code: 0, duration_ms: 100)
    end
  end
end
