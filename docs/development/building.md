# Building the firmware

Ethernet Switch OS is built with the [Yocto Project](https://www.yoctoproject.org/).
This repository is the build entry point. It holds [kas](https://kas.readthedocs.io/)
configuration files that describe, per board, which Yocto layers to check out
and how to configure them, so a build needs nothing on the host but Docker,
git and a POSIX shell. The result is a flashable firmware image.

## Requirements

Docker, git and a POSIX shell. VS Code with the Dev Containers extension if
you want to work in the development container from the editor.

Everything else (bitbake's host dependencies, the cross toolchain, Python,
Rust) is inside the container image. `kas-container` in the repository is the
upstream script from [siemens/kas](https://github.com/siemens/kas), vendored
and pinned to kas 5.5.

## Get the sources

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
```

## Choose the board

Each supported hardware has a board file in `kas/board/`. It is the one file
to name on the command line; it pulls in the layers, the machine and the
build targets:

| Hardware | Board file |
|---|---|
| Zyxel GS1900-8 (rev A1), also for [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) | `kas/board/zyxel-gs1900-8-a1.yml` |
| Albrecht RTL8382MI test switch (experimental) | `kas/board/albrecht-rtl8382mi-test.yml` |
| Raspberry Pi Zero with the [4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port) (experimental) | `kas/board/rpi-managed-switch-rpi0.yml` |
| 8 port switch emulated in QEMU x86-64 (experimental) | `kas/board/qemux86-64-switch.yml` |

!!! note
    Use the board file of your hardware. The examples on this page build the
    GS1900-8 (`kas/board/zyxel-gs1900-8-a1.yml`); for any other hardware,
    replace it with that hardware's board file. An image built for another
    board does not work on your switch.

The images land in `build/tmp/deploy/images/<board>/`, where `<board>` is the
file name without `.yml`.

## Build

The build always runs in a container, and there are two ways into it. The kas
commands are the same in both; only the name differs: `kas` inside the dev
container, `./kas-container` on the host.

### In VS Code, with the dev container

Open the checkout in VS Code and run **Dev Containers: Reopen in Container**.
VS Code builds the development image from `Dockerfile` (the upstream kas
image plus tools for working on the project) and mounts the checkout at
`/work`. `.devcontainer/devcontainer.json` already sets `KAS_BUILD_DIR`,
`DL_DIR` and `SSTATE_DIR`, so in a terminal there:

```sh
# Replace the board file with the one for your hardware.
kas build kas/board/zyxel-gs1900-8-a1.yml
```

### On the shell, with kas-container

`kas-container` runs kas in a Docker container by itself, so this is all a
build needs:

```sh
# Replace the board file with the one for your hardware.
./kas-container build kas/board/zyxel-gs1900-8-a1.yml
```

That uses the upstream `ghcr.io/siemens/kas/kas:5.5` image and puts
everything under `build/`. Two optional additions, both what the dev
container does too:

- **The development image** from `Dockerfile`: the upstream kas image plus
  tools for working *on* the project (a host Rust toolchain, `dtc`,
  `mkimage`, the JFFS2 tools, a Docker client for rtl838x-qemu). It builds
  the same artifacts. `kas-container` does not build images, so build it
  once, and again whenever `Dockerfile` changes. The tag has to match the
  vendored `kas-container` (5.5), or kas refuses to run.
- **Downloads and shared state outside `build/`**, so they survive deleting
  it and are shared between boards. `kas-container` creates the directories
  and mounts them into the container.

```sh
docker build -t ethernet-switch-os/kas:5.5 - < Dockerfile
export KAS_CONTAINER_IMAGE=ethernet-switch-os/kas:5.5
export KAS_BUILD_DIR=$PWD/build DL_DIR=$PWD/downloads SSTATE_DIR=$PWD/sstate-cache
./kas-container build kas/board/zyxel-gs1900-8-a1.yml
```

A first build takes hours. `kas/opt/sstate-mirror.yml` pulls oe-core's share
of it from the Yocto Project's CDN instead:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/sstate-mirror.yml
```

## Other kas commands

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

## What comes out

For the Zyxel GS1900-8, in `build/tmp/deploy/images/zyxel-gs1900-8-a1/`:

| File | What it is for |
|---|---|
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin` | TFTP boot image; the first install and recovery run entirely from RAM. |
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1-rt-loader.bin` | The same payload without the uImage header, for booting with `go` instead of `bootm`. |
| `ethernet-switch-os-swu-factory-zyxel-gs1900-8-a1.swu` | First install, uploaded from the TFTP initramfs. Writes `firmware`, wipes `data`. |
| `ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu` | Update in place. Rewrites `firmware`, keeps user data. |

The flash layout, the TFTP procedure and what to type at the stock bootloader
are in [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp)'s
README and summarized in [Installation](../installation/zyxel-gs1900-8.md#real-switch).

The Raspberry Pi switch is different: its board builds an SD card image,
`rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic.bz2` with its
`.wic.bmap`, which is the first install, and
`ethernet-switch-os-swu-upgrade-rpi-managed-switch-rpi0.swu` for updates.
There is no factory `.swu` and no TFTP image. The SD card layout and the A/B
update are in
[meta-rpi-managed-switch-bsp](https://github.com/AlbrechtL/meta-rpi-managed-switch-bsp)'s
README. Once the switch is up: `ssh cli@192.168.1.1` for the CLI,
`http://192.168.1.1/` for the status and settings page,
`http://192.168.1.1:8080` for SWUpdate. [First login](../installation/first-login.md)
takes it from there.

The QEMU switch builds a disk image in the same A/B shape, with EFI Boot
Guard instead of U-Boot: `qemu-switch-image-qemux86-64-switch.rootfs.wic`
with its `.wic.bmap`, and
`ethernet-switch-os-swu-upgrade-qemux86-64-switch.swu`. The build also leaves
the UEFI firmware (`ovmf.*.qcow2`) and a QEMU for running it; see
[QEMU x86-64 switch](../installation/qemu-x86-64.md).

## Building this documentation

The documentation is plain [MkDocs](https://www.mkdocs.org/) with the
Material theme, and needs only Docker too. Serve it on
<http://localhost:8000>, rebuilt on every change:

```sh
docker run --rm -it -p 8000:8000 -v $PWD:/docs squidfunk/mkdocs-material:9.7.7
```

Or build it into `site/` the way CI does, failing on warnings and broken
links:

```sh
docker run --rm -u $(id -u):$(id -g) -v $PWD:/docs squidfunk/mkdocs-material:9.7.7 build --strict
```

The image version matches `docs/requirements.txt`, which CI installs with
pip.
