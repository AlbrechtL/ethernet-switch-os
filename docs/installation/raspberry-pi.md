# Raspberry Pi switch

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
| HAT on a Raspberry Pi Zero 2, 3 or 4 | Not yet: each needs a machine configuration of its own. The HAT itself supports them. |
| HAT on a Raspberry Pi 5 | Not planned for now. The HAT does not work with OpenWrt on a Pi 5 either ([openwrt/openwrt#18034](https://github.com/openwrt/openwrt/issues/18034)). |

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
