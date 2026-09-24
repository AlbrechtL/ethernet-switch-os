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
| **Web page** | `http://<switch-ip>/` | Read-only status: system, management address, ports, VLANs. See [Web UI](web-ui.md). |

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

What it cannot do (yet) is listed under [Limitations](reference/limitations.md).
Read that page before you rely on the switch for anything.

## Supported hardware

| Hardware | Ports | Notes |
|---|---|---|
| Zyxel GS1900-8 (rev A1) | `lan1` … `lan8`, Gigabit Ethernet | |
| Zyxel GS1900-8 emulated in QEMU ([rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu)) | `lan1` … `lan8` | Same image as the real switch; no flash, so nothing is kept across reboots. See [Running in QEMU](getting-started/qemu.md). |

## Where to start

1. [Installation](getting-started/installation.md): getting Ethernet Switch OS
   onto the switch, or [Running in QEMU](getting-started/qemu.md) to try it
   without one.
2. [First login](getting-started/first-login.md): factory settings and how to
   connect.
3. [CLI basics](cli/basics.md): how the CLI works. Read this before the task
   chapters.
4. The task chapters: [management IP address](cli/ip.md),
   [VLANs](cli/vlans.md), [ports](cli/interfaces.md),
   [spanning tree](cli/spanning-tree.md), [SNMP](cli/snmp.md),
   [system](cli/system.md).
