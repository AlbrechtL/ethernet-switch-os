# Raspberry Pi switch

The Raspberry Pi Zero with the
[4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port)
(experimental) has 4 Gigabit Ethernet ports on a Realtek RTL8367S switch
chip. Its board name is `rpi-managed-switch-rpi0`.

The images are in the `ethernet-switch-os-rpi-managed-switch-rpi0`
[download](download.md), or [build them yourself](../development/building.md).

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

