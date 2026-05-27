# Interactive Picker — Crystal Port Plan

**Source of truth**: `vendor/worktrunk/src/commands/picker/` (9 files, ~4500 lines Rust)
**Crystal shards**: `dsisnero/bubbles`, `dsisnero/lipgloss`, `dsisnero/bubbletea`

## Vendor Architecture

The upstream Rust picker shells out to `skim` (a Rust fzf clone) as an external
process, piping worktree items via an unbounded channel. Items are formatted as
ANSI-colored lines; preview is computed on-demand and cached in both in-memory
(`DashMap`) and disk (SHA-keyed JSON).

### Vendor files and purpose

| File | Purpose |
|------|---------|
| `mod.rs` | Entry point (`handle_picker`), skim invocation with key bindings, alt-r removal collector |
| `items.rs` | `WorktreeSkimItem` — rendered display line, preview compute for 5 modes |
| `preview.rs` | `PreviewMode` enum (5 variants), `PreviewLayout` (Right/Down), temp-file state management |
| `preview_cache.rs` | Persistent SHA-keyed disk cache for log/branch-diff/upstream-diff |
| `preview_orchestrator.rs` | Background pre-compute on rayon pool (tier 1 = first item, tier 2 = rest) |
| `pager.rs` | Pager detection and execution (delta, bat, less) |
| `progressive_handler.rs` | Bridge between `collect::collect()` and skim item stream |
| `summary.rs` | LLM summary generation and caching |
| `log_formatter.rs` | Git log output formatting with dimming and diffstats |

### Vendor key bindings

| Key | Action |
|-----|--------|
| `1`-`5` | Switch preview mode (WorkingTree/Log/BranchDiff/UpstreamDiff/Summary) |
| `Enter` | Select and switch to worktree |
| `alt-c` | Create new worktree from query text |
| `alt-r` | Remove selected worktree |
| `alt-p` | Toggle preview panel |
| `ctrl-u` / `ctrl-d` | Scroll preview up/down half page |
| `ctrl-c` / `Esc` | Cancel |

---

## Crystal Architecture

Instead of shelling out to an external `fzf`/`skim` binary, the Crystal port
uses a fully integrated TUI built with `bubbletea` and `bubbles` components:

```
┌─ Main TUI (Tea::Program) ────────────────────────────────┐
│ ┌─ List Panel ───────────────┐ ┌─ Preview Panel ────────┐ │
│ │ [Filter: ████████████    ] │ │ Tab: 1·2·3·4·5         │ │
│ │                            │ │                        │ │
│ │  main          /repo   ↑3  │ │ diff --git a/x b/x     │ │
│ │▶ feature/fix   /wt/feat ↑1 │ │ + fn fix_login() {     │ │
│ │  feat/auth     /wt/auth ↓2 │ │ +   validate(input)    │ │
│ │  ...                       │ │ -   return old_token    │ │
│ │                            │ │                        │ │
│ │ ── 3/12 ──                 │ │ ── 45% scrolled ──     │ │
│ └────────────────────────────┘ └────────────────────────┘ │
│  Enter:select  1-5:preview  /:filter  q:quit  ?:help    │
└──────────────────────────────────────────────────────────┘
```

### Component mapping (vendor → Crystal)

| Vendor (skim) | Crystal (bubbletea + bubbles) |
|---|---|
| Skim item list | `Bubbles::List::Model` with custom `Item` and `ItemDelegate` |
| Fuzzy matching | `Bubbles::List` built-in fuzzy filter (`default_filter`) |
| Preview window | `Bubbles::Viewport::Model` for scrollable diff/log output |
| Mode tabs (1-5) | Tea model state field `preview_mode : PreviewMode` |
| Key bindings | `Bubbles::Key` declarative bindings |
| Alt screen | `Tea.with_alt_screen` |
| alt-r reload | Tea message to remove item from list |
| Progressive updates | `Tea::Cmd` background fibers → `Tea.send(msg)` |

---

## Crystal Model (Elm Architecture)

