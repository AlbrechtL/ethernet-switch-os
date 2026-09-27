# Raspberry Pi 4-port switch

The Raspberry Pi Zero with the
[4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port)
(experimental) has 4 Gigabit Ethernet ports on a Realtek RTL8367S switch
chip. Its board name is `rpi-managed-switch-rpi0`.

The images are in the `ethernet-switch-os-rpi-managed-switch-rpi0`
[download](download.md), or [build them yourself](../development/building.md).

## Hardware

The switch chip is a Realtek RTL8367S with four Gigabit front ports,
`lan1` … `lan4`. The Pi talks to it through an ENC28J60 SPI Ethernet
controller on SPI0, which is the link to the switch's CPU port, and manages
it over Realtek SMI, bit-banged on GPIO17 and GPIO27. The
[hardware repository](https://github.com/AlbrechtL/rpi-managed-switch-4-port)
has the schematics, the KiCad design and the known hardware issues. The
serial console is on the GPIO header (GPIO14 and GPIO15), 115200 8N1.

| Hardware | Status |
|---|---|
| HAT on a Raspberry Pi Zero (BCM2835, ARMv6), `rpi-managed-switch-rpi0` | Experimental |
| HAT on a Raspberry Pi Zero 2, 3, 4 or 5 | Not yet here: each needs a machine configuration of its own. The [OpenWrt fork](https://github.com/AlbrechtL/openwrt/tree/rpi_managed_switch) this port is based on already supports them. |

## First installation

The Pi is not installed over TFTP. Its first installation is an SD
card image, written with `dd`. The image comes compressed, so unpack it
first:

```sh
bunzip2 -k rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic.bz2
```

`-k` keeps the `.bz2` file. Find the SD card with `lsblk`, make sure none of
its partitions are mounted, then write the image to the whole device (for
example `/dev/sdX`, not a partition like `/dev/sdX1`):

```sh
sudo dd if=rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic \
    of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

!!! warning
    `dd` overwrites the target without asking. If `/dev/sdX` is the wrong
    device, its data is gone. Check the device name and size with `lsblk`
    before you press Enter.

Put the SD card into the Pi and power it on. It starts at `192.168.1.1`, as
described in [First login](first-login.md). Both firmware slots on the card
are identical at first; later updates use the `.swu` file (see
[Firmware update](../maintenance.md#firmware-update)).

!!! tip "Faster flashing"
    `bmaptool copy <image>.wic.bz2 /dev/sdX` unpacks and writes only the used
    blocks in one step, using the `.wic.bmap` file next to the image.

Continue with [First login](first-login.md).

## SD card layout and A/B boot

| Partition | Content |
|---|---|
| p1 `boot`, vfat, 64 MiB | Raspberry Pi firmware, `config.txt`, the device tree and overlays, U-Boot as `kernel.img`, `boot.scr`, `uboot.env`, `kernel-a.img`, `kernel-b.img` |
| p2, slot A, 256 MiB | squashfs root filesystem |
| p3, slot B, 256 MiB | squashfs root filesystem |
| p4 `data`, ext4, 256 MiB | The writable part of the root filesystem and the saved configuration; shared by both slots |

The firmware of a Pi Zero cannot switch between boot slots itself (that
needs a Pi 4 or later), so U-Boot does it. It starts the slot named by
`rootpart` in `uboot.env` (2 or 3) with that slot's kernel. An update
writes the other slot and its kernel, then sets `rootpart` to it. From then
on, U-Boot counts every start that is not confirmed. Once the system is up,
it confirms itself, and the count is cleared. After 3 unconfirmed starts,
U-Boot switches back to the previous slot. The kernel runs with `panic=5`,
so a slot that cannot mount its root filesystem fails over as well.

The device tree and the overlays in the boot partition are shared by both
slots and are not part of an update. See
[A/B updates](../maintenance.md#ab-updates) for how an update works.

## Known limitations

- Only the Pi Zero (1) has a machine configuration. On a Pi with onboard
  Ethernet, the ENC28J60 link would no longer be `eth0`.
- The link between the Pi and the switch chip is 10 Mbit/s half-duplex.
  Traffic to and from the Pi itself (management, the web page, an update)
  is correspondingly slow. Traffic between the front ports is forwarded by
  the switch chip and is not affected.
- `uboot.env` is a single copy on the vfat partition. A power cut while it
  is written can damage it. U-Boot then uses its default environment, which
  starts slot A.
- There is no watchdog yet. A slot that hangs without a kernel panic is not
  rolled back before a power cycle.

## QEMU

QEMU's [`raspi0` machine](https://www.qemu.org/docs/master/system/arm/raspi.html)
emulates the Pi Zero's BCM2835 SoC closely enough to boot the same kernel
and root filesystem as the real HAT — but not the HAT itself: QEMU does
not emulate the **RTL8367S switch chip or the ENC28J60 SPI Ethernet
controller** between it and the Pi. So there are no `lan1` … `lan4` and no
management link either, and the `clixon` backend, which talks to the
switch chip over that link, cannot start: no CLI, no RESTCONF, no web
pages. What comes up is the base Linux system on its own, on the serial
console — useful to try a kernel or root filesystem change without
hardware, not to try the switch. For that, use the [QEMU x86-64
switch](qemu-x86-64.md) or the [emulated GS1900-8](zyxel-gs1900-8.md#qemu)
instead.

!!! note "Tested on"
    This guide was tested with QEMU 10.2 on Ubuntu 26.04.

### 1. Install QEMU

```sh
sudo apt install qemu-system-arm device-tree-compiler
```

`device-tree-compiler` provides `fdtput`, needed in step 3.

### 2. Download and unpack the image

As in [First installation](#first-installation): download the
`ethernet-switch-os-rpi-managed-switch-rpi0` artifact (see
[Download](download.md)) and unpack it:

```sh
bunzip2 -k rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic.bz2
```

### 3. Get a kernel and device tree

On the real Pi Zero, the firmware in the boot partition (`bootcode.bin`,
`start.elf`) builds the device tree from `config.txt` and its overlays and
hands it, with `kernel.img`, to whatever runs next — U-Boot on this board.
QEMU's `raspi0` machine has no such firmware: it takes a kernel and a
device tree directly, with `-kernel` and `-dtb`. Pull both out of the
image's boot partition instead of going through U-Boot:

```sh
sudo mount -o loop,ro,offset=4194304,sizelimit=67108864 \
    rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic /mnt
cp /mnt/kernel-a.img /mnt/bcm2708-rpi-zero.dtb .
sudo umount /mnt
```

`kernel-a.img` is slot A's kernel (a zImage), and `bcm2708-rpi-zero.dtb`
the stock device tree for the Pi Zero. The offset and size are the boot
partition's, fixed by the [SD card layout](#sd-card-layout-and-ab-boot).

QEMU's emulation of the BCM2835's power/watchdog block is incomplete: the
kernel's `bcm2835-power` driver faults on it during boot and the system
hangs right after the console comes up. Disable that device tree node —
QEMU has nothing behind it to control anyway:

```sh
fdtput -t s bcm2708-rpi-zero.dtb /soc/watchdog@7e100000 status disabled
```

### 4. Start the switch

QEMU's emulated SD card also needs a power-of-two image size, so work on a
resized copy:

```sh
cp rpi-switch-image-rpi-managed-switch-rpi0.rootfs.wic sdcard.img
qemu-img resize -f raw sdcard.img 1G
```

This only pads the file with zeros after the existing partitions; nothing
inside them changes. To start over with the factory settings later, copy
and resize again.

```sh
qemu-system-arm -M raspi0 \
    -kernel kernel-a.img \
    -dtb bcm2708-rpi-zero.dtb \
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=squashfs rootwait init=/sbin/overlay-init panic=5" \
    -drive if=sd,format=raw,file=sdcard.img \
    -nographic
```

| Option | Meaning |
|---|---|
| `-M raspi0` | The Pi Zero: ARM1176JZF-S, 512 MB RAM. |
| `-kernel …`, `-dtb …` | The kernel and device tree from step 3. |
| `-append …` | The command line `boot.scr` would otherwise build: `console=` for the emulated PL011 UART, `root=` for slot A on the emulated SD card, and `panic=5` as on the real switch. |
| `-drive if=sd,format=raw,file=sdcard.img` | The SD card: the resized copy from this step. |
| `-nographic` | No window. The terminal becomes the switch's serial console. |

After a few seconds the login prompt appears. Log in as `root` (no
password); there is no point starting `clixon_cli`, since there is no
switch chip for it to talk to. **Ctrl-A x** quits QEMU.

A configuration change is written to the `data` partition inside
`sdcard.img` and is still there the next time you start with the same
file — though with no switch chip and no network link, there is little to
configure.

### What doesn't work

| | In QEMU |
|---|---|
| `lan1` … `lan4`, the RTL8367S | Not emulated: no switch ports, no VLANs, no spanning tree. |
| The ENC28J60 management link | Not emulated: the `clixon` backend cannot reach the switch chip and does not come up. |
| U-Boot, A/B slots, firmware updates | Skipped: QEMU boots `kernel-a.img` directly, so there is no bootloader to test an `.swu` update against. |
| GPIO SMI bit-banging, HAT peripherals | Not emulated. |

## For developers

The hardware support is ported from the OpenWrt branch
[`rpi_managed_switch`](https://github.com/AlbrechtL/openwrt/tree/rpi_managed_switch);
the layer,
[meta-rpi-managed-switch-bsp](https://github.com/AlbrechtL/meta-rpi-managed-switch-bsp),
has the table of what became of each OpenWrt patch. It builds on
[meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi). A build
leaves more files than the SD card image: `rpi-switch-image-rpi-managed-switch-rpi0.rootfs.squashfs-xz` is
the content of one slot, and `zImage-rpi-managed-switch-rpi0.bin` the kernel that is installed as
`kernel-a.img` and `kernel-b.img`. To build, see
[Building the firmware](../development/building.md).
