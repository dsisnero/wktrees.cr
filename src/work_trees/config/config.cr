# Configuration loading for worktrees.
# Ported from vendor/worktrunk/src/config/

require "toml"

module WorkTrees
  module Config
    # User-level configuration (~/.config/worktrees/config.toml).
    class UserConfig
      property worktree_path_template : String
      property llm_command : String?
      property llm_template : String?
      property llm_template_append : String?

      DEFAULT_PATH_TEMPLATE = "~/worktrees/{{ branch | sanitize }}"

      def initialize(
        @worktree_path_template : String = DEFAULT_PATH_TEMPLATE,
        @llm_command : String? = nil,
      )
      end
    end

    # Project-level configuration (.config/wt.toml in repo root).
    # Overrides user defaults for worktree path template.
    class ProjectConfig
      property worktree_path_template : String?
      property llm_command : String?
      property llm_template_append : String?
      property hooks : Hash(String, Hash(String, String))

      def initialize(
        @worktree_path_template : String? = nil,
        @llm_command : String? = nil,
        @hooks = {} of String => Hash(String, String),
      )
      end
    end

    # Merge project config into user config (project takes precedence).
    def self.merge(user : UserConfig, project : ProjectConfig?) : UserConfig
      return user unless project

      merged = UserConfig.new
      merged.worktree_path_template = project.worktree_path_template || user.worktree_path_template
      merged.llm_command = project.llm_command || user.llm_command
      merged.llm_template = user.llm_template
      merged.llm_template_append = user.llm_template_append
      merged
    end

    # Load user config from disk, falling back to defaults.
    def self.load_user(path : String) : UserConfig
      if File.exists?(path)
        content = File.read(path)
        parse_user(content)
      else
        UserConfig.new
      end
    rescue ex : TOML::ParseException
      UserConfig.new
    end

    # Parse user config from a TOML string.
    def self.parse_user(toml_str : String) : UserConfig
      data = TOML.parse(toml_str)
      config = UserConfig.new

      if path = data["worktree-path"]?.try(&.raw.to_s)
        config.worktree_path_template = path
      end

      # Parse nested [commit.generation] section
      if commit = data["commit"]?.try(&.raw)
        if commit.is_a?(Hash)
          gen = commit["generation"]?
          if gen && gen.raw.is_a?(Hash)
            raw_gen = gen.raw.as(Hash)
            cmd = raw_gen["command"]?
            config.llm_command = cmd.try(&.raw.to_s) if cmd
            tpl = raw_gen["template"]?
            config.llm_template = tpl.try(&.raw.to_s) if tpl
            append = raw_gen["template-append"]?
            config.llm_template_append = append.try(&.raw.to_s) if append
          end
        end
      end

      config
    end

    # Default config file path.
    def self.default_config_path : String
      home = ENV["HOME"]? || ENV["USERPROFILE"]? || ""
      File.join(home, ".config", "worktrees", "config.toml")
    end

    # Load user config from the default location, with env overrides.
    def self.load_default : UserConfig
      config = load_user(default_config_path)
      apply_env_overrides(config)
    end

    # Project config path relative to repo root.
    def self.project_config_path(repo_root : String) : String
      File.join(repo_root, ".config", "wt.toml")
    end

    # Load project config from .config/wt.toml
    def self.load_project(repo_root : String) : ProjectConfig?
      path = project_config_path(repo_root)
      return nil unless File.exists?(path)
      parse_project(File.read(path))
    rescue TOML::ParseException
      nil
    end

    # Parse project config TOML.
    def self.parse_project(toml_str : String) : ProjectConfig
      data = TOML.parse(toml_str)
      config = ProjectConfig.new

      if path = data["worktree-path"]?.try(&.raw.to_s)
        config.worktree_path_template = path
      end

      # Parse [commit.generation] section
      if commit = data["commit"]?.try(&.raw)
        if commit.is_a?(Hash)
          gen = commit["generation"]?
          if gen && gen.raw.is_a?(Hash)
            raw_gen = gen.raw.as(Hash)
            cmd = raw_gen["command"]?
            config.llm_command = cmd.try(&.raw.to_s) if cmd
            append = raw_gen["template-append"]?
            config.llm_template_append = append.try(&.raw.to_s) if append
          end
        end
      end

      # Parse hook sections
      HOOK_SECTIONS.each do |section|
        groups = parse_hooks(toml_str, section)
        flat_hooks = groups.flat_map(&.hooks)
        unless flat_hooks.empty?
          config.hooks[section] = flat_hooks.map { |hook| {hook.name, hook.command} }.to_h
        end
      end

      config
    end

    # All hook section names in config.
    HOOK_SECTIONS = %w[
      pre-start post-start
      pre-switch post-switch
      pre-commit post-commit
      pre-merge post-merge
      pre-remove post-remove
    ]

    # -- Env var overrides ------------------------------------------------------
    #
    # WORKTRUNK_* env vars override config values at load time.
    #   WARNING_KEY → top-level key
    #   SECTION__NESTED → section.nested key
    #   _LIST__FULL → list.full key

    EXCLUDED_ENV_VARS = %w[
      WORKTRUNK_CONFIG_PATH
      WORKTRUNK_SYSTEM_CONFIG_PATH
      WORKTRUNK_APPROVALS_PATH
      WORKTRUNK_PROJECT_CONFIG_PATH
      WORKTRUNK_DIRECTIVE_CD_FILE
      WORKTRUNK_DIRECTIVE_EXEC_FILE
      WORKTRUNK_DIRECTIVE_FILE
      WORKTRUNK_SHELL
      WORKTRUNK_NO_HOOKS
      WORKTRUNK_BIN
      WORKTRUNK_MAX_CONCURRENT_COMMANDS
    ]

    CONFIG_ENV_MAP = {
      "WORKTREE_PATH"                       => ["worktree-path"],
      "COMMIT__GENERATION__COMMAND"         => ["commit", "generation", "command"],
      "COMMIT__GENERATION__TEMPLATE"        => ["commit", "generation", "template"],
      "COMMIT__GENERATION__TEMPLATE_APPEND" => ["commit", "generation", "template-append"],
      "_LIST__FULL"                         => ["list", "full"],
      "_LIST__BRANCHES"                     => ["list", "branches"],
      "_LIST__REMOTES"                      => ["list", "remotes"],
      "_LIST__TIMEOUT_MS"                   => ["list", "timeout-ms"],
    }

    def self.collect_env_overrides : Hash(String, String)
      overrides = {} of String => String
      ENV.each do |key, value|
        next unless key.starts_with?("WORKTRUNK_")
        next if EXCLUDED_ENV_VARS.includes?(key)
        next unless key.size > 10
        stripped = key[10..]
        config_key = CONFIG_ENV_MAP[stripped]?
        next unless config_key
        next if value.empty?
        overrides[config_key.join('.')] = value
      end
      overrides
    end

    def self.apply_env_overrides(config : UserConfig) : UserConfig
      overrides = collect_env_overrides
      return config if overrides.empty?
      config.worktree_path_template = overrides["worktree-path"] if overrides["worktree-path"]?
      config.llm_command = overrides["commit.generation.command"] if overrides["commit.generation.command"]?
      config.llm_template = overrides["commit.generation.template"] if overrides["commit.generation.template"]?
      config.llm_template_append = overrides["commit.generation.template-append"] if overrides["commit.generation.template-append"]?
      config
    end

    # Load merged config (user + project).
    def self.load_merged(repo_root : String) : UserConfig
      user = load_default
      project = load_project(repo_root)
      merged = merge(user, project)
      apply_env_overrides(merged)
    end

    # Parse aliases from config TOML.
    # [aliases]
    # build = "step for-each 'cargo build'"
    def self.parse_aliases(toml_str : String) : Hash(String, String)
      data = TOML.parse(toml_str)
      aliases = {} of String => String
      section = data["aliases"]?
      return aliases unless section

      raw = section.raw
      if raw.is_a?(Hash)
        raw.each do |key, value|
          aliases[key.to_s] = value.raw.to_s
        end
      end
      aliases
    end
  end
end
