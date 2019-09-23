SHELL := bash

VERSION_VALUE ?= $(shell git rev-parse --short HEAD 2>/dev/null)
DOCKER_IMAGE_REPO ?= travisci/travis-scheduler
DOCKER_DEST ?= $(DOCKER_IMAGE_REPO):$(VERSION_VALUE)
QUAY ?= quay.io
QUAY_IMAGE ?= $(QUAY)/$(DOCKER_IMAGE_REPO)

ifdef $$QUAY_ROBOT_HANDLE
	QUAY_ROBOT_HANDLE := $$QUAY_ROBOT_HANDLE
endif
ifdef $$QUAY_ROBOT_TOKEN
	QUAY_ROBOT_TOKEN := $$QUAY_ROBOT_TOKEN
endif
ifndef $$TRAVIS_BRANCH
	TRAVIS_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
endif
ifndef $$TRAVIS_PULL_REQUEST
	TRAVIS_PULL_REQUEST ?= $$TRAVIS_PULL_REQUEST
endif
ifndef $$BUNDLE_GEMS__CONTRIBSYS__COM
	BUNDLE_GEMS__CONTRIBSYS__COM ?= $$BUNDLE_GEMS__CONTRIBSYS__COM
endif

DOCKER ?= docker

.PHONY: docker-build
docker-build:
	$(DOCKER) build --build-arg bundle_gems__contribsys__com=$(BUNDLE_GEMS__CONTRIBSYS__COM) -t $(DOCKER_DEST) .

.PHONY: docker-push
docker-push:
	$(DOCKER) login -u=$(QUAY_ROBOT_HANDLE) -p=$(QUAY_ROBOT_TOKEN) $(QUAY)
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):$(VERSION_VALUE)
	$(DOCKER) push $(QUAY_IMAGE):$(VERSION_VALUE)

.PHONY: docker-latest
docker-latest:
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):latest
	$(DOCKER) push $(QUAY_IMAGE):latest

.PHONY: ship
ship: docker-build docker-push

ifeq ($(shell [[ $(TRAVIS_BRANCH) == master && $(TRAVIS_PULL_REQUEST) == false ]] ),true)
ship: docker-latest
endif
