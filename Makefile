VERSION ?= 0.0.0-dev

.PHONY: dev
dev:
	@bash scripts/dev.sh

.PHONY: test
test:
	@bash scripts/test.sh

.PHONY: build
build:
	@bash scripts/build.sh $(VERSION)
