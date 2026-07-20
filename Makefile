IMAGE_NAME ?= rhel9-dev-toolbox
CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || command -v docker)

.PHONY: build lint create enter clean

build:
	$(CONTAINER_ENGINE) build -t $(IMAGE_NAME) -f Containerfile .

lint:
	bash -n scripts/*.sh bin/*
	@echo "shell syntax OK"

create: build
	toolbox create --image localhost/$(IMAGE_NAME) rhel9-dev

enter:
	toolbox enter rhel9-dev

clean:
	-toolbox rm -f rhel9-dev
	-$(CONTAINER_ENGINE) rmi $(IMAGE_NAME)
