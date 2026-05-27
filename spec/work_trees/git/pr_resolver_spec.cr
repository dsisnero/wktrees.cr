require "../../spec_helper"

module WorkTrees
  describe Git::PrResolver do
    describe "RemoteRefInfo" do
      it "builds from GitHub API response" do
        json = JSON.parse(<<-JSON)
        {
          "title": "Fix login bug",
          "user": {"login": "contributor"},
          "state": "open",
          "draft": false,
          "head": {
            "ref": "fix-login",
            "repo": {"owner": {"login": "contributor"}, "name": "work_trees"},
            "sha": "abc123"
          },
          "base": {
            "ref": "main",
            "repo": {"owner": {"login": "dsisnero"}, "name": "work_trees"},
            "sha": "def456"
          },
          "html_url": "https://github.com/dsisnero/work_trees/pull/42"
        }
        JSON
        info = Git::PrResolver.parse_github_pr_response(json, 42_u32)
        info.number.should eq(42)
        info.title.should eq("Fix login bug")
        info.author.should eq("contributor")
        info.source_branch.should eq("fix-login")
        info.base_branch.should eq("main")
        info.url.should eq("https://github.com/dsisnero/work_trees/pull/42")
        info.head_sha.should eq("abc123")
        info.base_sha.should eq("def456")
      end

      it "detects cross-repo PR" do
        json = JSON.parse(<<-JSON)
        {
          "title": "Feature from fork",
          "user": {"login": "outsider"},
          "state": "open",
          "draft": false,
          "head": {
            "ref": "cool-feature",
            "repo": {"owner": {"login": "outsider"}, "name": "work_trees"},
            "sha": "abc123"
          },
          "base": {
            "ref": "main",
            "repo": {"owner": {"login": "dsisnero"}, "name": "work_trees"},
            "sha": "def456"
          },
          "html_url": "https://github.com/dsisnero/work_trees/pull/99"
        }
        JSON
        info = Git::PrResolver.parse_github_pr_response(json, 99_u32)
        info.cross_repo?.should be_true
      end

      it "detects same-repo PR as not cross-repo" do
        json = JSON.parse(<<-JSON)
        {
          "title": "Internal refactor",
          "user": {"login": "dsisnero"},
          "state": "open",
          "draft": false,
          "head": {
            "ref": "refactor-x",
            "repo": {"owner": {"login": "dsisnero"}, "name": "work_trees"},
            "sha": "abc123"
          },
          "base": {
            "ref": "main",
            "repo": {"owner": {"login": "dsisnero"}, "name": "work_trees"},
            "sha": "def456"
          },
          "html_url": "https://github.com/dsisnero/work_trees/pull/55"
        }
        JSON
        info = Git::PrResolver.parse_github_pr_response(json, 55_u32)
        info.cross_repo?.should be_false
      end
    end

    describe "ref_path" do
      it "builds pull ref path" do
        Git::PrResolver.ref_path_for(:pr, 123_u32).should eq("pull/123/head")
      end

      it "builds merge request ref path" do
        Git::PrResolver.ref_path_for(:mr, 42_u32).should eq("merge-requests/42/head")
      end
    end

    describe "fork_refspec" do
      it "builds correct refspec for fork PR" do
        Git::PrResolver.fork_refspec(123_u32).should eq("+refs/pull/123/head:refs/remotes/pull/123/head")
      end
    end

    describe "tracking_ref" do
      it "builds full tracking ref for GitHub PR" do
        Git::PrResolver.tracking_ref(:pr, 123_u32).should eq("refs/pull/123/head")
      end

      it "builds full tracking ref for GitLab MR" do
        Git::PrResolver.tracking_ref(:mr, 42_u32).should eq("refs/merge-requests/42/head")
      end
    end

    describe "local_branch_name" do
      it "returns source branch name unchanged" do
        Git::PrResolver.local_branch_name("feature/fix").should eq("feature/fix")
      end
    end
  end
end
