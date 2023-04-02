#@name DocsetApi

# Use one shell for the whole recipe, instead of per-line
.ONESHELL:
# Use bash in strict mode
SHELL := bash
.SHELLFLAGS = -eu -o pipefail -c

# Build variables
APP_NAME ?= $(shell grep 'app:' mix.exs | sed -e 's/\[//g' -e 's/ //g' -e 's/app://' -e 's/[:,]//g')
APP_VSN ?= $(shell grep 'version:' mix.exs | cut -d '"' -f2 )
BUILD ?= $(shell git rev-parse --short HEAD )

deps: mix.exs mix.lock
	@mix deps.get
	touch $@

.PHONY: build
build:
	mix compile

RELEASE_PATH = "_build/$(MIX_ENV)/rel/$(APP_NAME)/releases/$(APP_VSN)/"

.PHONY: release
release:
	MIX_ENV=prod mix release --path $(RELEASE_PATH)

.DEFAULT_GOAL := start
.PHONY: start
## Start DocsetApi on http://localhost:3667
## To add a new docset use: http://localhost:3667/feeds/<package_name>
start: deps
	PORT=3667 mix phx.server

# Docker Section
# --------------
#
# This is dedicated to target that are docker related

# Secret build args
source_build_args = source env.sh 2>&1 > /dev/null || true

# Build the Docker image
TAG = $(APP_VSN)-$(BUILD)
BUILDER_IMG = $(APP_NAME)-builder
TESTER_IMG = $(APP_NAME)-tester

.PHONY: docker-build
docker-build:
	@echo "🐳 Build the docker image"
	docker build \
			--rm=false \
			--build-arg APP_NAME=$(APP_NAME) --build-arg APP_VSN=$(APP_VSN) \
			-t $(BUILDER_IMG):$(TAG) \
			-t $(BUILDER_IMG):latest \
			--target builder .

.PHONY: docker-release
docker-release:
	@echo "🐳 Create a production docker image"
	docker build \
	    --build-arg APP_NAME=$(APP_NAME) --build-arg APP_VSN=$(APP_VSN) \
			-t $(APP_NAME):$(APP_VSN)-$(BUILD) \
			-t $(APP_NAME):latest \
			--target production .

.PHONY: docker-serve
## Run the app in Docker
docker-serve:
	@echo "🐳 Run Bidex in docker"
	docker run \
		-e PORT=3667 \
    -p 3667:3667 \
    --rm -it $(APP_NAME):latest

bin/pretty-make:
	@curl -Ls https://raw.githubusercontent.com/awea/pretty-make/master/scripts/install.sh | bash -s

.PHONY: help
## List available commands
help: bin/pretty-make
	@bin/pretty-make pretty-help Makefile
