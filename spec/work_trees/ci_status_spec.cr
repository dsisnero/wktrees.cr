require "../spec_helper"

module WorkTrees
  describe "CI status" do
    describe "CiPlatform" do
      it "detects GitHub from remote URL" do
        url = Git::GitRemoteUrl.parse("https://github.com/user/repo.git").not_nil!
        platform = CiPlatform.detect(url)
        platform.should eq(CiPlatform::GitHub)
      end

      it "detects GitLab from remote URL" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/user/repo.git").not_nil!
        platform = CiPlatform.detect(url)
        platform.should eq(CiPlatform::GitLab)
      end

      it "detects Azure from dev.azure.com" do
        url = Git::GitRemoteUrl.parse("https://dev.azure.com/org/proj/_git/repo").not_nil!
        platform = CiPlatform.detect(url)
        platform.should eq(CiPlatform::Azure)
      end

      it "detects Gitea from gitea host" do
        url = Git::GitRemoteUrl.parse("https://gitea.example.com/user/repo.git").not_nil!
        platform = CiPlatform.detect(url)
        platform.should eq(CiPlatform::Gitea)
      end

      it "defaults to Unknown for unrecognized hosts" do
        url = Git::GitRemoteUrl.parse("https://bitbucket.org/user/repo.git").not_nil!
        platform = CiPlatform.detect(url)
        platform.should eq(CiPlatform::Unknown)
      end
    end

    describe "CiStatus" do
      it "has variants for each state" do
        CiStatus::Success.should be_a(CiStatus)
        CiStatus::Failure.should be_a(CiStatus)
        CiStatus::Pending.should be_a(CiStatus)
        CiStatus::Unknown.should be_a(CiStatus)
      end

      it "returns ANSI symbol for each state" do
        CiStatus::Success.symbol.should contain("✓")
        CiStatus::Failure.symbol.should contain("✗")
        CiStatus::Pending.symbol.should contain("○")
      end

      it "pending and unknown are not terminal states" do
        CiStatus::Success.terminal?.should be_true
        CiStatus::Failure.terminal?.should be_true
        CiStatus::Pending.terminal?.should be_false
        CiStatus::Unknown.terminal?.should be_false
      end
    end

    describe "fetch_ci_status" do
      it "returns nil for unknown platform" do
        CiStatus.fetch_ci_status("main", CiPlatform::Unknown).should be_nil
      end
    end
  end
end
