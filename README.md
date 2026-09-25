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
general-purpose Linux installation.

## Documentation

Everything about using, building and developing Ethernet Switch OS is in the
**[documentation](https://albrechtl.github.io/ethernet-switch-os/)**. Its
source is in [`docs/`](docs/).

| I want to … | Go to |
|---|---|
| Install it on a switch or try it in QEMU | [Getting started](https://albrechtl.github.io/ethernet-switch-os/getting-started/installation/) |
| Configure the switch | [CLI](https://albrechtl.github.io/ethernet-switch-os/cli/basics/), [Web UI](https://albrechtl.github.io/ethernet-switch-os/web-ui/), [RESTCONF](https://albrechtl.github.io/ethernet-switch-os/restconf/) |
| Build the firmware | [Building the firmware](https://albrechtl.github.io/ethernet-switch-os/development/building/) |
| Know what does not work yet | [Limitations](https://albrechtl.github.io/ethernet-switch-os/reference/limitations/) |

## Supported hardware

The full list, with the SoC, the status and the board file of each, is in
[Supported hardware](https://albrechtl.github.io/ethernet-switch-os/#supported-hardware).

- [Zyxel GS1900-8](https://albrechtl.github.io/ethernet-switch-os/getting-started/installation/) (rev A1), Realtek RTL8380
- [Albrecht RTL8382MI test switch](https://albrechtl.github.io/ethernet-switch-os/getting-started/installation/#albrecht-rtl8382mi-test-switch) (experimental)
- [Raspberry Pi Zero with the 4-port managed switch HAT](https://albrechtl.github.io/ethernet-switch-os/getting-started/installation/#raspberry-pi-switch) (experimental)
- [Zyxel GS1900-8 emulated in QEMU](https://albrechtl.github.io/ethernet-switch-os/getting-started/qemu/) with rtl838x-qemu
- [8 port switch emulated in QEMU x86-64](https://albrechtl.github.io/ethernet-switch-os/getting-started/qemu-x86-64/) (experimental)

## Components and repositories

This repository is the build entry point and contains no recipes of its own.
It holds [kas](https://kas.readthedocs.io/) configuration files that describe,
per board, which Yocto layers to check out and how to configure them. The
interesting parts live in repositories of their own. See
[Layers and kas files](https://albrechtl.github.io/ethernet-switch-os/development/kas/)
for the branches and how the layers fit together.

| Repository | Role |
|---|---|
| [clixon-switch-rs](https://github.com/AlbrechtL/clixon-switch-rs) | The [clixon](https://www.clicon.org/) backend plugin, in Rust. Applies an OpenConfig configuration to the kernel: DSA ports in a VLAN-aware bridge, routed VLAN interfaces, spanning tree via mstpd, a read-only SNMPv3 agent. Built by a recipe in `meta-ethernet-switch-os`, not checked out by kas. |
| [meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os) | The distro and the userspace: the `ethernet-switch-os` distro (poky-tiny plus sysvinit), clixon with the plugin, dropbear, SWUpdate with its two `.swu` images, and the status and settings web UI. |
| [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp) | The hardware: Realtek RTL83xx switch SoCs. Machine configurations, the patched kernel and its device trees, `rt-loader`, and the flash image types. The kernel patches (Realtek SoC support, device trees, MTD split) are taken from [OpenWrt](https://openwrt.org/) — many thanks to the OpenWrt developers for their work, without which this would not exist. Boots on its own, without the OS layer. |
| [meta-rpi-managed-switch-bsp](https://github.com/AlbrechtL/meta-rpi-managed-switch-bsp) | The hardware: the [4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port) for the Raspberry Pi, on top of [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi). Machine configurations, the kernel with the switch's device tree overlay and OpenWrt's rtl8365mb backports, and an A/B SD card image with U-Boot. Ported from [its OpenWrt branch](https://github.com/AlbrechtL/openwrt/tree/rpi_managed_switch). Boots on its own, without the OS layer. |
| [meta-qemu-switch-bsp](https://github.com/AlbrechtL/meta-qemu-switch-bsp) | The hardware: an 8 port switch emulated on QEMU x86-64, on top of oe-core's `qemux86-64` machine. UEFI (OVMF) with [EFI Boot Guard](https://github.com/siemens/efibootguard) from [meta-efibootguard](https://github.com/siemens/meta-efibootguard), virtio-net front ports, and an A/B disk image. Boots on its own, without the OS layer. |
| [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) | Emulates an RTL838x switch, for booting and testing a built image without hardware. Frames really cross between the eight emulated front ports, so VLANs and spanning tree can be exercised. Built by `qemu-rtl838x-native` in `meta-rtl83xx-bsp`, not checked out by kas. |

## Contributing

Bug reports, documentation fixes, support for new hardware and code are
welcome. Send a change to the repository that owns the code (see the table
above), as a pull request against its `master` branch, and build the board you
changed first. The
[contributing guide](https://albrechtl.github.io/ethernet-switch-os/development/contributing/)
has the details.

## License

[MIT](LICENSE)
