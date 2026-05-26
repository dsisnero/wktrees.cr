require "../../spec_helper"
require "../../../src/work_trees/config/deprecation"

module WorkTrees
  describe Config::Deprecation do
    describe "DEPRECATED_VARS" do
      it "maps repo_root to repo_path" do
        Config::Deprecation::DEPRECATED_VARS.should contain({"repo_root", "repo_path"})
      end

      it "maps worktree to worktree_path" do
        Config::Deprecation::DEPRECATED_VARS.should contain({"worktree", "worktree_path"})
      end

      it "maps main_worktree to repo" do
        Config::Deprecation::DEPRECATED_VARS.should contain({"main_worktree", "repo"})
      end

      it "maps main_worktree_path to primary_worktree_path" do
        Config::Deprecation::DEPRECATED_VARS.should contain({"main_worktree_path", "primary_worktree_path"})
      end
    end

    describe "normalize_template_vars" do
      it "returns unchanged for clean templates" do
        result = Config::Deprecation.normalize_template_vars("{{ repo_path }}/{{ branch }}")
        result.should eq("{{ repo_path }}/{{ branch }}")
      end

      it "replaces repo_root with repo_path" do
        result = Config::Deprecation.normalize_template_vars("cd {{ repo_root }} && npm install")
        result.should eq("cd {{ repo_path }} && npm install")
      end

      it "replaces worktree with worktree_path" do
        result = Config::Deprecation.normalize_template_vars("echo {{ worktree }}")
        result.should eq("echo {{ worktree_path }}")
      end

      it "replaces main_worktree with repo" do
        result = Config::Deprecation.normalize_template_vars("{{ main_worktree }}/target")
        result.should eq("{{ repo }}/target")
      end

      it "replaces main_worktree_path with primary_worktree_path" do
        result = Config::Deprecation.normalize_template_vars("cp -r {{ main_worktree_path }} {{ worktree_path }}")
        result.should eq("cp -r {{ primary_worktree_path }} {{ worktree_path }}")
      end

      it "handles multiple replacements in one string" do
        result = Config::Deprecation.normalize_template_vars("cd {{ repo_root }} && echo {{ worktree }} && ls {{ main_worktree }}")
        result.should eq("cd {{ repo_path }} && echo {{ worktree_path }} && ls {{ repo }}")
      end
    end

    describe "DEPRECATED_SECTION_KEYS" do
      it "includes commit-generation → commit.generation" do
        keys = Config::Deprecation::DEPRECATED_SECTION_KEYS
        commit_gen = keys.find { |ds| ds[:key] == "commit-generation" }
        commit_gen.should_not be_nil
        commit_gen.not_nil![:canonical_display].should eq("[commit.generation]")
      end

      it "includes select → switch.picker" do
        keys = Config::Deprecation::DEPRECATED_SECTION_KEYS
        keys.any? { |ds| ds[:key] == "select" }.should be_true
      end

      it "includes ci → forge" do
        keys = Config::Deprecation::DEPRECATED_SECTION_KEYS
        ci_entry = keys.find { |ds| ds[:key] == "ci" }
        ci_entry.should_not be_nil
        ci_entry.not_nil![:canonical_display].should eq("[forge]")
      end
    end

    describe "detect_deprecations" do
      it "detects deprecated template vars in content" do
        content = <<-TOML
        [pre-start]
        server = "cd {{ repo_root }} && npm start"
        TOML
        deps = Config::Deprecation.detect_deprecations(content)
        deps.has_any?.should be_true
        deps.replaced_vars.size.should be >= 1
      end

      it "returns no deprecations for clean content" do
        content = <<-TOML
        [pre-start]
        server = "cd {{ repo_path }} && npm start"
        TOML
        deps = Config::Deprecation.detect_deprecations(content)
        deps.has_any?.should be_false
      end

      it "detects deprecated commit-generation section" do
        content = <<-TOML
        [commit-generation]
        command = "llm"
        TOML
        deps = Config::Deprecation.detect_deprecations(content)
        deps.has_any?.should be_true
        deps.deprecated_sections.size.should eq(1)
        deps.deprecated_sections[0].should eq("commit-generation")
      end

      it "detects deprecated ci section" do
        content = <<-TOML
        [ci]
        platform = "github"
        TOML
        deps = Config::Deprecation.detect_deprecations(content)
        deps.has_any?.should be_true
      end

      it "detects legacy approved-commands format" do
        content = <<-TOML
        [[approved-commands]]
        project = "github.com/user/repo"
        command = "npm install"
        TOML
        deps = Config::Deprecation.detect_deprecations(content)
        deps.has_any?.should be_true
        deps.legacy_approved_commands?.should be_true
      end
    end

    describe "migrate_content" do
      it "renames [commit-generation] to [commit.generation]" do
        content = <<-TOML
        [commit-generation]
        command = "llm -m haiku"
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("[commit.generation]")
        migrated.should_not contain("[commit-generation]")
        migrated.should contain("command = \"llm -m haiku\"")
      end

      it "renames [ci] to [forge]" do
        content = <<-TOML
        [ci]
        platform = "github"
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("[forge]")
        migrated.should_not contain("[ci]")
        migrated.should contain("platform = \"github\"")
      end

      it "inverts no-ff to ff in [merge]" do
        content = <<-TOML
        [merge]
        no-ff = true
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("ff = false")
        migrated.should_not contain("no-ff")
      end

      it "inverts no-ff = false to ff = true" do
        content = <<-TOML
        [merge]
        no-ff = false
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("ff = true")
        migrated.should_not contain("no-ff")
      end

      it "renames [select] to [switch.picker]" do
        content = <<-TOML
        [select]
        pager = "less"
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("[switch.picker]")
        migrated.should_not contain("[select]")
      end

      it "returns content unchanged when no migrations apply" do
        content = <<-TOML
        [commit.generation]
        command = "llm"
        [forge]
        platform = "github"
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("[commit.generation]")
        migrated.should contain("[forge]")
      end

      it "migrates multiple patterns in one pass" do
        content = <<-TOML
        [commit-generation]
        command = "llm"

        [merge]
        no-ff = true

        [ci]
        platform = "github"
        TOML
        migrated = Config::Deprecation.migrate_content(content)
        migrated.should contain("[commit.generation]")
        migrated.should contain("ff = false")
        migrated.should contain("[forge]")
        migrated.should_not contain("[commit-generation]")
        migrated.should_not contain("no-ff")
        migrated.should_not contain("[ci]")
      end
    end

    describe "check_and_migrate" do
      it "detects deprecations and returns migrated content" do
        content = <<-TOML
        [commit-generation]
        command = "llm -m haiku"
        TOML
        result = Config::Deprecation.check_and_migrate(content, user_config: true)
        result.has_deprecations?.should be_true
        result.migrated_content.should contain("[commit.generation]")
        result.migrated_content.should_not contain("[commit-generation]")
      end

      it "returns empty migrations for clean content" do
        content = <<-TOML
        [commit.generation]
        command = "llm"
        TOML
        result = Config::Deprecation.check_and_migrate(content, user_config: true)
        result.has_deprecations?.should be_false
      end

      it "includes all deprecation details" do
        content = <<-TOML
        [commit-generation]
        command = "llm -m haiku"

        [merge]
        no-ff = true
        TOML
        result = Config::Deprecation.check_and_migrate(content, user_config: true)
        result.has_deprecations?.should be_true
      end
    end

    describe "compute_migrated_content" do
      it "applies structural migrations" do
        content = <<-TOML
        [commit-generation]
        command = "llm"
        TOML
        migrated = Config::Deprecation.compute_migrated_content(content)
        migrated.should contain("[commit.generation]")
        migrated.should_not contain("[commit-generation]")
      end

      it "replaces deprecated template variables" do
        content = <<-TOML
        [pre-start]
        server = "cd {{ repo_root }} && npm start"
        TOML
        migrated = Config::Deprecation.compute_migrated_content(content)
        migrated.should contain("{{ repo_path }}")
        migrated.should_not contain("{{ repo_root }}")
      end
    end
  end
end
