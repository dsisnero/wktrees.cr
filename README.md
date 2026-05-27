# wktrees

A CLI for Git worktree management, designed for parallel AI agent workflows.
Crystal port of [worktrunk](https://github.com/max-sixty/worktrunk) (Rust, v0.51.0).

The binary is installed as `wktrees`.

```
wktrees switch <branch>         # switch to a worktree
wktrees switch --create <name>  # create and switch
wktrees list                    # list worktrees with status
wktrees remove <branch>         # cleanup worktrees
wktrees merge                   # commit, squash, rebase, FF merge
wktrees step commit             # conventional commit with LLM
wktrees step for-each 'cmd'     # run command on every worktree
wktrees config show             # view configuration
wktrees shell install           # shell integration
```

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

1. Fork it (<https://github.com/dsisnero/wktrees/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
