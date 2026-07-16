SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help test lint security validate checksum

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run Bats tests.
	@command -v bats >/dev/null || { echo "bats is required" >&2; exit 1; }
	bats tests

lint: ## Check shell formatting and static analysis.
	@command -v shfmt >/dev/null || { echo "shfmt is required" >&2; exit 1; }
	@command -v shellcheck >/dev/null || { echo "shellcheck is required" >&2; exit 1; }
	shfmt -d -i 2 -ci -bn bootstrap.sh lib tests/*.bash
	shellcheck -x bootstrap.sh lib/*.sh tests/*.bash

security: ## Check tracked content for prohibited secret material.
	./tests/no-secrets.sh

validate: lint test security ## Run all repository checks.

checksum: ## Write a SHA-256 checksum for bootstrap.sh.
	shasum -a 256 bootstrap.sh > bootstrap.sh.sha256
