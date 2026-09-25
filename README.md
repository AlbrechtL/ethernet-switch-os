# ethernet-switch-os

> **⚠️ Proof of concept.** This project is a proof of concept, built to see how
> far AI assistance gets on a real embedded Linux product. It was created with
> the help of AI, has not undergone thorough review or hardening, and should
> not be assumed suitable for production use.

**Ethernet Switch OS** is a minimal Linux system for managed Ethernet
switches, based on YANG and OpenConfig models. The switch is configured
through those models and offers three ways to do it: a RESTCONF API, a CLI and
a simple web UI.

It is built with the [Yocto Project](https://www.yoctoproject.org/): the
system is a custom distro on top of OpenEmbedded, assembled per board from
Yocto layers, and the result is a flashable firmware image rather than a
general-purpose Linux installation. See [Building](#building) for how to
build it.

## Documentation

The **[user guide](https://albrechtl.github.io/ethernet-switch-os/)** covers
using a switch that runs Ethernet Switch OS: first login, the CLI, the
management address and DHCP, VLANs, spanning tree, SNMP, firmware updates
and the current limitations. Its source is in [`docs/`](docs/); see
[Building the user guide](#building-the-user-guide) for previewing it
locally. This README is about building the firmware.

## Supported hardware

| Hardware | SoC | Status |
|---|---|---|
| Zyxel GS1900-8 (rev A1), 8 × Gigabit | Realtek RTL8380 | Supported (`zyxel-gs1900-8-a1`) |
| Zyxel GS1900-8, emulated by [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) | Realtek RTL8380 (emulated) | Supported, same image as the real switch (see [Running in QEMU](https://albrechtl.github.io/ethernet-switch-os/getting-started/qemu/)) |
| QEMU x86_64 | — | Coming soon |

## Components and repositories

This repository is the build entry point and contains no recipes of its own.
It holds [kas](https://kas.readthedocs.io/) configuration files that describe,
per board, which Yocto layers to check out and how to configure them — so that
a build needs nothing on the host but Docker, git and a POSIX shell. The
interesting parts live in four repositories of their own. kas checks the three
layers out under `layers/`; `rtl838x-qemu` is a separate tool and is cloned by
hand when it is needed.

| Repository | Role |
|---|---|
| [clixon-switch-rs](https://github.com/AlbrechtL/clixon-switch-rs) | The [clixon](https://www.clicon.org/) backend plugin, in Rust. Applies an OpenConfig configuration to the kernel: DSA ports in a VLAN-aware bridge, routed VLAN interfaces, spanning tree via mstpd, a read-only SNMPv3 agent. Built by a recipe in `meta-ethernet-switch-os`, not checked out by kas. |
| [meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os) | The distro and the userspace: the `ethernet-switch-os` distro (poky-tiny plus sysvinit), clixon with the plugin, dropbear, SWUpdate with its two `.swu` images, and the read-only status web UI. |
| [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp) | The hardware: Realtek RTL83xx switch SoCs. Machine configurations, the patched kernel and its device trees, `rt-loader`, and the flash image types. The kernel patches (Realtek SoC support, device trees, MTD split) are taken from [OpenWrt](https://openwrt.org/) — many thanks to the OpenWrt developers for their work, without which this would not exist. Boots on its own, without the OS layer. |
| [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) | Emulates an RTL838x switch, for booting and testing a built image without hardware. Frames really cross between the eight emulated front ports, so VLANs and spanning tree can be exercised. |

## Requirements

Docker, git and a POSIX shell. VS Code with the Dev Containers extension if
you want to work in the development container from the editor.

Everything else — bitbake's host dependencies, the cross toolchain, Python,
Rust — is inside the container image. `kas-container` in this repository is
the upstream script from [siemens/kas](https://github.com/siemens/kas),
vendored and pinned to kas 5.5.

## Building

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
```

The build always runs in a container, and there are two ways into it. The kas
commands are the same in both — only the name differs: `kas` inside the dev
container, `./kas-container` on the host.

### In VS Code, with the dev container

Open the checkout in VS Code and run **Dev Containers: Reopen in Container**.
VS Code builds the development image from `Dockerfile` (the upstream kas
image plus tools for working on the project) and mounts the checkout at `/work`.
`.devcontainer/devcontainer.json` already sets `KAS_BUILD_DIR`, `DL_DIR` and
`SSTATE_DIR`, so in a terminal there:

```sh
kas build kas/board/zyxel-gs1900-8-a1.yml
```

### On the shell, with kas-container

`kas-container` runs kas in a Docker container by itself, so this is all a
build needs:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml
```

That uses the upstream `ghcr.io/siemens/kas/kas:5.5` image and puts
everything under `build/`. Two optional additions, both what the dev
container does too:

- **The development image** from `Dockerfile`: the upstream kas image plus
  tools for working *on* the project (a host Rust toolchain, `dtc`,
  `mkimage`, the JFFS2 tools, a Docker client for rtl838x-qemu). It builds the
  same artifacts. `kas-container` does not build images, so build it once,
  and again whenever `Dockerfile` changes. The tag has to match the vendored
  `kas-container` (5.5), or kas refuses to run.
- **Downloads and shared state outside `build/`**, so they survive deleting
  it and are shared between boards. `kas-container` creates the directories
  and mounts them into the container.

```sh
docker build -t ethernet-switch-os/kas:5.5 - < Dockerfile
export KAS_CONTAINER_IMAGE=ethernet-switch-os/kas:5.5
export KAS_BUILD_DIR=$PWD/build DL_DIR=$PWD/downloads SSTATE_DIR=$PWD/sstate-cache
./kas-container build kas/board/zyxel-gs1900-8-a1.yml
```

### Other kas commands

Written for the shell; in the dev container replace `./kas-container` with
`kas`.

| Command | What it does |
|---|---|
| `./kas-container build kas/board/<board>.yml` | Build a board. |
| `./kas-container shell kas/board/<board>.yml` | A shell with bitbake ready, e.g. for `bitbake -c menuconfig virtual/kernel`. |
| `./kas-container checkout kas/board/<board>.yml` | Clone the layers and write `build/conf/` without building anything. |
| `./kas-container dump kas/board/<board>.yml` | Print the fully resolved configuration. |
| `ls kas/board/` | The boards that can be built. |
| `rm -rf build` | Start over. Layers, downloads and shared state are kept, so the next build is fast. |
| `rm -rf build layers downloads sstate-cache` | Drop everything kas created. |

A first build takes hours. `kas/opt/sstate-mirror.yml` pulls oe-core's share
of it from the Yocto Project's CDN instead:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/sstate-mirror.yml
```

### What comes out

In `build/tmp/deploy/images/zyxel-gs1900-8-a1/`:

| File | What it is for |
|---|---|
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin` | TFTP boot image; the first install and recovery run entirely from RAM. |
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1-rt-loader.bin` | The same payload without the uImage header, for booting with `go` instead of `bootm`. |
| `ethernet-switch-os-swu-factory-zyxel-gs1900-8-a1.swu` | First install, uploaded from the TFTP initramfs. Writes `firmware`, wipes `data`. |
| `ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu` | Update in place. Rewrites `firmware`, keeps user data. |

The flash layout, the TFTP procedure and what to type at the stock bootloader
are in [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp)'s
README. Once the switch is up: `ssh cli@192.168.1.1` for the clixon CLI,
`http://192.168.1.1/` for the status page, `http://192.168.1.1:8080` for
SWUpdate. The [user guide](https://albrechtl.github.io/ethernet-switch-os/)
takes it from there.

### Building the user guide

The user guide is plain [MkDocs](https://www.mkdocs.org/) with the Material
theme, and needs only Docker too. Serve it on http://localhost:8000, rebuilt
on every change:

```sh
docker run --rm -it -p 8000:8000 -v $PWD:/docs squidfunk/mkdocs-material:9.7.7
```

Or build it into `site/` the way CI does, failing on warnings and broken
links:

```sh
docker run --rm -u $(id -u):$(id -g) -v $PWD:/docs squidfunk/mkdocs-material:9.7.7 build --strict
```

The image version matches `docs/requirements.txt`, which CI installs with pip.

## Testing without hardware

```sh
git clone --recurse-submodules https://github.com/AlbrechtL/rtl838x-qemu
cd rtl838x-qemu
./rtl838x.sh build
./rtl838x.sh run ../ethernet-switch-os/build/tmp/deploy/images/zyxel-gs1900-8-a1/ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin
```

That is the TFTP boot image, uImage header and all: the machine parses the
header the same way the stock bootloader does, so `rt-loader` runs exactly as
it does on the real switch.

`rtl838x-qemu` runs QEMU in its own container and takes the image as its first
argument, so it is kept outside kas. The development container has a Docker
client for driving it from inside; the devcontainer mounts the socket for
that.

## Layers

| Layer | Repository | Branch |
|---|---|---|
| `meta` | [openembedded-core](https://git.openembedded.org/openembedded-core) | wrynose |
| `meta-poky` | [meta-yocto](https://git.yoctoproject.org/meta-yocto) | wrynose |
| `meta-oe`, `meta-python`, `meta-networking` | [meta-openembedded](https://github.com/openembedded/meta-openembedded) | wrynose |
| `meta-swupdate` | [meta-swupdate](https://github.com/sbabic/meta-swupdate) | wrynose |
| `meta-rtl83xx-bsp` | [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp) | master |
| `meta-ethernet-switch-os` | [meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os) | master |

Plus [bitbake](https://git.openembedded.org/bitbake) (branch `2.18`), which is
the build tool rather than a layer.

Branch tips, deliberately: every layer uses the current head of its branch in
every build and every CI run, and kas warns about that on every invocation. If a reproducible build is ever needed,
`./kas-container lock kas/board/<board>.yml` writes a lock file next to the
board file, which kas then picks up on its own; `--update` refreshes it.

`meta-python` is in the list only because `meta-networking` names it in
`LAYERDEPENDS`; nothing here builds from it. The Yocto Project retired the
combined `poky` repository after *walnascar*, which is why oe-core, meta-yocto
and bitbake are three separate checkouts.

## The kas files

```
kas/
├── base.yml                      bitbake, openembedded-core, meta-poky
├── os.yml                        meta-ethernet-switch-os and its dependencies,
│                                 and the ethernet-switch-os distro
├── bsp/
│   └── rtl83xx.yml               meta-rtl83xx-bsp
├── board/
│   └── zyxel-gs1900-8-a1.yml     base + bsp + os, MACHINE, targets, artifacts
└── opt/
    ├── ci.yml                    rm_work, for a disk-bound runner
    ├── sstate-mirror.yml         pull oe-core's shared state from the CDN
    ├── local-layers.yml          stop kas resetting the layers/ checkouts
    └── devtool.yml               keep devtool's workspace across kas runs
```

A board file is the only thing that needs naming on the command line; it
includes the rest. Anything under `kas/opt/` is appended with a colon and
layers on top:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/sstate-mirror.yml
```

`./kas-container dump kas/board/<board>.yml` prints the whole thing resolved,
which is the quickest way to see what a combination actually means.

### Adding a board

If the BSP already has a machine configuration for it, a board file is all it
takes — copy `kas/board/zyxel-gs1900-8-a1.yml`, change `machine:` and the
artifact paths, and add the name to the `board:` matrix in
`.github/workflows/build.yml`. For a board the BSP does not know yet, the
machine `.conf` (and usually a device tree) goes into `meta-rtl83xx-bsp`
first.

### Adding a BSP

A second hardware family is a new file under `kas/bsp/`, listing that BSP
layer and nothing else, plus board files that include it instead of
`kas/bsp/rtl83xx.yml`. Nothing in `base.yml` or `os.yml` changes:
`meta-ethernet-switch-os` deliberately does not depend on the BSP, and reaches
into it through `BBFILES_DYNAMIC` only where the BSP is present. Making that
cheap is the reason this repository exists.

### Working on a layer

kas checks the layers out under `layers/` as ordinary git clones, but it owns
them: on every invocation it resets the local branch to the upstream one. A
commit made in `layers/` and not yet pushed is **dropped from the branch** by
the next build -- it survives in the reflog, but nothing points at it
any more.

So while working on a layer, add the fragment that tells kas to keep its
hands off the project's own layers:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/local-layers.yml
```

Then `layers/meta-ethernet-switch-os` and `layers/meta-rtl83xx-bsp` are yours
to edit, commit and push, and nothing moves underneath. Everything else still
follows its branch tip. Without it, work in a clone of your own and let kas
fetch from the remote.

For `clixon-switch-rs`, whose source bitbake fetches from git, use devtool:

```sh
./kas-container shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/devtool.yml
devtool modify clixon-switch
# edit build/workspace/sources/clixon-switch, then
bitbake ethernet-switch-os-swu-upgrade
```

`kas/opt/devtool.yml` is needed because kas rewrites `bblayers.conf` on every
invocation and would otherwise drop the workspace layer again.

## Continuous integration

`.github/workflows/build.yml` runs the same `./kas-container build` as a local
build, one job per board, on every push to `master` and on pull requests, and
uploads the four images as a job artifact.

The layer repositories no longer build images of their own. A push to
`meta-ethernet-switch-os` runs a parse check there -- this configuration, this
machine, no task executed -- which catches a broken recipe in minutes. It
cannot trigger this workflow, so this one also runs weekly, which is what
turns the layers' current `master` into images. Because almost nothing is
pinned, that run doubles as a check that the upstream branches still build.

## Relation to the earlier build setup

This replaces a `bitbake-setup` tree in which `bblayers.conf` held absolute
paths, machine and distro were selected by mutable `bitbake-config-build`
state inside the build directory, and the layer revisions were maintained by
hand in three different places. One board at a time, and adding a second one
meant editing that state. Here a board is a file.
