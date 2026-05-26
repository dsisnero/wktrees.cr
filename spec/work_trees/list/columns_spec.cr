require "../../spec_helper"
require "../../../src/work_trees/list/columns"

module WorkTrees::List
  describe ColumnKind do
    describe "#header" do
      it "returns empty for Gutter" do
        ColumnKind::Gutter.header.should eq("")
      end

      it "returns non-empty for all other columns" do
        kinds = ColumnKind.values.reject(&.gutter?)
        kinds.each do |kind|
          kind.header.should_not be_empty
        end
      end

      it "has correct headers" do
        ColumnKind::Branch.header.should eq("Branch")
        ColumnKind::Status.header.should eq("Status")
        ColumnKind::WorkingDiff.header.should eq("HEAD±")
        ColumnKind::AheadBehind.header.should eq("main↕")
        ColumnKind::BranchDiff.header.should eq("main…±")
        ColumnKind::Path.header.should eq("Path")
        ColumnKind::Upstream.header.should eq("Remote⇅")
        ColumnKind::Url.header.should eq("URL")
        ColumnKind::Time.header.should eq("Age")
        ColumnKind::CiStatus.header.should eq("CI")
        ColumnKind::Commit.header.should eq("Commit")
        ColumnKind::Summary.header.should eq("Summary")
        ColumnKind::Message.header.should eq("Message")
      end
    end

    describe "#priority" do
      it "returns a valid priority for every column kind" do
        ColumnKind.values.each do |kind|
          kind.priority.should_not eq(UInt8::MAX)
        end
      end
    end
  end

  describe "COLUMN_SPECS" do
    it "columns are in the correct display order" do
      expected = [
        ColumnKind::Gutter,
        ColumnKind::Branch,
        ColumnKind::Status,
        ColumnKind::WorkingDiff,
        ColumnKind::AheadBehind,
        ColumnKind::BranchDiff,
        ColumnKind::Summary,
        ColumnKind::Upstream,
        ColumnKind::CiStatus,
        ColumnKind::Path,
        ColumnKind::Url,
        ColumnKind::Commit,
        ColumnKind::Time,
        ColumnKind::Message,
      ]
      kinds = COLUMN_SPECS.map(&.kind)
      kinds.should eq(expected)
    end

    it "base_priority values are unique" do
      priorities = COLUMN_SPECS.map(&.base_priority)
      priorities.uniq.size.should eq(priorities.size)
    end

    it "only 4 columns require tasks" do
      task_cols = COLUMN_SPECS.select { |s| !s.requires_task.nil? }.map(&.kind)
      task_cols.should contain(ColumnKind::BranchDiff)
      task_cols.should contain(ColumnKind::Summary)
      task_cols.should contain(ColumnKind::CiStatus)
      task_cols.should contain(ColumnKind::Url)
      task_cols.size.should eq(4)
    end

    it "columns requiring tasks have correct task names" do
      spec = COLUMN_SPECS.find { |s| s.kind == ColumnKind::BranchDiff }.not_nil!
      spec.requires_task.should eq("branch-diff")

      spec = COLUMN_SPECS.find { |s| s.kind == ColumnKind::Url }.not_nil!
      spec.requires_task.should eq("url-status")

      spec = COLUMN_SPECS.find { |s| s.kind == ColumnKind::CiStatus }.not_nil!
      spec.requires_task.should eq("ci-status")

      spec = COLUMN_SPECS.find { |s| s.kind == ColumnKind::Summary }.not_nil!
      spec.requires_task.should eq("summary-generate")
    end

    it "Branch is shrinkable" do
      spec = COLUMN_SPECS.find { |s| s.kind == ColumnKind::Branch }.not_nil!
      spec.shrinkable?.should be_true
    end
  end

  describe ".column_display_index" do
    it "returns correct indices" do
      List.column_display_index(ColumnKind::Gutter).should eq(0)
      List.column_display_index(ColumnKind::Branch).should eq(1)
      List.column_display_index(ColumnKind::Message).should eq(13)
    end
  end
end
