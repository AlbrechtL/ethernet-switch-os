# Installation

Ethernet Switch OS replaces the switch's original firmware. The first
installation is done once, over the serial console and TFTP. After that,
updates go through a web page or the `swupdate` command (see
[Firmware update](firmware-update.md)).

## Images

A build (see the
[README](https://github.com/AlbrechtL/ethernet-switch-os#building)) produces
these files. The CI also publishes them as an artifact of each
[build run](https://github.com/AlbrechtL/ethernet-switch-os/actions).

| File | Used for |
|---|---|
| `ethernet-switch-os-initramfs-<board>.bin` | Booted over TFTP from the original bootloader. Runs entirely from RAM; used for the first installation and for recovery. |
| `ethernet-switch-os-swu-factory-<board>.swu` | First installation. Uploaded while the TFTP image runs. Writes the firmware and **erases** the configuration partition. |
| `ethernet-switch-os-swu-upgrade-<board>.swu` | Update of an installed switch. Writes the firmware and **keeps** the configuration. |

## First installation, in short

1. Connect a serial console (115200 8N1) to the switch, and a PC with a TFTP
   server to one of its ports.
2. Stop the original bootloader and boot the `initramfs` image over TFTP.
3. The switch comes up at `192.168.1.1`, running from RAM. Open
   `http://192.168.1.1:8080` and upload the **factory** `.swu`.
4. Reboot. The switch now starts Ethernet Switch OS from flash.

The exact steps (serial settings, bootloader commands, flash layout, how to
go back to the original firmware) are in the
[meta-rtl83xx-bsp README](https://github.com/AlbrechtL/meta-rtl83xx-bsp).

!!! tip "Trying it without hardware"
    [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the
    switch and boots the same `initramfs` image. All of this guide works
    there as well.

Continue with [First login](first-login.md).
