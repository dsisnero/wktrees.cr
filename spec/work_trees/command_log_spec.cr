require "../spec_helper"
require "file_utils"

module WorkTrees
  describe CommandLog do
    describe "truncate_cmd" do
      it "truncates long ASCII commands and appends …" do
        long = "x" * (CommandLog::MAX_CMD_LENGTH + 100)
        truncated = CommandLog.truncate_cmd(long)
        truncated.chars.size.should eq(CommandLog::MAX_CMD_LENGTH + 1)
        truncated.should end_with("…")
      end

      it "truncates long multibyte commands on character boundaries" do
        long = "é" * (CommandLog::MAX_CMD_LENGTH + 100)
        truncated = CommandLog.truncate_cmd(long)
        truncated.chars.size.should eq(CommandLog::MAX_CMD_LENGTH + 1)
        truncated.should end_with("…")
      end

      it "returns short commands unchanged" do
        short = "echo hello"
        CommandLog.truncate_cmd(short).should eq("echo hello")
      end

      it "does not truncate a 2000-char multibyte string" do
        exact = "é" * CommandLog::MAX_CMD_LENGTH
        result = CommandLog.truncate_cmd(exact)
        result.chars.size.should eq(CommandLog::MAX_CMD_LENGTH)
        result.should_not end_with("…")
      end
    end

    describe "log_command without init" do
      it "silently no-ops" do
        CommandLog.log_command("test", "echo hello", exit_code: 0, duration_ms: 100)
      end
    end

    describe "JSON entry format" do
      it "produces the expected keys and values" do
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
        parsed["exit"].as_i.should eq(0)
        parsed["dur_ms"].as_i.should eq(12345)
      end
    end

    describe "null values for background commands" do
      it "emits null for exit_code and duration_ms" do
        entry = {
          "ts"     => "2026-02-17T10:00:00Z",
          "wt"     => "wt switch",
          "label"  => "post-start user:server",
          "cmd"    => "npm run dev",
          "exit"   => nil,
          "dur_ms" => nil,
        }.to_json
        parsed = JSON.parse(entry)
        parsed["exit"].raw.should be_nil
        parsed["dur_ms"].raw.should be_nil
      end
    end

    describe "special characters in command" do
      it "escapes correctly in JSON" do
        entry = {"cmd" => "echo \"hello\nworld\""}.to_json
        parsed = JSON.parse(entry)
        parsed["cmd"].should eq("echo \"hello\nworld\"")
      end
    end

    describe "file operations" do
      it "creates the log file lazily on first write" do
        dir = File.tempname("wt-cmdlog")
        begin
          Dir.mkdir_p(dir)
          CommandLog.init(dir, "wt test")
          log_path = File.join(dir, "commands.jsonl")
          File.exists?(log_path).should be_false

          CommandLog.log_command("test", "echo hi", exit_code: 0, duration_ms: 10)
          File.exists?(log_path).should be_true

          content = File.read(log_path)
          parsed = JSON.parse(content.strip)
          parsed["label"].should eq("test")
          parsed["cmd"].should eq("echo hi")
          parsed["exit"].as_i.should eq(0)
          parsed["wt"].should eq("wt test")
        ensure
          FileUtils.rm_rf(dir)
        end
      end

      it "appends multiple entries as JSONL lines" do
        dir = File.tempname("wt-cmdlog-append")
        begin
          Dir.mkdir_p(dir)
          CommandLog.init(dir, "wt test")

          CommandLog.log_command("a", "cmd-a", exit_code: 0, duration_ms: 1)
          CommandLog.log_command("b", "cmd-b", exit_code: 1, duration_ms: 2)

          content = File.read(File.join(dir, "commands.jsonl"))
          lines = content.strip.lines
          lines.size.should eq(2)

          first = JSON.parse(lines[0])
          second = JSON.parse(lines[1])
          first["label"].should eq("a")
          second["label"].should eq("b")
        ensure
          FileUtils.rm_rf(dir)
        end
      end

      it "rotates when file exceeds MAX_LOG_SIZE" do
        dir = File.tempname("wt-cmdlog-rotate")
        begin
          Dir.mkdir_p(dir)
          log_path = File.join(dir, "commands.jsonl")

          # Pre-create an oversized file
          filler = "x" * (CommandLog::MAX_LOG_SIZE + 1)
          File.write(log_path, filler)

          CommandLog.init(dir, "wt test")
          CommandLog.log_command("rotated", "echo rotated", exit_code: 0, duration_ms: 5)

          # Old file should exist with the filler content
          old_path = File.join(dir, "commands.jsonl.old")
          File.exists?(old_path).should be_true
          File.read(old_path).should eq(filler)

          # New file should have just the one entry
          content = File.read(log_path)
          parsed = JSON.parse(content.strip)
          parsed["label"].should eq("rotated")
        ensure
          FileUtils.rm_rf(dir)
        end
      end

      it "rotates correctly when the log directory name contains .jsonl" do
        dir = File.tempname("wt.jsonl-rotate")
        begin
          Dir.mkdir_p(dir)
          log_path = File.join(dir, "commands.jsonl")

          filler = "x" * (CommandLog::MAX_LOG_SIZE + 1)
          File.write(log_path, filler)

          CommandLog.init(dir, "wt test")
          CommandLog.log_command("safe", "echo safe", exit_code: 0, duration_ms: 1)

          old_path = File.join(dir, "commands.jsonl.old")
          File.exists?(old_path).should be_true
          File.read(old_path).should eq(filler)
        ensure
          FileUtils.rm_rf(dir)
        end
      end
    end
  end
end
