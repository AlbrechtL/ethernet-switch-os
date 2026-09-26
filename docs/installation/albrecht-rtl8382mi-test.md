# Albrecht RTL8382MI test switch

The Albrecht RTL8382MI test switch (experimental) has 20 Gigabit Ethernet
ports on a Realtek RTL8382M switch chip. Its board name is
`albrecht-rtl8382mi-test`.

## First installation

Like the [Zyxel GS1900-8](zyxel-gs1900-8.md#first-installation-in-short),
it is installed once over the serial console and TFTP, and updated through
the [firmware update](../maintenance.md#firmware-update) page after that.
You need the `initramfs` image and the **factory** `.swu` from the
`ethernet-switch-os-albrecht-rtl8382mi-test` artifact, see
[Download](download.md).

The board uses the Realtek SDK bootloader, whose prompt is `RTL838x#`. The
first installation differs from the GS1900 in two ways:

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

Then continue with step 3 of the
[Zyxel GS1900-8](zyxel-gs1900-8.md#first-installation-in-short)
installation. The factory `.swu` merges the original `JFFS2_CFG` and
`JFFS2_LOG` partitions into the configuration partition, and both firmware
slots (`RUNTIME1`, `RUNTIME2`) into one.

Continue with [First login](first-login.md).

## LEDs and DIP switches

The port LEDs blink while the firmware is written and during a reboot.
DIP switch 6 is the reset switch: switched on and back off within 5 seconds
it reboots the switch, left on for 5 seconds or more it resets the
configuration to the factory default (see
[Maintenance](../maintenance.md#factory-reset)). DIP switches 1 to 5 have no
function yet; they are only logged.

!!! tip "Trying it without hardware"
    [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the
    Zyxel GS1900-8, a switch of the same family, see
    [Zyxel GS1900-8 in QEMU](zyxel-gs1900-8.md#qemu).

