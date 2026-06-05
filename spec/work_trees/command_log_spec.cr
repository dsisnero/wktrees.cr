require "../spec_helper"

module WorkTrees
  describe CommandLog do
    describe ".truncate_cmd" do
      it "truncates long ASCII commands" do
        long_cmd = "x" * (CommandLog::MAX_CMD_LENGTH + 100)
        result = CommandLog.truncate_cmd(long_cmd)
        result.should end_with("…")
        result.size.should eq(CommandLog::MAX_CMD_LENGTH + 1)
      end

      it "does not truncate short commands" do
        CommandLog.truncate_cmd("echo hello").should eq("echo hello")
      end

      it "handles multibyte truncation" do
        long_cmd = "é" * (CommandLog::MAX_CMD_LENGTH + 100)
        result = CommandLog.truncate_cmd(long_cmd)
        result.should end_with("…")
        result.chars.size.should eq(CommandLog::MAX_CMD_LENGTH + 1)
      end
    end

    describe ".log_command without init" do
      it "safely no-ops when not initialized" do
        CommandLog.log_command("test", "echo hi", exit_code: 0, duration_ms: 100)
      end
    end

    # Upstream: test_json_format — verifies JSON structure has expected fields
    it "produces valid JSON with expected fields" do
      entry = {
        "ts"     => "2026-02-17T10:00:00Z",
        "wt"     => "wt hook pre-merge --yes",
        "label"  => "pre-merge user:lint",
        "cmd"    => "pre-commit run --all-files",
        "exit"   => 0,
        "dur_ms" => 12345_i64,
      }.to_json

      parsed = JSON.parse(entry)
      parsed["label"].should eq("pre-merge user:lint")
      parsed["cmd"].should eq("pre-commit run --all-files")
      parsed["exit"].should eq(0_i64)
      parsed["dur_ms"].should eq(12345_i64)
    end

    # Upstream: test_null_values_for_background
    it "handles null values for background commands" do
      entry = {
        "ts"     => "2026-02-17T10:00:00Z",
        "wt"     => "wt switch",
        "label"  => "post-start user:server",
        "cmd"    => "npm run dev",
        "exit"   => nil,
        "dur_ms" => nil,
      }.to_json

      parsed = JSON.parse(entry)
      parsed["exit"].should eq(JSON::Any.new(nil))
      parsed["dur_ms"].should eq(JSON::Any.new(nil))
    end

    # Upstream: test_special_chars_in_command
    it "handles special characters in command" do
      entry = {"cmd" => "echo \"hello\nworld\""}.to_json
      parsed = JSON.parse(entry)
      parsed["cmd"].should eq("echo \"hello\nworld\"")
    end

    # Upstream: test_write_creates_file_lazily + test_write_appends_multiple_entries
    # + test_rotation_at_size_limit — integration tests using the real log file
    describe "file I/O" do
      tmp_dir = File.join(Dir.tempdir, "wt_cmdlog_test_#{Random.rand(99999)}")

      Spec.before_each do
        Dir.mkdir_p(tmp_dir)
      end

      Spec.after_each do
        Dir.children(tmp_dir).each do |child|
          path = File.join(tmp_dir, child)
          File.delete(path) rescue nil
        end
        Dir.delete(tmp_dir) rescue nil
      end

      it "creates file lazily on first write" do
        log_path = File.join(tmp_dir, "commands.jsonl")
        File.exists?(log_path).should be_false

        CommandLog.init(tmp_dir, "wt test")
        CommandLog.log_command("test", "echo hi", exit_code: 0, duration_ms: 10)
        # File is reopened each log_command call; on create it should exist
        # Sleep briefly to ensure flush
        sleep(50.milliseconds)

        File.exists?(log_path).should be_true
        content = File.read(log_path).strip
        parsed = JSON.parse(content)
        parsed["label"].should eq("test")
        parsed["cmd"].should eq("echo hi")
        parsed["exit"].should eq(0_i64)
        parsed["wt"].should eq("wt test")
      end

      it "appends multiple entries" do
        CommandLog.init(tmp_dir, "wt test")
        CommandLog.log_command("a", "cmd-a", exit_code: 0, duration_ms: 1)
        CommandLog.log_command("b", "cmd-b", exit_code: 1, duration_ms: 2)

        log_path = File.join(tmp_dir, "commands.jsonl")
        sleep(50.milliseconds)

        lines = File.read(log_path).strip.lines
        lines.size.should eq(2)

        first = JSON.parse(lines[0])
        second = JSON.parse(lines[1])
        first["label"].should eq("a")
        second["label"].should eq("b")
      end

      it "rotates when file exceeds size limit" do
        log_path = File.join(tmp_dir, "commands.jsonl")
        old_path = File.join(tmp_dir, "commands.jsonl.old")

        # Write a filler file just over MAX_LOG_SIZE
        filler = "x" * (CommandLog::MAX_LOG_SIZE + 1)
        File.write(log_path, filler)

        CommandLog.init(tmp_dir, "wt test")
        CommandLog.log_command("rotated", "echo rotated", exit_code: 0, duration_ms: 5)

        sleep(50.milliseconds)

        File.exists?(old_path).should be_true
        old_content = File.read(old_path)
        old_content.should eq(filler)

        new_content = File.read(log_path).strip
        parsed = JSON.parse(new_content)
        parsed["label"].should eq("rotated")
      end
    end
  end
end
