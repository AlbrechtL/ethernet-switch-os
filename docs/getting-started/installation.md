# Installation

How you get Ethernet Switch OS onto a switch depends on the hardware. Pick
your board:

| Hardware | First installation |
|---|---|
| [Zyxel GS1900-8](#zyxel-gs1900-8) | Serial console and TFTP |
| [Albrecht RTL8382MI test switch](#albrecht-rtl8382mi-test-switch) | Serial console and TFTP |
| [Raspberry Pi switch](#raspberry-pi-switch) | SD card image |
| [QEMU: Zyxel GS1900-8](#qemu-zyxel-gs1900-8) | None, emulated |
| [QEMU: x86-64 switch](#qemu-x86-64-switch) | None, emulated |

On the real switches, Ethernet Switch OS replaces the original firmware. The
first installation is done once. After that, updates go through a web page
or the `swupdate` command (see [Firmware update](firmware-update.md)).

## Images

A build (see [Building the firmware](../development/building.md)) produces
these files. The CI also publishes them as an artifact of each
[build run](https://github.com/AlbrechtL/ethernet-switch-os/actions).

| File | Used for |
|---|---|
| `ethernet-switch-os-initramfs-<board>.bin` | Booted over TFTP from the original bootloader. Runs entirely from RAM; used for the first installation and for recovery. |
| `ethernet-switch-os-swu-factory-<board>.swu` | First installation. Uploaded while the TFTP image runs. Writes the firmware and **erases** the configuration partition. |
| `ethernet-switch-os-swu-upgrade-<board>.swu` | Update of an installed switch. Writes the firmware and **keeps** the configuration. |

## Zyxel GS1900-8

The GS1900-8 (rev A1) is installed over the serial console and TFTP.

### First installation, in short

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

Then continue with step 3 of the [Zyxel GS1900-8](#zyxel-gs1900-8) installation. The factory `.swu` merges the original
`JFFS2_CFG` and `JFFS2_LOG` partitions into the configuration partition, and
both firmware slots (`RUNTIME1`, `RUNTIME2`) into one.

The port LEDs blink while the firmware is written and during a reboot.
DIP switch 6 is the reset switch: switched on and back off within 5 seconds
it reboots the switch, left on for 5 seconds or more it resets the
configuration to the factory default (see
[Maintenance](maintenance.md#factory-reset)). DIP switches 1 to 5 have no
function yet; they are only logged.

!!! tip "Trying it without hardware"
    [rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the
    switch and boots the same `initramfs` image, see
    [QEMU: Zyxel GS1900-8](#qemu-zyxel-gs1900-8). All of this guide works
    there as well.

## Raspberry Pi switch

The Raspberry Pi Zero with the
[4-port managed switch HAT](https://github.com/AlbrechtL/rpi-managed-switch-4-port)
(experimental) is not installed over TFTP. Its first installation is an SD
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
[Firmware update](firmware-update.md)).

!!! tip "Faster flashing"
    `bmaptool copy <image>.wic.bz2 /dev/sdX` unpacks and writes only the used
    blocks in one step, using the `.wic.bmap` file next to the image.

Continue with [First login](first-login.md).

## QEMU: Zyxel GS1900-8

You can try Ethernet Switch OS without a switch.
[rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the Zyxel
GS1900-8, and it boots the same `initramfs` image that is used for the first
installation on real hardware. The CLI, RESTCONF, the web pages, VLANs,
the DHCP client, spanning tree and SNMP all work as on the real switch.

Everything runs in Docker containers. You need Docker, git and a Linux host.

### 1. Build the image and the emulator

The GS1900-8 is built as usual (see
[Building the firmware](../development/building.md)), with
`kas/opt/rtl838x-qemu.yml` appended. That also builds QEMU with the RTL8380
machine, so nothing else has to be installed:

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml
```

### 2. Boot the switch

```sh
./kas-container --runtime-args "--network=host" \
    shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml \
    -c /work/scripts/mips-rtl838x-qemu
```

The terminal shows the serial console, which is what you would see on the
real switch's console port. After about 20 seconds the login prompt
appears. Log in as `root` (no password) and start the CLI with
`clixon_cli`, or log in as `cli`. **Ctrl-A x** quits QEMU. The update
service writes its log to the console as well, so its lines can appear
between yours; press Enter to get a fresh prompt.

The emulated `lan1` is connected to QEMU's user network, and the switch's
factory address `192.168.1.1` is forwarded to your computer:

| On your computer | On the switch |
|---|---|
| `ssh -p 2222 cli@127.0.0.1` | The CLI |
| `ssh -p 2222 root@127.0.0.1` | A root shell |
| `http://127.0.0.1:8000/` | [Status page](../web-ui.md) |
| `http://127.0.0.1:8000/restconf/` | RESTCONF |
| `http://127.0.0.1:8080/` | [Firmware update page](firmware-update.md) |
| UDP `127.0.0.1:1161` | [SNMP](../snmp/index.md), e.g. `snmpwalk ... 127.0.0.1:1161 1.3.6.1.2.1.1` |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`. The ports only listen on `127.0.0.1`;
`--network=host` is what makes them appear on your computer.

QEMU's user network also has a DHCP server. With
[DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the switch gets
`192.168.1.100`, the gateway `192.168.1.254` and the DNS server `192.168.1.244`.

### 3. Connect switches

`lan2` … `lan8` can be cabled to the ports of other emulated switches. Start
each switch in a terminal of its own, with its own number in `SWITCH` and the
same list of cables in `CABLES`. A cable is written as `switch:port-switch:port`;
here `lan2` of switch 0 goes to `lan2` of switch 1:

```sh
# Terminal 1
./kas-container --runtime-args "--network=host" \
    shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml \
    -c "SWITCH=0 CABLES='0:2-1:2' /work/scripts/mips-rtl838x-qemu"

# Terminal 2
./kas-container --runtime-args "--network=host" \
    shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml \
    -c "SWITCH=1 CABLES='0:2-1:2' /work/scripts/mips-rtl838x-qemu"
```

Cabled switches share VLAN 1, so they cannot all keep the factory address
`192.168.1.1`: your SSH session or browser would end up on whichever switch
answers first. A cabled switch number N is therefore reached at
`192.168.1.N+1`: switch 0 keeps `192.168.1.1`, switch 1 needs `192.168.1.2`,
and so on. The emulated switch has no flash, so it forgets the address when
it stops: after every boot, log in as `cli` on the console of every switch
except switch 0 and give it its address, here for switch 1:

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config ip 192.168.1.2
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config prefix-length 24
switch> delete interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1
switch> commit
```

Each switch has its own forwarded ports on your computer:

| Switch | Address | SSH | Web pages, RESTCONF | Firmware update | SNMP (UDP) |
|---|---|---|---|---|---|
| `SWITCH=0` | `192.168.1.1` | 2222 | 8000 | 8080 | 1161 |
| `SWITCH=1` | `192.168.1.2` | 2232 | 8010 | 8090 | 1171 |
| `SWITCH=N` | `192.168.1.N+1` | 2222 + 10·N | 8000 + 10·N | 8080 + 10·N | 1161 + 10·N |

A switch without cables is always reached at `192.168.1.1`. To forward to
another address, add `ADDRESS=...` in front of `/work/scripts/mips-rtl838x-qemu`.

!!! note
    With the factory settings, all ports of a switch are in VLAN 1 and
    spanning tree is off. Two cables between two switches, such as
    `CABLES='0:2-1:2 0:3-1:3'`, are then a loop that floods both switches
    until neither answers. Turn on [spanning tree](../cli/spanning-tree.md)
    on the first switch before you start the second one -- after every
    boot, since the emulated switch forgets it. Or connect only one cable.

Start the two terminals a few seconds apart: two `kas-container` commands
that start at the same moment can collide while checking out `layers/`.

### What is different from the real switch

| | In QEMU |
|---|---|
| Configuration after a reboot | **Lost.** The emulated switch has no flash memory. `save` works, but the next boot starts with the factory settings again. |
| Firmware update | Uploading works, and the file is checked, but writing fails (`Wrong MTD device in description: firmware`). The TFTP image runs the factory update anyway. |
| Cabled ports | All eight ports have a link. `lan2` … `lan8` lead to another emulated switch, or nowhere when `CABLES` does not name them. |
| Port counters | Always 0, in the CLI and on the status page. |
| MSTP | Only the common spanning tree is emulated, so MSTP instances have no effect on forwarding. STP and RSTP work. |
| Reboot | `reboot` ends QEMU. Start it again for a fresh switch with the factory settings. |

## QEMU: x86-64 switch

The QEMU x86-64 switch is an emulated 8 port switch with a board of its own.
It is not a copy of any real switch; it is a virtual PC whose front ports are
virtual network cards. Unlike [QEMU: Zyxel GS1900-8](#qemu-zyxel-gs1900-8), which emulates the
Zyxel GS1900-8, it:

- boots in seconds, because it runs at full speed with KVM,
- keeps its configuration on a virtual disk, and
- has two firmware slots (A/B) with automatic rollback, so
  [firmware updates](firmware-update.md) work as they will on hardware that
  has two slots.

Everything runs in Docker containers. You need Docker, git and a Linux host;
KVM (`/dev/kvm`) makes it fast but is not required.

!!! warning "Experimental"
    The QEMU x86-64 switch is new. Use it for trying things out and for
    testing, not as a production switch.

### 1. Build it

The board is built like any other (see
[Building the firmware](../development/building.md)). The
build also produces the UEFI firmware and a QEMU to run it with, so nothing
else has to be installed:

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
./kas-container build kas/board/qemux86-64-switch.yml
```

### 2. Start the switch

```sh
./kas-container --kvm --runtime-args "--network=host" \
    shell kas/board/qemux86-64-switch.yml -c /work/scripts/x86-64-q35-qemu
```

The terminal shows the serial console. After a few seconds the login prompt
appears. Log in as `root` (no password) and start the CLI with `clixon_cli`,
or log in as `cli`. **Ctrl-A x** quits QEMU.

Port `lan1` is connected to QEMU's user network, and the switch's factory
address `192.168.1.1` is forwarded to your computer:

| On your computer | On the switch |
|---|---|
| `ssh -p 2222 cli@127.0.0.1` | The CLI |
| `ssh -p 2222 root@127.0.0.1` | A root shell |
| `http://127.0.0.1:8000/` | [Status page](../web-ui.md) |
| `http://127.0.0.1:8000/restconf/` | RESTCONF |
| `http://127.0.0.1:8080/` | [Firmware update page](firmware-update.md) |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`. The ports only listen on `127.0.0.1`.

QEMU's user network also has a DHCP server. With
[DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the switch gets
`192.168.1.100`, the gateway `192.168.1.254` and the DNS server
`192.168.1.244`. (Switch N: `192.168.1.100+10·N`, gateway `.254-N`, DNS
`.244-N`.)

The switch keeps its disk in `build/qemu/switch0.wic`. A saved
configuration is still there the next time you start it. To start over
with the factory settings and the image you built last, add `RESET=1`:

```sh
./kas-container --kvm --runtime-args "--network=host" \
    shell kas/board/qemux86-64-switch.yml -c "RESET=1 /work/scripts/x86-64-q35-qemu"
```

### 3. Connect switches

`lan2` … `lan8` can be connected to ports of other emulated switches, for
example to try VLAN trunks or spanning tree. Start every switch in a terminal
of its own, with its own number in `SWITCH` and the same list of cables in
`CABLES`. A cable is written as `switch:port-switch:port`.

Cabled switches share VLAN 1, so they cannot all keep the factory address
`192.168.1.1`: your SSH session or browser would end up on whichever switch
answers first. A cabled switch number N is therefore reached at
`192.168.1.N+1`: switch 0 keeps `192.168.1.1`, switch 1 needs `192.168.1.2`,
and so on. Give every switch except switch 0 its address once, before you
connect it. Start it without `CABLES` and log in as `cli` on its console (the
terminal):

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config ip 192.168.1.2
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config prefix-length 24
switch> delete interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1
switch> commit
switch> save
```

Do this on the console, not over SSH: over SSH, the `commit` ends your
session before you can `save` (see
[Management IP address](../cli/ip.md#change-the-static-address)). The
switch keeps the address on its disk, so this is needed only once, and again
after `RESET=1`.

Then two switches, connected by two cables, so that spanning tree has a loop
to break:

```sh
# Terminal 1
./kas-container --kvm --runtime-args "--network=host" shell kas/board/qemux86-64-switch.yml \
    -c "SWITCH=0 CABLES='0:2-1:2 0:3-1:3' /work/scripts/x86-64-q35-qemu"

# Terminal 2
./kas-container --kvm --runtime-args "--network=host" shell kas/board/qemux86-64-switch.yml \
    -c "SWITCH=1 CABLES='0:2-1:2 0:3-1:3' /work/scripts/x86-64-q35-qemu"
```

Each switch has its own forwarded ports on your computer:

| Switch | Address | SSH | Web pages, RESTCONF | Firmware update |
|---|---|---|---|---|
| `SWITCH=0` | `192.168.1.1` | 2222 | 8000 | 8080 |
| `SWITCH=1` | `192.168.1.2` | 2232 | 8010 | 8090 |
| `SWITCH=N` | `192.168.1.N+1` | 2222 + 10·N | 8000 + 10·N | 8080 + 10·N |

A switch without cables is always reached at `192.168.1.1`. To forward to
another address, add `ADDRESS=...` in front of `/work/scripts/x86-64-q35-qemu`.

!!! note
    With the factory settings, all ports of a switch are in VLAN 1. Two
    cables between two switches are then a loop. Turn on
    [spanning tree](../cli/spanning-tree.md) on the first switch before you
    start the second one, or connect only one cable.

Start the two terminals a few seconds apart: two `kas-container` commands
that start at the same moment can collide while checking out `layers/`.

### 4. Update the firmware

After a new build, the running switch does not change: it keeps its own
disk. Install the new firmware the way you would on a real switch, with
the `.swu` file from
`build/tmp/deploy/images/qemux86-64-switch/ethernet-switch-os-swu-upgrade-qemux86-64-switch.swu`
on the [firmware update page](firmware-update.md) at
`http://127.0.0.1:8080/`, or with `curl`:

```sh
curl -F file=@build/tmp/deploy/images/qemux86-64-switch/ethernet-switch-os-swu-upgrade-qemux86-64-switch.swu \
    http://127.0.0.1:8080/upload
```

The switch writes the new firmware into the slot it is **not** running
from, and restarts into it. Your configuration is kept.

The first start of the new firmware is a trial. When the switch is fully
up, it confirms the new firmware, and the console shows:

```
A/B: slot on /dev/vda5 confirmed
```

If the new firmware does not get that far -- it hangs, crashes or is
restarted before that line -- the switch goes back to the previous
firmware on the next start, and your configuration is still there.

Which slot is running is shown by `cat /proc/cmdline` in a root shell:
`root=/dev/vda4` is slot A, `root=/dev/vda5` slot B.

### What is different from a real switch

| | QEMU x86-64 switch |
|---|---|
| Hardware | A virtual PC. The ports are handled by the Linux bridge in software; nothing is offloaded to a switch chip. |
| Firmware | Its own image. Firmware for another board is refused, and its firmware does not work on real switches. |
| Firmware slots | Two (A/B), with rollback. The Zyxel GS1900-8 has one. |
| Ports `lan2` … `lan8` | Always show a link, even without a cable. Frames sent there without a cable are lost. |
| Port speed | Reported by the virtual network card, not a real Gigabit link. |
| First installation | None needed: the build produces the disk. |
