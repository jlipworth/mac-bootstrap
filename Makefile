SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help test lint security release-smoke validate release-assets

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run Bats tests.
	@command -v bats >/dev/null || { echo "bats is required" >&2; exit 1; }
	bats tests

lint: ## Check shell formatting and static analysis.
	@command -v shfmt >/dev/null || { echo "shfmt is required" >&2; exit 1; }
	@command -v shellcheck >/dev/null || { echo "shellcheck is required" >&2; exit 1; }
	shfmt -d -i 2 -ci -bn bootstrap.sh lib scripts tests/*.bash
	shellcheck -x bootstrap.sh lib/*.sh scripts/*.sh tests/*.bash

security: ## Check tracked content for prohibited secret material.
	./tests/no-secrets.sh

release-smoke: ## Build and syntax-check the standalone release artifact.
	./scripts/build-release.sh
	bash -n dist/bootstrap.sh
	@if MB_NONINTERACTIVE=1 MB_TEST_OS=Linux MB_TEST_ARCH=arm64 ./dist/bootstrap.sh > /dev/null 2>&1; then \
		echo "platform guard failed" >&2; \
		exit 1; \
	fi

validate: lint test security release-smoke ## Run all repository checks.

release-assets: release-smoke ## Build the standalone script and its checksum.
	cd dist && shasum -a 256 bootstrap.sh > bootstrap.sh.sha256
