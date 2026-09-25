# Ethernet Switch OS

!!! warning "Proof of concept"
    Ethernet Switch OS is a proof of concept, built with the help of AI. It has
    not been thoroughly reviewed or hardened. Do not use it in production.

**Ethernet Switch OS** is a small Linux system for managed Ethernet switches.
The whole configuration of the switch is described by
[YANG](https://datatracker.ietf.org/doc/html/rfc7950) data models, mostly
[OpenConfig](https://www.openconfig.net/). You can change it in three ways:

| Interface | Where | What for |
|---|---|---|
| **CLI** | `ssh cli@<switch-ip>` | Interactive configuration. Described in this guide. |
| **RESTCONF** | `http://<switch-ip>/restconf` | Configuration by scripts and tools. [Coming later](restconf/index.md). |
| **Web page** | `http://<switch-ip>/` | Status and settings: system, management address, ports, VLANs, spanning tree, SNMP. See [Web UI](web-ui.md). |

The CLI and RESTCONF work on the same configuration. A change made through
one is visible in the other.

## What the switch can do

- **VLANs**: IEEE 802.1Q access and trunk ports, or simple port-based groups
  without tags.
- **Management IP address**: static IPv4 addresses and/or a DHCP client, on
  one or more VLANs.
- **Spanning tree**: STP, RSTP and MSTP.
- **SNMP**: a read-only SNMPv3 agent (system group, IF-MIB, BRIDGE-MIB,
  Q-BRIDGE-MIB, RSTP-MIB).
- **Firmware update** through a web page, `curl` or the `swupdate` command,
  with the configuration kept. There is only one firmware slot: read
  [Firmware update](getting-started/firmware-update.md) before the first update.

What it cannot do (yet) is listed under [Limitations](limitations.md).
Read that page before you rely on the switch for anything.

## Supported hardware

| Hardware | SoC | Ports | Status | Board file |
|---|---|---|---|---|
| Zyxel GS1900-8 (rev A1) | Realtek RTL8380 | `lan1` … `lan8`, Gigabit Ethernet | Supported. See [Installation](getting-started/installation.md). | `zyxel-gs1900-8-a1` |
| Albrecht RTL8382MI test switch | Realtek RTL8382M | 20 × Gigabit Ethernet | Experimental. See [Installation](getting-started/installation.md#albrecht-rtl8382mi-test-switch). | `albrecht-rtl8382mi-test` |
| Raspberry Pi Zero with the [4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port) | Realtek RTL8367S, Broadcom BCM2835 | 4 × Gigabit Ethernet | Experimental. See [Installation](getting-started/installation.md#raspberry-pi-switch). | `rpi-managed-switch-rpi0` |
| Zyxel GS1900-8 emulated in QEMU ([rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu)) | Realtek RTL8380 (emulated) | `lan1` … `lan8` | Supported. Same image as the real switch; no flash, so nothing is kept across reboots. See [QEMU: Zyxel GS1900-8](getting-started/installation.md#qemu-zyxel-gs1900-8). | `zyxel-gs1900-8-a1` |
| Switch emulated in QEMU x86-64 | x86-64 (emulated) | `lan1` … `lan8` | Experimental. A board of its own, with two firmware slots and rollback; the configuration is kept on a virtual disk. See [QEMU: x86-64 switch](getting-started/installation.md#qemu-x86-64-switch). | `qemux86-64-switch` |

The board file is what you name when you [build the firmware](development/building.md).

## Where to start

1. [Installation](getting-started/installation.md): getting Ethernet Switch OS
   onto the switch, or [QEMU: Zyxel GS1900-8](getting-started/installation.md#qemu-zyxel-gs1900-8) or the
   [QEMU: x86-64 switch](getting-started/installation.md#qemu-x86-64-switch) to try it without one.
2. [First login](getting-started/first-login.md): factory settings and how to
   connect.
3. [CLI basics](cli/basics.md): how the CLI works. Read this before the task
   chapters.
4. The task chapters: [management IP address](cli/ip.md),
   [VLANs](cli/vlans.md), [ports](cli/interfaces.md),
   [spanning tree](cli/spanning-tree.md), [SNMP](snmp/index.md),
   [system](cli/system.md).
