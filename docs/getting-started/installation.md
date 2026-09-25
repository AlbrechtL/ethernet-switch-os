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

## Albrecht RTL8382MI test switch

This board (20 ports, experimental) uses the Realtek SDK bootloader, whose
prompt is `RTL838x#`. The first installation differs from the GS1900 in
two ways:

1. As delivered, the bootloader environment fails its CRC check. Save it
   once before anything else:

    ```text
    RTL838x# saveenv
    ```

2. Load the TFTP image to `0x8f000000`:

    ```text
    RTL838x# tftpboot 0x8f000000 192.168.1.12:ethernet-switch-os-initramfs-albrecht-rtl8382mi-test.bin
    RTL838x# bootm
    ```

Then continue with step 3 above. The factory `.swu` merges the original
`JFFS2_CFG` and `JFFS2_LOG` partitions into the configuration partition, and
both firmware slots (`RUNTIME1`, `RUNTIME2`) into one.

The port LEDs blink while the firmware is written and during a reboot.
DIP switch 6 is the reset switch: switched on and back off within 5 seconds
it reboots the switch, left on for 5 seconds or more it resets the
configuration to the factory default (see
[Maintenance](../maintenance.md#factory-reset)). DIP switches 1 to 5 have no
function yet; they are only logged.

!!! tip "Trying it without hardware"
    [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the
    switch and boots the same `initramfs` image. All of this guide works
    there as well.

Continue with [First login](first-login.md).
