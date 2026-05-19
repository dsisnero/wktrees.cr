#!/usr/bin/env crystal
# Binary entry point for work_trees CLI.
# This file is the target in shard.yml.

require "./work_trees"

WorkTrees::CLI.run
