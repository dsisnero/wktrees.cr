# WorkTrees

This repository is a Crystal port of https://github.com/max-sixty/worktrunk

Upstream pinned ref: `8c6ed7e3f68efb3bac43c420d136f5360ff24d54` (v0.51.0)

## Upstream README Highlights

Worktrunk is a CLI for Git worktree management, designed for parallel AI agent workflows.
It makes git worktrees as easy as branches, with three core commands:

- `wt switch` — Switch worktrees (create + start)
- `wt list` — List worktrees with status (CI status, AI summaries, diffs)
- `wt remove` — Clean up worktrees and branches

Additional features: hooks for workflow automation, LLM commit messages, merge workflow,
interactive picker, PR checkout, build cache sharing, dev server per worktree, aliases,
and per-branch variables.

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

```bash
make install  # install dependencies
make format   # format code
make lint     # lint code
make test     # run tests
```

## Contributing

1. Fork it (<https://github.com/dsisnero/work_trees/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
