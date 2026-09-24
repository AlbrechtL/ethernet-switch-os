# Convenience wrapper around ./kas-container. Everything it does can be done
# by hand -- it only fills in the environment variables kas-container reads,
# so that downloads and shared state survive "make clean" and are shared
# between boards.
#
#   make container                    build the development image (once)
#   make build                        build the default board
#   make build BOARD=other-board
#   make build OPT=kas/opt/sstate-mirror.yml
#   make shell                        a shell with bitbake ready
#   make boards                       what can be built

KAS_VERSION           ?= 5.5
KAS_CONTAINER_IMAGE   ?= ethernet-switch-os/kas:$(KAS_VERSION)
BOARD                 ?= zyxel-gs1900-8-a1
# Extra kas fragments, colon separated, appended to the board file.
OPT                   ?=

TOP := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

KAS_WORK_DIR  ?= $(TOP)
KAS_BUILD_DIR ?= $(TOP)/build
DL_DIR        ?= $(TOP)/downloads
SSTATE_DIR    ?= $(TOP)/sstate-cache
export KAS_CONTAINER_IMAGE KAS_WORK_DIR KAS_BUILD_DIR DL_DIR SSTATE_DIR

KAS      := $(TOP)/kas-container
KAS_CONF := kas/board/$(BOARD).yml$(if $(OPT),:$(OPT))
DEPLOY   := $(KAS_BUILD_DIR)/tmp/deploy/images/$(BOARD)

.PHONY: all container build checkout shell dump boards deploy clean distclean help

all: build

## Build the development image. Only needed again when Dockerfile
## changes.
container:
	docker build -t $(KAS_CONTAINER_IMAGE) - < Dockerfile

build:
	$(KAS) build $(KAS_CONF)

## Clone the layers and write build/conf/ without building anything.
checkout:
	$(KAS) checkout $(KAS_CONF)

## A shell inside the container with bitbake on PATH.
shell:
	$(KAS) shell $(KAS_CONF)

## The fully resolved configuration, for checking what a board file expands to.
dump:
	$(KAS) dump $(KAS_CONF)

boards:
	@ls kas/board/*.yml | sed 's|kas/board/||; s|\.yml$$||'

## What the last build left behind.
deploy:
	@ls -lL $(DEPLOY)/*.swu $(DEPLOY)/*-initramfs-$(BOARD)*.bin 2>/dev/null || \
		echo "nothing built for $(BOARD) yet"

## Drop the build directory. Layers, downloads and shared state are kept, so
## the next build is fast.
clean:
	rm -rf $(KAS_BUILD_DIR)

## Drop everything kas created, including the layer checkouts and the
## downloads.
distclean: clean
	rm -rf $(TOP)/layers $(DL_DIR) $(SSTATE_DIR)

help:
	@sed -n 's|^#   ||p' $(lastword $(MAKEFILE_LIST)) | head -6
	@echo
	@echo "BOARD=$(BOARD)  OPT=$(OPT)"
	@echo "image=$(KAS_CONTAINER_IMAGE)"
