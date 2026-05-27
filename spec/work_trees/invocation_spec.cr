require "../spec_helper"

module WorkTrees
  describe Invocation do
    describe "binary_name" do
      it "returns a non-empty string" do
        Invocation.binary_name.should_not be_empty
      end

      it "strips .exe extension" do
        # Test the logic directly
        result = Invocation.binary_name_from("work_trees.exe")
        result.should eq("work_trees")
      end

      it "handles full path" do
        result = Invocation.binary_name_from("/usr/local/bin/work_trees")
        result.should eq("work_trees")
      end

      it "handles relative path" do
        result = Invocation.binary_name_from("./target/debug/work_trees")
        result.should eq("work_trees")
      end
    end

    describe "invocation_path" do
      it "normalizes backslashes" do
        result = Invocation.invocation_path_from("C:\\Users\\test\\work_trees.exe")
        result.should_not contain("\\")
      end
    end

    describe "was_invoked_with_explicit_path?" do
      it "detects forward-slash paths" do
        Invocation.was_invoked_with_explicit_path?("./target/debug/wt").should be_true
      end

      it "detects backslash paths" do
        Invocation.was_invoked_with_explicit_path?("C:\\tools\\wt.exe").should be_true
      end

      it "returns false for bare binary name" do
        Invocation.was_invoked_with_explicit_path?("wt").should be_false
      end
    end
  end
end
