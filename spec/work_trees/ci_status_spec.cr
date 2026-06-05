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

      # Upstream parity: test_ci_status_color + test_pr_status_indicator
      # Colors map: Passed→Green, Running→Pending(Blue), Failed→Red,
      # Conflicts→Yellow, NoCI→BrightBlack, Error→Yellow
      it "each variant has a non-empty symbol" do
        CiStatus::Success.symbol.should_not be_empty
        CiStatus::Failure.symbol.should_not be_empty
        CiStatus::Pending.symbol.should_not be_empty
        CiStatus::Unknown.symbol.should_not be_empty
      end

      it "Success and Failure are the only terminal states" do
        CiStatus.values.each do |variant|
          terminal = CiStatus::Success == variant || CiStatus::Failure == variant
          variant.terminal?.should eq(terminal)
        end
      end
    end

    describe "fetch_ci_status" do
      it "returns nil for unknown platform" do
        CiStatus.fetch_ci_status("main", CiPlatform::Unknown).should be_nil
      end
    end

    describe "platform_from_url" do
      it "detects GitHub from https URL" do
        CiPlatform.platform_from_url("https://github.com/owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitHub from git@ URL" do
        CiPlatform.platform_from_url("git@github.com:owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitHub from ssh URL" do
        CiPlatform.platform_from_url("ssh://git@github.com/owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitHub Enterprise" do
        CiPlatform.platform_from_url("https://github.mycompany.com/owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitHub from http:// URL" do
        CiPlatform.platform_from_url("http://github.com/owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitHub from git:// URL" do
        CiPlatform.platform_from_url("git://github.com/owner/repo.git").should eq(CiPlatform::GitHub)
      end

      it "detects GitLab from https" do
        CiPlatform.platform_from_url("https://gitlab.com/owner/repo.git").should eq(CiPlatform::GitLab)
      end

      it "detects GitLab from git@ URL" do
        CiPlatform.platform_from_url("git@gitlab.com:owner/repo.git").should eq(CiPlatform::GitLab)
      end

      it "detects GitLab self-hosted" do
        CiPlatform.platform_from_url("https://gitlab.example.com/owner/repo.git").should eq(CiPlatform::GitLab)
      end

      it "detects Gitea from https" do
        CiPlatform.platform_from_url("https://gitea.com/owner/repo.git").should eq(CiPlatform::Gitea)
      end

      it "detects Gitea from git@ URL" do
        CiPlatform.platform_from_url("git@gitea.example.com:owner/repo.git").should eq(CiPlatform::Gitea)
      end

      it "detects Azure DevOps from https" do
        CiPlatform.platform_from_url("https://dev.azure.com/myorg/myproject/_git/myrepo").should eq(CiPlatform::Azure)
      end

      it "detects Azure DevOps from ssh URL" do
        CiPlatform.platform_from_url("git@ssh.dev.azure.com:v3/myorg/myproject/myrepo").should eq(CiPlatform::Azure)
      end

      it "detects Azure DevOps from visualstudio.com" do
        CiPlatform.platform_from_url("https://myorg.visualstudio.com/myproject/_git/myrepo").should eq(CiPlatform::Azure)
      end

      it "returns nil for unknown forges" do
        CiPlatform.platform_from_url("https://bitbucket.org/owner/repo.git").should be_nil
        CiPlatform.platform_from_url("https://codeberg.org/owner/repo.git").should be_nil
      end

      it "parses platform strings from config" do
        CiPlatform.parse("github").should eq(CiPlatform::GitHub)
        CiPlatform.parse("gitlab").should eq(CiPlatform::GitLab)
        CiPlatform.parse("gitea").should eq(CiPlatform::Gitea)
        CiPlatform.parse("azure-devops").should eq(CiPlatform::Azure)
      end

      it "returns nil for invalid platform strings" do
        CiPlatform.parse("invalid").should be_nil
        CiPlatform.parse("GITHUB").should be_nil
      end
    end
  end
end
