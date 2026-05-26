require "../../spec_helper"

module WorkTrees
  describe "List column layout" do
    describe "calculate_column_widths" do
      it "divides terminal width across columns" do
        headers = ["Branch", "Worktree", "HEAD"]
        widths = Commands.calculate_column_widths(headers, columns_data, terminal: 100)
        widths.size.should eq(3)
        widths.sum.should eq(100)
      end

      it "allocates more space to wider content" do
        headers = ["B", "W"]
        data = [["short", "very_long_content_here"]]
        widths = Commands.calculate_column_widths(headers, data, terminal: 40)
        # The wider column (index 1) should get more space
        widths[1].should be > widths[0]
      end

      it "respects minimum column widths" do
        headers = ["Branch", "Status"]
        data = [["x", "x"]]
        widths = Commands.calculate_column_widths(headers, data, terminal: 20)
        widths.all? { |w| w >= 1 }.should be_true
      end

      it "drops flexible columns when terminal is narrow" do
        headers = ["Branch", "Worktree", "HEAD", "Extra"]
        data = [["feature/my-branch", "/home/user/worktrees/feature", "abc1234", "extra"]]
        widths = Commands.calculate_column_widths(headers, data, terminal: 40)
        # Extra column should get dropped or squeezed
        widths.sum.should eq(40)
      end

      it "returns equal widths when terminal is huge" do
        headers = ["B", "W"]
        data = [["a", "b"]]
        widths = Commands.calculate_column_widths(headers, data, terminal: 10_000)
        widths.sum.should eq(10_000)
        # All widths should be the same since data is small
        widths[0].should eq(widths[1])
      end
    end

    describe "build_list_table" do
      it "renders headers and rows as lipgloss table" do
        headers = ["Branch", "Worktree"]
        rows = [["main", "/home/user/main"]]
        table = Commands.build_list_table(headers, rows, terminal: 80)
        table.should contain("main")
        table.should contain("/home/user/main")
        table.should contain("Branch")
      end

      it "handles empty rows" do
        table = Commands.build_list_table(["Col"], [] of Array(String), terminal: 80)
        table.should contain("Col")
      end
    end
  end
end

private def columns_data
  [
    ["main", "/home/user/main", "abc1234"],
    ["feature/long-branch-name", "/home/user/worktrees/feature", "def5678"],
  ]
end
