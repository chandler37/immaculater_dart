SHELL := $(shell which bash)

.PHONY: help
help:
	@echo "See README.md"

.PHONY: install
install: .pubgotten

.PHONY: fmt
fmt: .pubgotten
	dartfmt -l 100 -w .
	git checkout -- lib/src/generated/**/*.dart

.PHONY: lint
lint: .pubgotten
	dartanalyzer --fatal-infos --fatal-warnings bin lib test

.pubgotten: pubspec.yaml
	pub get
	touch $@

.PHONY: test
test: .pubgotten
	pub run test

.PHONY: run
run: .pubgotten
	dart bin/main.dart

.PHONY: clean
clean:
	@rm -fr .dart_tool .packages .pubgotten build
	@echo "NOTE: Leaving pubspec.lock but you might want to remove it too."

.DEFAULT_GOAL := help
