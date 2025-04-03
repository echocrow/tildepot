VERSION ?= 0.0.0-dev

.PHONY: dev
dev:
	@bash scripts/dev.sh

.PHONY: test
test:
	@$(MAKE) build
	@bash scripts/test.sh

.PHONY: build
build:
	@bash scripts/build.sh $(VERSION)
