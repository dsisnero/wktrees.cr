# Configuration section structs.
#
# Ported from vendor/worktrunk/src/config/user/sections.rs
#
# These represent individual TOML configuration sections that can be set
# globally (user config) or per-project. Each supports merging where project
# values override user values.

module WorkTrees
  module Config
    # What to stage before committing.
    enum StageMode
      All     # Stage everything: untracked + unstaged tracked changes
      Tracked # Stage tracked changes only (like `git add -u`)
      None    # Stage nothing, commit only what's already in the index

      def self.default : StageMode
        All
      end
    end

    # Configuration for LLM commit message generation.
    struct CommitGenerationConfig
      property command : String?
      property template : String?
      property template_file : String?
      property squash_template : String?
      property squash_template_file : String?
      property template_append : String?

      def initialize(
        @command : String? = nil,
        @template : String? = nil,
        @template_file : String? = nil,
        @squash_template : String? = nil,
        @squash_template_file : String? = nil,
        @template_append : String? = nil,
      )
      end

      def configured? : Bool
        if cmd = @command
          !cmd.strip.empty?
        else
          false
        end
      end

      # Merge project config over user config. Project values take precedence.
      # Mutually exclusive pairs (template/template_file) are cleared
      # when project sets the other.
      def merge_with(other : CommitGenerationConfig) : CommitGenerationConfig
        tpl, tpl_file = if other.@template
                          {other.@template, nil}
                        elsif other.@template_file
                          {nil, other.@template_file}
                        else
                          {@template, @template_file}
                        end

        sq_tpl, sq_file = if other.@squash_template
                            {other.@squash_template, nil}
                          elsif other.@squash_template_file
                            {nil, other.@squash_template_file}
                          else
                            {@squash_template, @squash_template_file}
                          end

        CommitGenerationConfig.new(
          command: other.@command || @command,
          template: tpl,
          template_file: tpl_file,
          squash_template: sq_tpl,
          squash_template_file: sq_file,
          template_append: other.@template_append || @template_append,
        )
      end
    end

    # Configuration for the `wt step commit` command.
    struct CommitConfig
      property stage : StageMode
      property generation : CommitGenerationConfig?

      def initialize(
        @stage : StageMode = StageMode::All,
        @generation : CommitGenerationConfig? = nil,
      )
      end

      # Merge project over user.
      def merge_with(other : CommitConfig) : CommitConfig
        gen = if gen_user = @generation
                if gen_other = other.@generation
                  gen_user.merge_with(gen_other)
                else
                  gen_user
                end
              else
                other.@generation
              end

        new_stage = if other.@stage != StageMode::All
                      other.@stage
                    else
                      @stage
                    end

        CommitConfig.new(
          stage: new_stage,
          generation: gen,
        )
      end
    end

    # Configuration for the `wt merge` command.
    struct MergeConfig
      property? squash : Bool = true
      property? commit : Bool = true
      property? rebase : Bool = true
      property? remove : Bool = true
      property? verify : Bool = true
      property? push : Bool = true

      def initialize(
        @squash : Bool = true,
        @commit : Bool = true,
        @rebase : Bool = true,
        @remove : Bool = true,
        @verify : Bool = true,
        @push : Bool = true,
      )
      end

      # Merge project over user.
      def merge_with(other : MergeConfig) : MergeConfig
        MergeConfig.new(
          squash: other.squash?,
          commit: other.commit?,
          rebase: other.rebase?,
          remove: other.remove?,
          verify: other.verify?,
          push: other.push?,
        )
      end
    end

    # Configuration for the `wt list` command.
    struct ListConfig
      getter? full : Bool = false
      getter? branches : Bool = false
      getter? remotes : Bool = false
      getter? summary : Bool = false
      property task_timeout_ms : Int64?
      property timeout_ms : Int64?

      def initialize(
        @full : Bool = false,
        @branches : Bool = false,
        @remotes : Bool = false,
        @summary : Bool = false,
        @task_timeout_ms : Int64? = nil,
        @timeout_ms : Int64? = nil,
      )
      end

      # Merge project over user.
      def merge_with(other : ListConfig) : ListConfig
        ListConfig.new(
          full: other.full? || full?,
          branches: other.branches? || branches?,
          remotes: other.remotes? || remotes?,
          summary: other.summary? || summary?,
          task_timeout_ms: other.task_timeout_ms || task_timeout_ms,
          timeout_ms: other.timeout_ms || timeout_ms,
        )
      end
    end
  end
end
