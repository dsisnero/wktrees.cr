require "../spec_helper"

module WorkTrees
  describe Output do
    describe "verbosity" do
      it "defaults to 0 (normal)" do
        Output.verbosity.should eq(0)
      end

      it "can be set and read" do
        Output.verbosity = 1
        Output.verbosity.should eq(1)
        Output.verbosity = 0
      end
    end

    describe ".verbose?" do
      it "returns false at verbosity 0" do
        Output.verbosity = 0
        Output.verbose?.should be_false
      end

      it "returns true at verbosity 1" do
        Output.verbosity = 1
        Output.verbose?.should be_true
        Output.verbosity = 0
      end

      it "returns true at verbosity 2 (debug)" do
        Output.verbosity = 2
        Output.verbose?.should be_true
        Output.verbosity = 0
      end
    end

    describe ".debug?" do
      it "returns false at verbosity 1" do
        Output.verbosity = 1
        Output.debug?.should be_false
        Output.verbosity = 0
      end

      it "returns true at verbosity 2" do
        Output.verbosity = 2
        Output.debug?.should be_true
        Output.verbosity = 0
      end
    end

    describe ".init_from_flags" do
      it "consumes -v flag and sets verbosity" do
        args = ["-v", "list"]
        Output.init_from_flags(args)
        Output.verbosity.should eq(1)
        args.should eq(["list"]) # -v consumed
        Output.verbosity = 0
      end

      it "consumes -vv flag and sets debug" do
        args = ["-vv", "list"]
        Output.init_from_flags(args)
        Output.verbosity.should eq(2)
        args.should eq(["list"])
        Output.verbosity = 0
      end

      it "handles args without verbose flags" do
        args = ["list", "--full"]
        Output.init_from_flags(args)
        Output.verbosity.should eq(0)
        args.should eq(["list", "--full"]) # unchanged
      end
    end

    describe "data output" do
      it "writes to stdout by default" do
        io = IO::Memory.new
        Output.data("table data", io)
        io.to_s.should contain("table data")
      end
    end

    describe ".command_output" do
      it "formats command with gutter when verbose" do
        Output.verbosity = 1
        result = Output.command_output("echo hello", "hello world")
        result.should contain("hello")
        Output.verbosity = 0
      end

      it "returns plain output when not verbose" do
        result = Output.command_output("echo hello", "hello world")
        result.should eq("hello world")
      end
    end
  end
end
