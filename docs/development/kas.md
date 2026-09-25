# Layers and kas files

## Layers

| Layer | Repository | Branch |
|---|---|---|
| `meta` | [openembedded-core](https://git.openembedded.org/openembedded-core) | wrynose |
| `meta-poky` | [meta-yocto](https://git.yoctoproject.org/meta-yocto) | wrynose |
| `meta-oe`, `meta-python`, `meta-networking` | [meta-openembedded](https://github.com/openembedded/meta-openembedded) | wrynose |
| `meta-swupdate` | [meta-swupdate](https://github.com/sbabic/meta-swupdate) | wrynose |
| `meta-rtl83xx-bsp` | [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp) | master |
| `meta-raspberrypi` | [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi) | wrynose |
| `meta-rpi-managed-switch-bsp` | [meta-rpi-managed-switch-bsp](https://github.com/AlbrechtL/meta-rpi-managed-switch-bsp) | master |
| `meta-efibootguard` | [meta-efibootguard](https://github.com/siemens/meta-efibootguard) | master (the wrynose one) |
| `meta-qemu-switch-bsp` | [meta-qemu-switch-bsp](https://github.com/AlbrechtL/meta-qemu-switch-bsp) | master |
| `meta-ethernet-switch-os` | [meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os) | master |

Plus [bitbake](https://git.openembedded.org/bitbake) (branch `2.18`), which is
the build tool rather than a layer. A board uses only the BSP layers of its
own hardware: `meta-rtl83xx-bsp`, `meta-raspberrypi` with
`meta-rpi-managed-switch-bsp`, or `meta-efibootguard` with
`meta-qemu-switch-bsp`.

Branch tips, deliberately: every layer uses the current head of its branch in
every build and every CI run, and kas warns about that on every invocation.
If a reproducible build is ever needed,
`./kas-container lock kas/board/<board>.yml` writes a lock file next to the
board file, which kas then picks up on its own; `--update` refreshes it.

`meta-python` is in the list only because `meta-networking` names it in
`LAYERDEPENDS`; nothing here builds from it. The Yocto Project retired the
combined `poky` repository after *walnascar*, which is why oe-core, meta-yocto
and bitbake are three separate checkouts.

`rtl838x-qemu` is not a layer. It is built by a recipe in `meta-rtl83xx-bsp`
when it is needed, see [Testing and CI](testing.md).

## The kas files

```
kas/
├── base.yml                      bitbake, openembedded-core, meta-poky
├── os.yml                        meta-ethernet-switch-os and its dependencies,
│                                 and the ethernet-switch-os distro
├── bsp/
│   ├── rtl83xx.yml               meta-rtl83xx-bsp
│   ├── rpi-managed-switch.yml    meta-raspberrypi, meta-rpi-managed-switch-bsp
│   └── qemu-switch.yml           meta-efibootguard, meta-qemu-switch-bsp
├── board/                        base + bsp + os, MACHINE, targets, artifacts
│   ├── zyxel-gs1900-8-a1.yml
│   ├── albrecht-rtl8382mi-test.yml
│   ├── rpi-managed-switch-rpi0.yml
│   └── qemux86-64-switch.yml
└── opt/
    ├── ci.yml                    rm_work, for a disk-bound runner
    ├── sstate-mirror.yml         pull oe-core's shared state from the CDN
    ├── local-layers.yml          stop kas resetting the layers/ checkouts
    ├── local-layers-rpi-managed-switch.yml   the same for the Raspberry Pi boards
    ├── local-layers-qemu-switch.yml          the same for the QEMU switch
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

## Adding a board

If the BSP already has a machine configuration for it, a board file is all it
takes: copy `kas/board/zyxel-gs1900-8-a1.yml`, change `machine:` and the
artifact paths, and add the name to the `board:` matrix in
`.github/workflows/build.yml`. For a board the BSP does not know yet, the
machine `.conf` (and usually a device tree) goes into `meta-rtl83xx-bsp`
first.

## Adding a BSP

A second hardware family is a new file under `kas/bsp/`, listing that BSP
layer and nothing else, plus board files that include it instead of
`kas/bsp/rtl83xx.yml`. Nothing in `base.yml` or `os.yml` changes:
`meta-ethernet-switch-os` deliberately does not depend on the BSP, and reaches
into it through `BBFILES_DYNAMIC` only where the BSP is present. Making that
cheap is the reason this repository exists.

## Working on a layer

kas checks the layers out under `layers/` as ordinary git clones, but it owns
them: on every invocation it resets the local branch to the upstream one. A
commit made in `layers/` and not yet pushed is **dropped from the branch** by
the next build. It survives in the reflog, but nothing points at it any more.

So while working on a layer, add the fragment that tells kas to keep its
hands off the project's own layers:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/local-layers.yml
```

Then `layers/meta-ethernet-switch-os` and `layers/meta-rtl83xx-bsp` are yours
to edit, commit and push, and nothing moves underneath. For the Raspberry Pi
boards use `kas/opt/local-layers-rpi-managed-switch.yml` instead, which does
the same for `meta-ethernet-switch-os` and `meta-rpi-managed-switch-bsp`: kas
would turn the `meta-rtl83xx-bsp` entry of `local-layers.yml`, which no Pi
board file defines, into a layer at the root of this repository. The QEMU
switch has `kas/opt/local-layers-qemu-switch.yml` for the same reason.
Everything else still follows its branch tip. Without the fragment, work in a
clone of your own and let kas fetch from the remote.

For `clixon-switch-rs`, whose source bitbake fetches from git, use devtool:

```sh
./kas-container shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/devtool.yml
devtool modify clixon-switch
# edit build/workspace/sources/clixon-switch, then
bitbake ethernet-switch-os-swu-upgrade
```

`kas/opt/devtool.yml` is needed because kas rewrites `bblayers.conf` on every
invocation and would otherwise drop the workspace layer again.

## Relation to the earlier build setup

This replaces a `bitbake-setup` tree in which `bblayers.conf` held absolute
paths, machine and distro were selected by mutable `bitbake-config-build`
state inside the build directory, and the layer revisions were maintained by
hand in three different places. It built one board at a time, and adding a
second one meant editing that state. Here a board is a file.
