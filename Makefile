VERSION ?= 0.0.0-dev

.PHONY: prepare
prepare:
	@git config core.hooksPath ./scripts/git_hooks

.PHONY: dev
dev:
	@bash scripts/dev.sh build

.PHONY: format
format:
	@bash scripts/format.sh src

.PHONY: check
check:
	@$(MAKE) build
	@bash scripts/check.sh
	@bash scripts/format.sh check

.PHONY: test
test:
	@VERSION=0.0.0-test $(MAKE) build
	@bash scripts/test.sh $(TESTS)

.PHONY: test-watch
test-watch:
	@bash scripts/dev.sh test

.PHONY: build
build:
	@bash scripts/build.sh $(VERSION)
	@bash scripts/format.sh build

.PHONY: build-release
build-release:
	@bash scripts/release.sh
