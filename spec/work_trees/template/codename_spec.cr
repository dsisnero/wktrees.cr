require "../../spec_helper"

describe WorkTrees::Template do
  describe ".codename" do
    it "produces deterministic output" do
      c1 = WorkTrees::Template.codename("feature-auth")
      c2 = WorkTrees::Template.codename("feature-auth")
      c1.should eq(c2)
    end

    it "produces different names for different inputs" do
      c1 = WorkTrees::Template.codename("branch-a")
      c2 = WorkTrees::Template.codename("branch-b")
      c1.should_not eq(c2)
    end

    it "defaults to 2 words" do
      name = WorkTrees::Template.codename("test")
      parts = name.split('-')
      parts.size.should eq(2)
    end

    it "respects word count argument" do
      name = WorkTrees::Template.codename("test", 3)
      parts = name.split('-')
      parts.size.should eq(3)
    end

    it "rejects zero words" do
      expect_raises(ArgumentError) do
        WorkTrees::Template.codename("test", 0)
      end
    end

    it "rejects word count exceeding max" do
      expect_raises(ArgumentError) do
        WorkTrees::Template.codename("test", WorkTrees::Template::CODENAME_MAX_WORDS + 1)
      end
    end

    it "produces hyphen-separated lowercase words" do
      name = WorkTrees::Template.codename("some-branch")
      name.should match(/^[a-z]+(-[a-z]+)+$/)
    end

    it "accepts single word" do
      name = WorkTrees::Template.codename("test", 1)
      parts = name.split('-')
      parts.size.should eq(1)
    end

    it "matches upstream stable outputs" do
      WorkTrees::Template.codename("main", 1).should eq("gorilla")
      WorkTrees::Template.codename("feature/auth", 2).should eq("malleable-opah")
      WorkTrees::Template.codename("feature/73", 2).should eq("prodigious-shoveler")
      WorkTrees::Template.codename("feature/149", 2).should eq("tuneful-vendace")
      WorkTrees::Template.codename("release/1.0", 3).should eq("intent-equipped-treefrog")
      WorkTrees::Template.codename("hotfix/some-very-long-thing", 4).should eq("noteworthy-musical-durable-silkworm")
    end
  end
end
