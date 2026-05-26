require "../../spec_helper"

module WorkTrees
  describe Git::ShaCache do
    describe "key generation" do
      it "generates symmetric keys" do
        key1 = Git::ShaCache.symmetric_key("abc123", "def456")
        key2 = Git::ShaCache.symmetric_key("def456", "abc123")
        key1.should eq(key2)
        key1.should contain("abc123")
        key1.should contain("def456")
      end

      it "generates asymmetric keys preserving order" do
        key1 = Git::ShaCache.symmetric_key("aaa", "bbb")
        key2 = Git::ShaCache.symmetric_key("bbb", "aaa")
        key1.should eq(key2)
        # symmetric key sorts: "aaa" < "bbb" → "aaa-bbb.json"
        key1.should eq("aaa-bbb.json")
      end
    end

    describe "kind constants" do
      it "defines all cache kinds" do
        Git::ShaCache::KIND_MERGE_TREE_CONFLICTS.should eq("merge-tree-conflicts")
        Git::ShaCache::KIND_MERGE_ADD_PROBE.should eq("merge-add-probe")
        Git::ShaCache::KIND_IS_ANCESTOR.should eq("is-ancestor")
        Git::ShaCache::KIND_HAS_ADDED_CHANGES.should eq("has-added-changes")
        Git::ShaCache::KIND_DIFF_STATS.should eq("diff-stats")
        Git::ShaCache::KIND_AHEAD_BEHIND.should eq("ahead-behind")
        Git::ShaCache::ALL_KINDS.size.should eq(6)
      end
    end

    describe "MAX_ENTRIES_PER_KIND" do
      it "is 5000" do
        Git::ShaCache::MAX_ENTRIES_PER_KIND.should eq(5000)
      end
    end
  end
end
