VERSION ?= 0.0.0-dev

.PHONY: dev
dev:
	@bash scripts/dev.sh

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
	@bash scripts/test.sh

.PHONY: build
build:
	@bash scripts/build.sh $(VERSION)
	@bash scripts/format.sh build
