require "../../spec_helper"

module WorkTrees
  describe Git::GitRemoteUrl do
    describe ".parse" do
      it "parses HTTPS GitHub URL" do
        url = Git::GitRemoteUrl.parse("https://github.com/user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
        u.owner.should eq("user")
        u.repo.should eq("repo")
      end

      it "parses HTTPS URL without .git suffix" do
        url = Git::GitRemoteUrl.parse("https://github.com/user/repo")
        url.should_not be_nil
        u = url.not_nil!
        u.repo.should eq("repo")
      end

      it "parses git@ SSH URL" do
        url = Git::GitRemoteUrl.parse("git@github.com:user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
        u.owner.should eq("user")
        u.repo.should eq("repo")
      end

      it "parses ssh:// URL" do
        url = Git::GitRemoteUrl.parse("ssh://git@github.com/user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
        u.owner.should eq("user")
        u.repo.should eq("repo")
      end

      it "parses HTTP URL" do
        url = Git::GitRemoteUrl.parse("http://github.com/user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
      end

      it "parses git:// protocol" do
        url = Git::GitRemoteUrl.parse("git://github.com/user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
      end

      it "handles GitLab nested groups" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/group/subgroup/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("gitlab.com")
        u.owner.should eq("group/subgroup")
        u.repo.should eq("repo")
      end

      it "handles deeply nested groups" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/a/b/c/d/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.owner.should eq("a/b/c/d")
        u.repo.should eq("repo")
      end

      it "returns nil for malformed URLs" do
        Git::GitRemoteUrl.parse("not-a-url").should be_nil
        Git::GitRemoteUrl.parse("").should be_nil
        Git::GitRemoteUrl.parse("https://host-only.com").should be_nil
      end
    end

    describe "forge detection" do
      it "detects github.com" do
        url = Git::GitRemoteUrl.parse("https://github.com/user/repo.git").not_nil!
        url.github?.should be_true
        url.gitlab?.should be_false
      end

      it "detects gitlab.com" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/user/repo.git").not_nil!
        url.gitlab?.should be_true
        url.github?.should be_false
      end

      it "detects gitea instances" do
        url = Git::GitRemoteUrl.parse("https://gitea.com/user/repo.git").not_nil!
        url.gitea?.should be_true
      end

      it "azure? detects dev.azure.com" do
        url = Git::GitRemoteUrl.parse("https://dev.azure.com/org/proj/_git/repo").not_nil!
        url.azure?.should be_true
      end
    end

    describe "project_identifier" do
      it "builds host/path identifier" do
        url = Git::GitRemoteUrl.parse("https://github.com/owner/repo.git").not_nil!
        url.project_identifier.should eq("github.com/owner/repo")
      end

      it "includes nested groups for GitLab" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/group/sub/repo.git").not_nil!
        url.project_identifier.should eq("gitlab.com/group/sub/repo")
      end
    end

    describe "with_port" do
      it "parses SSH URL with port" do
        url = Git::GitRemoteUrl.parse("ssh://git@github.com:22/user/repo.git")
        url.should_not be_nil
        u = url.not_nil!
        u.host.should eq("github.com")
        u.owner.should eq("user")
        u.repo.should eq("repo")
      end
    end

    describe "parse_owner_repo" do
      it "extracts owner and repo from HTTPS URL" do
        result = Git::GitRemoteUrl.parse_owner_repo("https://github.com/owner/repo.git")
        result.should eq({"owner", "repo"})
      end

      it "strips trailing .git" do
        result = Git::GitRemoteUrl.parse_owner_repo("https://github.com/owner/repo")
        result.should eq({"owner", "repo"})
      end

      it "handles trailing whitespace" do
        result = Git::GitRemoteUrl.parse_owner_repo("  https://github.com/owner/repo.git\n")
        result.should eq({"owner", "repo"})
      end

      it "returns nil for malformed URL" do
        Git::GitRemoteUrl.parse_owner_repo("not-a-url").should be_nil
      end

      it "parses git@ without .git suffix" do
        result = Git::GitRemoteUrl.parse_owner_repo("git@github.com:owner/repo")
        result.should eq({"owner", "repo"})
      end

      it "parses ssh:// URL" do
        result = Git::GitRemoteUrl.parse_owner_repo("ssh://git@github.com/owner/repo.git")
        result.should eq({"owner", "repo"})
      end
    end

    describe "self-hosted GitLab" do
      it "handles nested groups on custom domain" do
        url = Git::GitRemoteUrl.parse("https://gitlab.mycompany.com/team/frontend/repo.git").not_nil!
        url.host.should eq("gitlab.mycompany.com")
        url.owner.should eq("team/frontend")
        url.repo.should eq("repo")
      end

      it "handles git@ self-hosted with deep nesting" do
        url = Git::GitRemoteUrl.parse("git@gitlab.internal:org/dept/project/repo.git").not_nil!
        url.owner.should eq("org/dept/project")
        url.repo.should eq("repo")
      end
    end

    # Upstream parity: adversarial URL tests
    describe "adversarial inputs" do
      it "preserves dot segments as literals (no path traversal)" do
        with_dot = Git::GitRemoteUrl.parse("https://gitlab.com/owner/./repo.git").not_nil!
        normal = Git::GitRemoteUrl.parse("https://gitlab.com/owner/repo.git").not_nil!
        with_dot.owner.should eq("owner/.")
        with_dot.repo.should eq("repo")
        with_dot.project_identifier.should_not eq(normal.project_identifier)
      end

      it "preserves double-dot as literal (no parent traversal)" do
        url = Git::GitRemoteUrl.parse("https://gitlab.com/owner/../repo.git").not_nil!
        url.owner.should eq("owner/..")
        url.repo.should eq("repo")
      end

      it "treats empty user in ssh URL correctly" do
        url = Git::GitRemoteUrl.parse("ssh://github.com/owner/repo.git").not_nil!
        url.host.should eq("github.com")
        url.owner.should eq("owner")
      end

      it "preserves @ in path for ssh URLs" do
        url = Git::GitRemoteUrl.parse("git@github.com:owner/repo@v1.git").not_nil!
        url.owner.should eq("owner")
        url.repo.should eq("repo@v1")
      end

      it "handles case-sensitive hostnames" do
        lower = Git::GitRemoteUrl.parse("https://github.com/owner/repo.git").not_nil!
        upper = Git::GitRemoteUrl.parse("https://GITHUB.COM/owner/repo.git").not_nil!
        # Host should preserve case but forge detection is case-insensitive
        lower.github?.should be_true
        upper.host.should eq("GITHUB.COM")
      end
    end

    # Upstream parity: parse_owner_repo with nested groups
    describe "parse_owner_repo nested" do
      it "extracts nested owner from GitLab-style HTTPS" do
        result = Git::GitRemoteUrl.parse_owner_repo("https://gitlab.com/group/subgroup/repo.git")
        result.should eq({"group/subgroup", "repo"})
      end

      it "extracts deeply nested owner" do
        result = Git::GitRemoteUrl.parse_owner_repo("https://gitlab.com/a/b/c/repo.git")
        result.should eq({"a/b/c", "repo"})
      end
    end
  end
end
