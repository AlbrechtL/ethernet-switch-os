# Download

!!! note "No releases yet"
    Ethernet Switch OS has no releases so far. There are no versioned
    downloads, and there is no release page.

Instead, every run of the
[build workflow](https://github.com/AlbrechtL/ethernet-switch-os/actions)
builds the firmware for each board and keeps the images as artifacts of
that run. They are built from the current `master` of this repository and
of every layer.

## Downloading the images

1. Open the [Actions](https://github.com/AlbrechtL/ethernet-switch-os/actions)
   page of the repository and choose the **Build images** workflow.
2. Open a recent run with a green check mark. Runs on `master` are the
   ones to use; runs of pull requests contain changes that are not merged
   yet.
3. Scroll down to **Artifacts** and download the one for your board. It is
   a `.zip` file with the images inside.

You have to be logged in to GitHub to download artifacts. GitHub deletes
them after some time (90 days by default), so an old run may have none
left.

| Artifact | Board |
|---|---|
| `ethernet-switch-os-zyxel-gs1900-8-a1` | [Zyxel GS1900-8](zyxel-gs1900-8.md) (rev A1) |
| `ethernet-switch-os-albrecht-rtl8382mi-test` | [Albrecht RTL8382MI test switch](albrecht-rtl8382mi-test.md) |
| `ethernet-switch-os-qemux86-64-switch` | [QEMU x86-64 switch](qemu-x86-64.md) |

The [Raspberry Pi switch](raspberry-pi.md) is not built by CI. Its image
has to be [built yourself](../development/building.md).

## Files

Each artifact contains the files the board needs, `<board>` being the name
in the artifact's name:

| File | Boards | Used for |
|---|---|---|
| `ethernet-switch-os-initramfs-<board>.bin` | Zyxel, Albrecht test switch | Booted over TFTP from the original bootloader with `bootm`. Runs entirely from RAM; used for the first installation and for recovery. |
| `ethernet-switch-os-initramfs-<board>-rt-loader.bin` | Zyxel, Albrecht test switch | The same image without the uImage header, for booting with `go` instead of `bootm`. |
| `ethernet-switch-os-swu-factory-<board>.swu` | Zyxel, Albrecht test switch | First installation. Uploaded while the TFTP image runs. Writes the firmware and **erases** the configuration partition. |
| `ethernet-switch-os-swu-upgrade-<board>.swu` | All | [Update](../maintenance.md#firmware-update) of an installed switch. Writes the firmware and **keeps** the configuration. |
| `qemu-switch-image-<board>.rootfs.wic`, `.wic.bmap` | QEMU x86-64 switch | The virtual disk. |

Next to the images, every artifact describes the firmware it contains:

| File | Boards | Contents |
|---|---|---|
| `<image>-<board>.rootfs.spdx.json` | All | Software bill of materials (SBOM) of the root filesystem, in SPDX 3.0 JSON, as written by Yocto: every package with its version, license and source. |
| `rtl83xx-image-initramfs-<board>.spdx.json` | Zyxel, Albrecht test switch | The same for the initramfs built into the kernel. |
| `ethernet-switch-os-licenses-<board>.tar.gz` | All | The open-source licenses: a manifest of every package and its license, the license texts of every component (the kernel and the bootloader included), and those of the Rust crates in the clixon backend plugin. |
| `ethernet-switch-os-yang-<board>.tar.gz` | All | The YANG modules the switch loads, for RESTCONF and NETCONF clients: `yang/clixon-switch/` (the switch's own, OpenConfig and IETF modules, and the MIB translations) and `yang/clixon/` (clixon's own modules). |
| `ethernet-switch-os-mibs-<board>.tar.gz` | All | The SNMP MIBs the agent serves (SNMPv2-MIB, IF-MIB, BRIDGE-MIB, Q-BRIDGE-MIB, RSTP-MIB, the SNMPv3 MIBs) and the MIBs they import, for loading into a network management system. |

## Building it yourself

None of the installation pages need a firmware build of your own: the
downloaded images are enough. The one thing to compile is the emulator for
the [Zyxel GS1900-8 in QEMU](zyxel-gs1900-8.md#qemu), because mainline
QEMU does not have its RTL8380 machine. The
[QEMU x86-64 switch](qemu-x86-64.md) runs in the QEMU of your Linux
distribution.

To build the images on your own computer, see
[Building the firmware](../development/building.md).
