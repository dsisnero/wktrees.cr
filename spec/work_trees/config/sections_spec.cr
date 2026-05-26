require "../../spec_helper"
require "../../../src/work_trees/config/sections"

module WorkTrees::Config
  describe StageMode do
    it "has three variants: All, Tracked, None" do
      StageMode::All.should be_a(StageMode)
      StageMode::Tracked.should be_a(StageMode)
      StageMode::None.should be_a(StageMode)
    end

    it "defaults to All" do
      StageMode.default.should eq(StageMode::All)
    end
  end

  describe CommitGenerationConfig do
    it "is not configured by default" do
      cfg = CommitGenerationConfig.new
      cfg.configured?.should be_false
    end

    it "is configured when command is set" do
      cfg = CommitGenerationConfig.new(command: "llm -m haiku")
      cfg.configured?.should be_true
    end

    it "is not configured when command is empty string" do
      cfg = CommitGenerationConfig.new(command: "")
      cfg.configured?.should be_false
    end

    it "is not configured when command is whitespace only" do
      cfg = CommitGenerationConfig.new(command: "   ")
      cfg.configured?.should be_false
    end

    it "holds template fields" do
      cfg = CommitGenerationConfig.new(
        command: "llm",
        template: "generate {{ branch }} commit",
      )
      cfg.command.should eq("llm")
      cfg.template.should eq("generate {{ branch }} commit")
      cfg.template_file.should be_nil
      cfg.squash_template.should be_nil
      cfg.template_append.should be_nil
    end

    it "merges with other config — project overrides command" do
      user = CommitGenerationConfig.new(command: "llm -m slow-model")
      project = CommitGenerationConfig.new(command: "llm -m fast-model")
      merged = user.merge_with(project)
      merged.command.should eq("llm -m fast-model")
    end

    it "merges — falls back to user when project has no command" do
      user = CommitGenerationConfig.new(command: "llm")
      project = CommitGenerationConfig.new
      merged = user.merge_with(project)
      merged.command.should eq("llm")
    end
  end

  describe CommitConfig do
    it "defaults stage to All" do
      cfg = CommitConfig.new
      cfg.stage.should eq(StageMode::All)
    end

    it "accepts explicit stage" do
      cfg = CommitConfig.new(stage: StageMode::Tracked)
      cfg.stage.should eq(StageMode::Tracked)
    end

    it "has no generation config by default" do
      cfg = CommitConfig.new
      cfg.generation.should be_nil
    end

    it "merges — project stage overrides user" do
      user = CommitConfig.new(stage: StageMode::All)
      project = CommitConfig.new(stage: StageMode::None)
      merged = user.merge_with(project)
      merged.stage.should eq(StageMode::None)
    end

    it "merges — falls back to user stage when project has none" do
      user = CommitConfig.new(stage: StageMode::Tracked)
      project = CommitConfig.new
      merged = user.merge_with(project)
      merged.stage.should eq(StageMode::Tracked)
    end
  end

  describe MergeConfig do
    it "defaults all values to true" do
      cfg = MergeConfig.new
      cfg.squash?.should be_true
      cfg.commit?.should be_true
      cfg.rebase?.should be_true
      cfg.remove?.should be_true
      cfg.verify?.should be_true
      cfg.push?.should be_true
    end

    it "can disable individual steps" do
      cfg = MergeConfig.new(squash: false, push: false)
      cfg.squash?.should be_false
      cfg.push?.should be_false
      cfg.commit?.should be_true # still default
    end

    it "merges — project overrides user" do
      user = MergeConfig.new(squash: true, rebase: true)
      project = MergeConfig.new(squash: false)
      merged = user.merge_with(project)
      merged.squash?.should be_false # project override
      merged.rebase?.should be_true  # inherited from user
    end
  end

  describe ListConfig do
    it "defaults full/branches/remotes to false" do
      cfg = ListConfig.new
      cfg.full?.should be_false
      cfg.branches?.should be_false
      cfg.remotes?.should be_false
      cfg.summary?.should be_false
    end

    it "can enable full mode" do
      cfg = ListConfig.new(full: true)
      cfg.full?.should be_true
    end

    it "merges — project overrides user" do
      user = ListConfig.new(full: false, branches: true)
      project = ListConfig.new(full: true)
      merged = user.merge_with(project)
      merged.full?.should be_true
      merged.branches?.should be_true
    end
  end
end