```crystal
require "bubbletea"
require "bubbles"
require "lipgloss"

module WorkTrees
  module Picker
    enum PreviewMode
      WorkingTree = 1  # git diff HEAD (uncommitted changes)
      Log         = 2  # git log --graph with merge-base dimming
      BranchDiff  = 3  # git diff against default branch
      UpstreamDiff = 4 # git diff against upstream tracking branch
      Summary     = 5  # LLM-generated branch summary
    end

    struct PickerItem
      include Bubbles::List::DefaultItem

      property branch : String
      property worktree_path : String
      property head_sha : String
      property status_symbols : String    # "↑3 ↓1"
      property is_current : Bool

      def filter_value : String
        "#{@branch} #{@worktree_path}"
      end

      def title : String
        "#{@branch}"
      end

      def description : String
        path = @worktree_path ? " #{@worktree_path}" : ""
        "#{path}  #{@status_symbols}"
      end
    end

    class Model
      include Tea::Model

      property list : Bubbles::List::Model
      property viewport : Bubbles::Viewport::Model
      property preview_mode : PreviewMode
      property items : Array(PickerItem)
      property repo : Git::Repository?
      property quitting : Bool

      def initialize(@repo, @worktrees)
        @preview_mode = PreviewMode::WorkingTree

        # Build items
        @items = build_items(@worktrees)

        # Create list component
        delegate = Bubbles::List.new_default_delegate
        delegate.styles = build_styles
        @list = Bubbles::List.new(
          @items.map(&.as(Bubbles::List::Item)),
          delegate,
          width: terminal_width // 2,
          height: terminal_height - 4,
        )
        @list.status_bar = "Enter:select  1-5:preview  /:filter  q:quit"
        @list.show_filter = true

        # Create viewport for preview
        @viewport = Bubbles::Viewport::Model.new(
          Bubbles::Viewport.with_width(terminal_width // 2),
          Bubbles::Viewport.with_height(terminal_height - 4),
        )
        @viewport.soft_wrap = true
        @quitting = false
      end

      def init : Tea::Cmd?
        # Prewarm: compute preview for selected item
        compute_preview(@items[0], @preview_mode)
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        case msg
        when Tea::KeyPressMsg
          handle_key(msg)
        when PreviewLoadedMsg
          @viewport.set_content(msg.content)
          {self, nil}
        else
          # Delegate to list for cursor/filter/etc
          @list, cmd = @list.update(msg)
          # Recompute preview when selection changes
          if selected_item = @items[@list.index]?
            {self, Tea.batch(cmd, compute_preview(selected_item, @preview_mode))}
          else
            {self, cmd}
          end
        end
      end

      def view : Tea::View
        left = @list.view
        right = @viewport.view
        # Join left and right panels horizontally
        content = Lipgloss.join_horizontal(
          Lipgloss::Position::Top,
          left, right,
        )
        Tea::View.new(content)
      end

      private def handle_key(key) : {Model, Tea::Cmd?}
        case key.to_s
        when "1" then switch_mode(PreviewMode::WorkingTree)
        when "2" then switch_mode(PreviewMode::Log)
        when "3" then switch_mode(PreviewMode::BranchDiff)
        when "4" then switch_mode(PreviewMode::UpstreamDiff)
        when "5" then switch_mode(PreviewMode::Summary)
        when "enter" then select_item
        when "q", "ctrl+c", "esc" then quit
        when "alt+r" then remove_item
        else {self, nil}
        end
      end
    end
  end
end
```

---

## Preview Computation

Each preview mode runs git commands and returns formatted content:

```crystal
def compute_preview(item : PickerItem, mode : PreviewMode) : Tea::Cmd?
  ->{
    content = case mode
    when .working_tree?
      compute_working_tree_preview(item)
    when .log?
      compute_log_preview(item)
    when .branch_diff?
      compute_branch_diff_preview(item)
    when .upstream_diff?
      compute_upstream_diff_preview(item)
    when .summary?
      compute_summary_preview(item)
    end
    PreviewLoadedMsg.new(content)
  }
end
```

**WorkingTree**: `git diff HEAD --color=always`, truncated to 500 lines
**Log**: `git log --graph --color=always --decorate -20`, with merge-base dimming
**BranchDiff**: `git diff <default>...<branch> --color=always --stat`, then `--numstat`
**UpstreamDiff**: `git diff @{u}...<branch> --color=always`
**Summary**: Pipe diff to configured LLM, cache result per commit SHA

