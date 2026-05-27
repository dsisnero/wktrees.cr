require "../../spec_helper"

module WorkTrees
  describe Config::ProjectForgeConfig do
    it "defaults platform and hostname to nil" do
      cfg = Config::ProjectForgeConfig.new
      cfg.platform.should be_nil
      cfg.hostname.should be_nil
    end

    it "parses platform from config" do
      cfg = Config::ProjectForgeConfig.new(platform: "github")
      cfg.platform.should eq("github")
    end

    it "parses hostname for self-hosted" do
      cfg = Config::ProjectForgeConfig.new(hostname: "gitlab.mycompany.com")
      cfg.hostname.should eq("gitlab.mycompany.com")
    end

    it "parses both platform and hostname" do
      cfg = Config::ProjectForgeConfig.new(platform: "gitlab", hostname: "gitlab.internal")
      cfg.platform.should eq("gitlab")
      cfg.hostname.should eq("gitlab.internal")
    end

    it "merges project over user" do
      user = Config::ProjectForgeConfig.new(platform: "github")
      project = Config::ProjectForgeConfig.new(platform: "gitlab", hostname: "gitlab.internal")
      merged = user.merge_with(project)
      merged.platform.should eq("gitlab")
      merged.hostname.should eq("gitlab.internal")
    end

    it "falls back to user when project has no values" do
      user = Config::ProjectForgeConfig.new(platform: "github", hostname: "github.internal")
      project = Config::ProjectForgeConfig.new
      merged = user.merge_with(project)
      merged.platform.should eq("github")
      merged.hostname.should eq("github.internal")
    end

    it "detects ci_platform from platform string" do
      cfg = Config::ProjectForgeConfig.new(platform: "github")
      cfg.ci_platform?.should eq(CiPlatform::GitHub)
    end

    it "returns nil for unsupported platform" do
      cfg = Config::ProjectForgeConfig.new(platform: "bitbucket")
      cfg.ci_platform?.should be_nil
    end
  end
end
