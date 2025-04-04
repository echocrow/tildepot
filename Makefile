VERSION ?= 0.0.0-dev

.PHONY: dev
dev:
	@bash scripts/dev.sh

.PHONY: format
format:
	@bash scripts/format.sh src

.PHONY: test
test:
	@$(MAKE) build
	@bash scripts/test.sh
	@bash scripts/format.sh test

.PHONY: build
build:
	@bash scripts/build.sh $(VERSION)
	@bash scripts/format.sh build
