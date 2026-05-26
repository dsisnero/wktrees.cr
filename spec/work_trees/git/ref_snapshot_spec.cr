require "../../spec_helper"

module WorkTrees
  describe Git::RefSnapshot do
    describe ".build" do
      it "indexes locals by short and qualified names" do
        locals = [
          Git::LocalBranch.new("main", "sha-main", 1718273930, nil),
          Git::LocalBranch.new("feature", "sha-feat", 1718273932, "origin/feature"),
        ]
        remotes = [] of Git::RemoteBranch
        snap = Git::RefSnapshot.build(locals, remotes, {} of {String, String} => {Int32, Int32})

        snap.resolve("main").should eq("sha-main")
        snap.resolve("refs/heads/main").should eq("sha-main")
        snap.resolve("feature").should eq("sha-feat")
        snap.resolve("refs/heads/feature").should eq("sha-feat")
        snap.resolve("HEAD").should be_nil
      end

      it "indexes remotes by short and qualified names" do
        locals = [] of Git::LocalBranch
        remotes = [
          Git::RemoteBranch.new("origin/main", "sha-remote", 1718273930, "origin", "main"),
        ]
        snap = Git::RefSnapshot.build(locals, remotes, {} of {String, String} => {Int32, Int32})

        snap.resolve("origin/main").should eq("sha-remote")
        snap.resolve("refs/remotes/origin/main").should eq("sha-remote")
        snap.resolve("refs/heads/main").should be_nil
      end

      it "provides local_branches and local_branch lookup" do
        locals = [
          Git::LocalBranch.new("main", "sha-m", 1718273930, nil),
          Git::LocalBranch.new("feat", "sha-f", 1718273932, nil),
        ]
        snap = Git::RefSnapshot.build(locals, [] of Git::RemoteBranch, {} of {String, String} => {Int32, Int32})

        snap.local_branches.size.should eq(2)
        snap.local_branch("main").try(&.name).should eq("main")
        snap.local_branch("feat").try(&.name).should eq("feat")
        snap.local_branch("nope").should be_nil
      end

      it "provides remote_branches" do
        remotes = [
          Git::RemoteBranch.new("origin/main", "sha-r", 1718273930, "origin", "main"),
        ]
        snap = Git::RefSnapshot.build([] of Git::LocalBranch, remotes, {} of {String, String} => {Int32, Int32})

        snap.remote_branches.size.should eq(1)
        snap.remote_branches[0].short_name.should eq("origin/main")
      end

      it "error_on_missing_ref raises" do
        snap = Git::RefSnapshot.build([] of Git::LocalBranch, [] of Git::RemoteBranch, {} of {String, String} => {Int32, Int32})
        expect_raises(KeyError) { snap.must_resolve("does-not-exist") }
      end

      it "stores ahead_behind cache" do
        snap = Git::RefSnapshot.build(
          [] of Git::LocalBranch, [] of Git::RemoteBranch,
          { {"main", "refs/heads/feature"} => {3, 0} }
        )
        snap.ahead_behind("main", "refs/heads/feature").should eq({3, 0})
        snap.ahead_behind("main", "refs/heads/absent").should be_nil
      end

      it "upstream_of reads from local branch upstream" do
        locals = [
          Git::LocalBranch.new("feat", "sha-f", 1718273932, "origin/main"),
        ]
        snap = Git::RefSnapshot.build(locals, [] of Git::RemoteBranch, {} of {String, String} => {Int32, Int32})
        snap.upstream_of("feat").should eq("origin/main")
        snap.upstream_of("nonexistent").should be_nil
      end
    end
  end
end
