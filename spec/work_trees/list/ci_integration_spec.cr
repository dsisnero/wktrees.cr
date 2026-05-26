require "../../spec_helper"

module WorkTrees
  describe "List CI status integration" do
    describe "platform_for_branch" do
      it "detects GitHub from URL" do
        platform = Commands.platform_for_branch("https://github.com/user/repo.git")
        platform.should eq(CiPlatform::GitHub)
      end

      it "detects GitLab from URL" do
        platform = Commands.platform_for_branch("https://gitlab.com/user/repo.git")
        platform.should eq(CiPlatform::GitLab)
      end

      it "returns Unknown for unrecognized URL" do
        platform = Commands.platform_for_branch("https://bitbucket.org/user/repo.git")
        platform.should eq(CiPlatform::Unknown)
      end

      it "returns Unknown for empty URL" do
        platform = Commands.platform_for_branch("")
        platform.should eq(CiPlatform::Unknown)
      end

      it "returns Unknown for unparseable URL" do
        platform = Commands.platform_for_branch("not-a-url")
        platform.should eq(CiPlatform::Unknown)
      end
    end
  end
end
