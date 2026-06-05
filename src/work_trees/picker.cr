# Interactive picker — Crystal port of vendor/worktrunk/src/commands/picker/
#
# Uses bubbletea + bubbles for a fully integrated TUI picker
# instead of shelling out to an external fzf/skim binary.
#
# Architecture: Elm model (Tea::Model) with Bubbles::List for item selection
# and Bubbles::Viewport for preview rendering.

require "bubbles"
require "lipgloss"
require "openssl"
require "./git/worktree_info"

module WorkTrees
  module Picker
    # Preview mode constants matching vendor numbering.
    enum PreviewMode
      WorkingTree  = 1
      Log          = 2
      BranchDiff   = 3
      UpstreamDiff = 4
      Summary      = 5
    end

    # A pickable worktree item implementing Bubbles::List::DefaultItem.
    struct PickerItem
      include Bubbles::List::DefaultItem

      getter branch : String
      getter worktree_path : String
      getter head_sha : String
      getter status_symbols : String
      getter? is_current : Bool

      def initialize(
        @branch : String,
        @worktree_path : String = "",
        @head_sha : String = "",
        @is_current : Bool = false,
        @status_symbols : String = "",
      )
      end

      def filter_value : String
        "#{@branch} #{@worktree_path}"
      end

      def title : String
        @branch
      end

      def description : String
        parts = [] of String
        parts << "@" if @is_current
        parts << @worktree_path unless @worktree_path.empty?
        parts << @status_symbols unless @status_symbols.empty?
        parts.join(" ")
      end
    end

    # Convert WorktreeInfo objects to PickerItems.
    # Marks the item matching `current_branch` with is_current=true.
    def self.build_items(worktrees : Array(Git::WorktreeInfo), current_branch : String? = nil) : Array(PickerItem)
      worktrees.map do |worktree|
        branch = worktree.branch || "(detached)"
        PickerItem.new(
          branch: branch,
          worktree_path: worktree.path,
          head_sha: worktree.head,
          is_current: branch == current_branch,
        )
      end
    end

    # Message sent when a preview computation completes.
    record PreviewLoadedMsg, content : String do
      include Tea::Msg
    end

    # Elm model for the interactive picker TUI.
    class Model
      include Tea::Model

      getter list : Bubbles::List::Model
      getter viewport : Bubbles::Viewport::Model
      property preview_mode : PreviewMode
      getter items : Array(PickerItem)
      getter? quitting : Bool
      property last_selected_idx : Int32?
      property selected_branch : String?
      property? create_requested : Bool
      property? remove_requested : Bool
      property cache_dir : String?

      def initialize(
        @items : Array(PickerItem),
        terminal_width : Int32,
        terminal_height : Int32,
        @cache_dir : String? = nil,
      )
        @preview_mode = PreviewMode::WorkingTree
        @quitting = false
        @last_selected_idx = nil
        @selected_branch = nil
        @create_requested = false
        @remove_requested = false

        # Build list component
        delegate = Bubbles::List.new_default_delegate
        delegate.styles = Bubbles::List.new_default_item_styles(is_dark: true)
        list_items = @items.map(&.as(Bubbles::List::Item))
        @list = Bubbles::List::Model.new(
          list_items, delegate, terminal_width // 2, terminal_height - 3,
        )
        @list.show_status_bar = true

        # Build viewport for preview
        @viewport = Bubbles::Viewport::Model.new(
          Bubbles::Viewport.with_width(terminal_width // 2),
          Bubbles::Viewport.with_height(terminal_height - 3),
        )
        @viewport.soft_wrap = true
      end

      # Handle alt-modified key presses (alt-c create, alt-r remove).
      private def handle_alt_key(msg : Tea::KeyPressMsg) : {Tea::Model, Tea::Cmd?}
        if (msg.mod & Tea::ModAlt) != 0
          case msg.string
          when "c"
            @selected_branch = @items[@list.index]?.try(&.branch) || "new-branch"
            @create_requested = true
            {self, Tea.quit}
          when "r"
            if item = @items[@list.index]?
              @selected_branch = item.branch
              @remove_requested = true
              {self, Tea.quit}
            else
              {self, nil}
            end
          else
            list_model, cmd = @list.update(msg)
            @list = list_model
            {self, cmd}
          end
        else
          list_model, cmd = @list.update(msg)
          @list = list_model
          {self, cmd}
        end
      end

      def item_count : Int32
        @items.size
      end

      def init : Tea::Cmd?
        nil
      end

      def update(msg : Tea::Msg) : {Tea::Model, Tea::Cmd?}
        case msg
        when PreviewLoadedMsg
          @viewport.set_content(msg.content)
          {self, nil}
        when Tea::KeyPressMsg
          case msg.to_s
          when "q", "ctrl+c"
            @quitting = true
            {self, Tea.quit}
          when "enter"
            if item = @items[@list.index]?
              @selected_branch = item.branch
            end
            @quitting = true
            {self, Tea.quit}
          when "1" then switch_preview_mode(PreviewMode::WorkingTree)
          when "2" then switch_preview_mode(PreviewMode::Log)
          when "3" then switch_preview_mode(PreviewMode::BranchDiff)
          when "4" then switch_preview_mode(PreviewMode::UpstreamDiff)
          when "5" then switch_preview_mode(PreviewMode::Summary)
          else
            # Check for alt-modified keys
            handle_alt_key(msg)
          end
        else
          list_model, cmd = @list.update(msg)
          @list = list_model
          {self, cmd}
        end
      end

      def view : Tea::View
        left = @list.view
        right = @viewport.view
        content = Lipgloss.join_horizontal(
          Lipgloss::Position::Top,
          left, right,
        )
        Tea::View.new(content)
      end

      private def switch_preview_mode(mode : PreviewMode) : {Tea::Model, Tea::Cmd?}
        @preview_mode = mode
        # Reload preview for the selected item in the new mode
        if item = @items[@list.index]?
          {self, load_preview(item)}
        else
          {self, nil}
        end
      end

      # Build a command that runs the preview computation in a background
      # fiber and sends a PreviewLoadedMsg when complete.
      # Uses PreviewCache on disk when cache_dir is set.
      private def load_preview(item : PickerItem) : Proc(Tea::Msg?)
        mode = @preview_mode
        dir = @cache_dir
        -> : Tea::Msg? {
          if dir
            cache_key = PreviewCache.make_key(item.branch, mode, item.head_sha)
            if cached = PreviewCache.read(cache_key, dir)
              return PreviewLoadedMsg.new(cached)
            end
          end
          content = Picker.run_preview(item, mode)
          if dir
            cache_key = PreviewCache.make_key(item.branch, mode, item.head_sha)
            PreviewCache.write(cache_key, content, dir)
          end
          PreviewLoadedMsg.new(content)
        }
      end
    end

    # Result of the picker selection.
    record PickerResult, branch : String?, create : Bool, remove : Bool

    # Launch the interactive picker TUI and return the selected branch name,
    # or nil if the user cancelled (q/ctrl-c).
    #
    # When STDOUT is a TTY, uses bubbletea with alt-screen for the full TUI.
    # Falls back to first worktree when STDOUT is piped.
    def self.handle_picker(worktrees : Array(Git::WorktreeInfo), current_branch : String? = nil) : PickerResult
      return PickerResult.new(nil, create: false, remove: false) if worktrees.empty?

      if STDOUT.tty?
        run_tui_picker(worktrees, current_branch)
      else
        branch = run_fzf_picker(worktrees)
        PickerResult.new(branch, create: false, remove: false)
      end
    end

    private def self.run_tui_picker(worktrees : Array(Git::WorktreeInfo), current_branch : String?) : PickerResult
      items = build_items(worktrees, current_branch)

      # Set up cache directory if we can detect a git repo
      cache_dir = begin
        repo = Git::Repository.current
        File.join(repo.git_common_dir, "cache", "picker-preview")
      rescue
        nil
      end

      model = Model.new(items, terminal_width: 80, terminal_height: 24, cache_dir: cache_dir)

      program = Tea.new_program(
        model,
        Tea.with_alt_screen,
        Tea.with_mouse_cell_motion,
      )

      begin
        result_model, err = program.run
      rescue ex
        return PickerResult.new(nil, create: false, remove: false)
      end
      return PickerResult.new(nil, create: false, remove: false) if err

      m = result_model
      return PickerResult.new(nil, create: false, remove: false) unless m.is_a?(Model)

      if m.remove_requested?
        PickerResult.new(m.selected_branch, create: false, remove: true)
      elsif m.create_requested?
        PickerResult.new(m.selected_branch, create: true, remove: false)
      elsif m.quitting?
        PickerResult.new(nil, create: false, remove: false)
      else
        branch = m.selected_branch
        branch ||= m.items[m.list.index]?.try(&.branch)
        PickerResult.new(branch, create: false, remove: false)
      end
    end

    # Fallback: return the first worktree when no TTY (no interactive picker).
    private def self.run_fzf_picker(worktrees : Array(Git::WorktreeInfo)) : String?
      # In non-TTY environments, just return the first worktree's branch
      worktrees.each do |worktree|
        return worktree.branch if worktree.branch
      end
      nil
    end

    # -- Preview computation ---------------------------------------------------

    # PreviewCache provides persistent on-disk caching of computed previews,
    # keyed by SHA-256(branch + mode + head_sha) so previews are never stale.
    module PreviewCache
      # Generate a deterministic cache key from branch, mode, and HEAD SHA.
      def self.make_key(branch : String, mode : PreviewMode, head_sha : String) : String
        input = "#{branch}:#{mode.to_i}:#{head_sha}"
        digest = OpenSSL::Digest.new("SHA256")
        digest.update(input)
        digest.final.hexstring
      end

      # Read a cached preview from disk. Returns nil on miss.
      def self.read(key : String, cache_dir : String) : String?
        path = File.join(cache_dir, key)
        File.read(path)
      rescue File::NotFoundError | IO::Error
        nil
      end

      # Write a preview to the disk cache.
      def self.write(key : String, content : String, cache_dir : String) : Nil
        Dir.mkdir_p(cache_dir) unless Dir.exists?(cache_dir)
        File.write(File.join(cache_dir, key), content)
      rescue IO::Error
        nil
      end
    end

    # Build git command string for working tree preview.
    def self.working_tree_preview_cmd : String
      "git diff HEAD --color=always --stat -- \"$(git rev-parse --show-toplevel)\""
    end

    # Build git command string for log preview.
    def self.log_preview_cmd(branch : String) : String
      "git log --graph --color=always --decorate --oneline -20 #{branch}"
    end

    def self.branch_diff_preview_cmd(default_branch : String, branch : String) : String
      "git diff --color=always --stat #{default_branch}...#{branch}"
    end

    def self.upstream_diff_preview_cmd(upstream : String, branch : String) : String
      "git diff --color=always --stat #{upstream}...#{branch}"
    end

    # Title line for a preview mode.
    def self.compute_preview_title(mode : PreviewMode, branch : String? = nil) : String
      b = branch || "HEAD"
      case mode
      in .working_tree?  then "Working Tree Changes (#{b})"
      in .log?           then "Recent Commits — #{b}"
      in .branch_diff?   then "Diff vs Default — #{b}"
      in .upstream_diff? then "Diff vs Upstream — #{b}"
      in .summary?       then "Branch Summary — #{b}"
      end
    end

    # Run the appropriate git command for the preview mode and return
    # the captured output (or a fallback message on failure).
    def self.run_preview(item : PickerItem, mode : PreviewMode) : String
      title = compute_preview_title(mode, branch: item.branch)
      output = begin
        case mode
        in .working_tree?
          Cmd.new("git").args(["diff", "HEAD", "--stat", "--color=always"]).run.stdout
        in .log?
          Cmd.new("git").args(["log", "--graph", "--color=always", "--decorate", "--oneline", "-20", item.branch]).run.stdout
        in .branch_diff?
          Cmd.new("git").args(["diff", "--color=always", "--stat", "main...#{item.branch}"]).run.stdout
        in .upstream_diff?
          Cmd.new("git").args(["diff", "--color=always", "--stat", "@{u}...#{item.branch}"]).run.stdout
        in .summary?
          "Run 'work_trees step summary' to generate an LLM summary."
        end
      rescue
        "Preview unavailable"
      end

      if output.strip.empty?
        "#{title}\n\n(no changes)"
      else
        "#{title}\n\n#{output}"
      end
    end
  end
end