---

## Styling (using Lipgloss)

```crystal
def build_styles : Bubbles::List::DefaultItemStyles
  dark = true
  Bubbles::List.new_default_item_styles(is_dark: dark).tap do |s|
    s.normal_title = Lipgloss.new_style.
      foreground(Lipgloss.color("7")).
      padding(0, 1)
    s.selected_title = Lipgloss.new_style.
      foreground(Lipgloss.color("15")).
      background(Lipgloss.color("62")).
      border(Lipgloss.normal_border, false, false, false, true).
      padding(0, 1)
    s.dimmed_title = Lipgloss.new_style.
      foreground(Lipgloss.color("8")).
      padding(0, 1)
    s.filter_match = Lipgloss.new_style.underline(true)
  end
end
```

---

## Status Bar

Bottom bar showing key bindings:

```
Enter:select  1-5:preview  /:filter  q:quit  ?:help  3/12
```

---

## Implementation Phases

### Phase A: Core TUI (skeleton rendering)

1. **PickerItem** struct with `Bubbles::List::DefaultItem` include
2. **PickerDelegate** with styled rendering (branch name + path + ahead/behind)
3. **Model** with list + viewport + preview_mode state
4. **View** rendering left/right panels joined horizontally
5. **Key handling**: 1-5 mode switch, enter select, q quit, / filter
6. **Tea::Program** wiring with alt screen, mouse support

### Phase B: Preview computation

1. `compute_working_tree_preview` — `git diff HEAD`
2. `compute_log_preview` — `git log --graph`
3. `compute_branch_diff_preview` — `git diff main...branch`
4. `compute_upstream_diff_preview` — `git diff @{u}...branch`
5. `compute_summary_preview` — LLM via configured command
6. Async preview loading via `Tea::Cmd` fibers
7. Preview caching (in-memory) for instant tab switch

### Phase C: Progressive loading + polish

1. Background prewarm: compute WorkingTree preview for first item on init
2. Display relative timestamps in Log preview
3. Diffstat summary line in diff previews
4. Merge-base dimming in Log view
5. Keyboard legend at bottom
6. Paginator for large worktree lists

### Phase D: Advanced features

1. alt-r removal (remove worktree from picker)
2. alt-c create (create branch from query text)
3. Persistent disk cache for previews
4. Background pre-compute tier 2 (rest of items)

---

## Upstream Parity Table

| Feature | Vendor (skim) | Crystal (bubbletea) |
|---|---|---|
| Item list | skim TUI | Bubbles::List |
| Fuzzy filtering | skim built-in | Bubbles::List default_filter |
| Preview modes | 5 modes via temp file | Model state field |
| Key bindings | skim execute/accept | Tea::KeyPressMsg |
| Alt screen | skim default | Tea.with_alt_screen |
| Progressive loading | Mutex + heartbeat | Tea::Cmd fibers |
| Preview cache | DashMap + SHA disk | In-memory Hash + optional disk |
| Remove (alt-r) | Reload via channel | Remove from list + reload |
| Create (alt-c) | accept(create) | Switch to create flow |

## Divergences

| ID | Area | Decision |
|----|------|----------|
| D5 | Picker engine | Integrated bubbletea TUI instead of shelling out to fzf/skim binary |
| D6 | Preview protocol | Tea messages via fibers instead of temp-file state and skim heartbeat |
| D7 | Items | `Bubbles::List::DefaultItem` instead of `SkimItem` trait |

---

## Dependencies

- `dsisnero/bubbles` — `Bubbles::List::Model`, `Bubbles::Viewport::Model`, `Bubbles::Key`
- `dsisnero/lipgloss` — Styling primitives, horizontal join, borders
- `dsisnero/bubbletea` (transitive via bubbles) — `Tea::Program`, Elm architecture

## Specs

Each phase includes TDD specs:

- **Phase A**: PickerItem filter_value, Delegate rendering, Model init, key handling
- **Phase B**: Each preview compute function with known git output snapshots
- **Phase C**: Timeline formatting, paginator slice bounds, status bar content
- **Phase D**: Item removal, item creation, cache read/write roundtrip
