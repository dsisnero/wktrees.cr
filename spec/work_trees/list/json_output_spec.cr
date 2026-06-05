require "../../spec_helper"

module WorkTrees
  describe List::JsonOutput do
    describe "JsonCommit" do
      it "serializes sha, short_sha, message, timestamp" do
        commit = List::JsonOutput::JsonCommit.new(
          sha: "abc123def456", short_sha: "abc123d",
          message: "feat: add feature", timestamp: 1718273932_i64,
        )
        json = commit.to_json
        json.should contain("abc123def456")
        json.should contain("abc123d")
        json.should contain("feat: add feature")
        json.should contain("1718273932")
      end
    end

    describe "JsonWorkingTree" do
      it "serializes working tree state flags" do
        wt = List::JsonOutput::JsonWorkingTree.new(
          staged: true, modified: false, untracked: true,
          renamed: false, deleted: false,
        )
        json = wt.to_json
        json.should contain("staged")
        json.should contain("untracked")
      end

      it "includes diff when present" do
        diff = List::JsonOutput::JsonDiff.new(added: 5, deleted: 3)
        wt = List::JsonOutput::JsonWorkingTree.new(
          staged: true, modified: false, untracked: false,
          diff: diff,
        )
        json = wt.to_json
        json.should contain("added")
        json.should contain("deleted")
      end
    end

    describe "JsonItem" do
      it "serializes with branch and kind" do
        commit = List::JsonOutput::JsonCommit.new(
          sha: "abc", short_sha: "abc", message: "init", timestamp: 1_i64,
        )
        item = List::JsonOutput::JsonItem.new(
          commit: commit, branch: "feature", kind: "worktree",
        )
        json = item.to_json
        json.should contain("feature")
        json.should contain("worktree")
      end

      it "serializes with CI status" do
        commit = List::JsonOutput::JsonCommit.new(
          sha: "abc", short_sha: "abc", message: "init", timestamp: 1_i64,
        )
        ci = List::JsonOutput::JsonCi.new(status: "passed", source: "pr", stale: false)
        item = List::JsonOutput::JsonItem.new(
          commit: commit, branch: "feature", kind: "worktree", ci: ci,
        )
        json = item.to_json
        json.should contain("ci")
        json.should contain("passed")
        json.should contain("pr")
      end

      it "skips nil optional fields" do
        commit = List::JsonOutput::JsonCommit.new(
          sha: "abc", short_sha: "abc", message: "init", timestamp: 1_i64,
        )
        item = List::JsonOutput::JsonItem.new(
          commit: commit, branch: "main", kind: "worktree",
        )
        json = item.to_json
        json.should_not contain("working_tree")
        json.should_not contain("ci")
        json.should_not contain("summary")
      end

      it "produces valid JSON that parses back" do
        commit = List::JsonOutput::JsonCommit.new(
          sha: "deadbeef", short_sha: "deadbee", message: "feat: login", timestamp: 1700000000_i64,
        )
        item = List::JsonOutput::JsonItem.new(commit: commit, branch: "fix/auth", kind: "worktree")
        json = item.to_json
        parsed = JSON.parse(json)
        parsed["branch"].should eq(JSON::Any.new("fix/auth"))
        parsed["kind"].should eq(JSON::Any.new("worktree"))
        parsed["commit"]["sha"].should eq(JSON::Any.new("deadbeef"))
      end
    end

    describe "JsonDiff" do
      it "serializes added and deleted" do
        diff = List::JsonOutput::JsonDiff.new(added: 100, deleted: 50)
        json = diff.to_json
        json.should contain("100")
        json.should contain("50")
      end

      it "round-trips through JSON parse" do
        diff = List::JsonOutput::JsonDiff.new(added: 7, deleted: 3)
        json = diff.to_json
        parsed = JSON.parse(json)
        parsed["added"].should eq(JSON::Any.new(7_i64))
        parsed["deleted"].should eq(JSON::Any.new(3_i64))
      end
    end

    describe "JsonCi" do
      it "serializes status, source, and stale flag" do
        ci = List::JsonOutput::JsonCi.new(status: "failed", source: "pr", stale: true)
        json = ci.to_json
        json.should contain("failed")
        json.should contain("pr")
        json.should contain("stale")
      end

      it "stale defaults to false" do
        ci = List::JsonOutput::JsonCi.new(status: "passed", source: "branch")
        json = ci.to_json
        json.should contain("false")
      end
    end
  end
end
