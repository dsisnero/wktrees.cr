require "../spec_helper"

module WorkTrees
  describe "LLM helpers" do
    describe "prepare_diff" do
      it "returns full diff when under threshold" do
        small_diff = "diff --git a/x b/x\n+add\n-delete\n" * 10
        result = Commands.prepare_diff(small_diff, max_chars: 50000)
        result.should eq(small_diff)
      end

      it "truncates large diffs to max files" do
        # Generate diff with many files
        lines = [] of String
        10.times do |i|
          lines << "diff --git a/file#{i}.rs b/file#{i}.rs"
          3.times { lines << "+line" }
        end
        large_diff = lines.join('\n')

        result = Commands.prepare_diff(large_diff, max_chars: 100, max_files: 3)
        # Should only include first 3 files
        file_count = result.lines.count { |l| l.starts_with?("diff --git") }
        file_count.should eq(3)
      end

      it "truncates per-file lines when diff exceeds max_chars" do
        lines = ["diff --git a/x.rs b/x.rs"]
        100.times { lines << "+long line of code here" }
        diff = lines.join('\n')

        result = Commands.prepare_diff(diff, max_chars: 100, max_lines_per_file: 5)
        result.size.should be < diff.size
        result.should contain("truncated")
      end

      it "returns empty for empty diff" do
        Commands.prepare_diff("", max_chars: 1000).should eq("")
      end

      # Upstream parity: preserves header content before first diff block
      it "preserves preamble text before first diff block" do
        diff = "commit abc123\nAuthor: Test\n\ndiff --git a/x.rs b/x.rs\n+code\n"
        result = Commands.prepare_diff(diff, max_chars: 100)
        result.should contain("commit abc123")
        result.should contain("diff --git a/x.rs")
      end

      # Upstream parity: handles single large file within max_files
      it "truncates lines within a single large file" do
        lines = ["diff --git a/big.rs b/big.rs"]
        200.times { |i| lines << "+line #{i}" }
        diff = lines.join('\n')

        result = Commands.prepare_diff(diff, max_chars: 50, max_lines_per_file: 10, max_files: 1)
        result.should contain("truncated")
        result.lines.size.should be < 200
      end

      # Adversarial: diff contains "diff --git" in code context, not as boundary
      it "does not split on diff --git appearing inside code" do
        diff = "diff --git a/main.rs b/main.rs\n+fn log(msg: &str) {\n+    println!(\"diff --git detected\");\n+}\n" +
               "diff --git a/lib.rs b/lib.rs\n+fn helper() {}\n"
        result = Commands.prepare_diff(diff, max_chars: 200)
        # Should still recognize the two proper file boundaries
        result.lines.count { |l| l.starts_with?("diff --git") }.should eq(2)
      end

      # Edge case: exactly max_chars
      it "handles diff exactly at max_chars boundary" do
        diff = "diff --git a/x b/x\n+line\n"
        result = Commands.prepare_diff(diff, max_chars: diff.size)
        result.should eq(diff)
      end
    end

    describe "shell_wrap_command" do
      it "wraps commands with shell metacharacters" do
        result = Commands.shell_wrap_command("claude -p 'summarize this' && echo done")
        result.should contain("sh -c")
      end

      it "does not wrap simple commands" do
        result = Commands.shell_wrap_command("llm -m haiku")
        result.should_not contain("sh -c")
        result.should eq("llm -m haiku")
      end

      it "detects pipe as metacharacter" do
        result = Commands.shell_wrap_command("diff | llm")
        result.should contain("sh -c")
      end
    end
  end
end
