.PHONY: install update build format lint test clean

install:
	shards install

update:
	shards update

build:
	crystal build src/cli.cr -o bin/wktrees

format:
	crystal tool format src spec

lint:
	ameba src spec

test:
	crystal spec

clean:
	rm -rf .crystal-cache/ bin/ lib/ .shards/
