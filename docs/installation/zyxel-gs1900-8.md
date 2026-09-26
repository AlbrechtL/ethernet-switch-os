# Zyxel GS1900-8

The Zyxel GS1900-8 (rev A1) is the main board of Ethernet Switch OS: eight
Gigabit Ethernet ports `lan1` … `lan8` on a Realtek RTL8380 switch chip.
Its board name is `zyxel-gs1900-8-a1`.

You can run it on the [real switch](#real-switch), or try the very same
image without a switch in the [emulated GS1900-8](#qemu) in QEMU. Both
start from the downloaded images; there is no need to build the firmware.

## Hardware

| | |
|---|---|
| SoC | Realtek RTL8380M, MIPS 4KEc, big endian, with the switch core |
| Ports | 8 × Gigabit Ethernet, `lan1` … `lan8` |
| RAM | 128 MB |
| Flash | 16 MB SPI NOR |
| Serial console | On the board, 115200 8N1 |
| Bootloader | The original U-Boot, which stays in place |

The [OpenWrt device page](https://openwrt.org/toh/zyxel/gs1900-8) has the
rest: photos, how to open the case, the serial pin-out (the labels on the
PCB name the signal to connect, not the signal on the pin) and how to tell
revision A1 from B1. Ethernet Switch OS is built for the rev A1 board
(`zyxel-gs1900-8-a1`).

## Real switch

Ethernet Switch OS replaces the original firmware. The first installation
is done once, over the serial console and TFTP. After that, updates go
through a web page or the `swupdate` command (see
[Firmware update](../maintenance.md#firmware-update)).

!!! warning "The original firmware is replaced"
    The factory `.swu` overwrites both firmware slots of the original
    firmware and its configuration with one Ethernet Switch OS system. The
    bootloader is not touched. If you want to be able to go back, copy the
    flash first, before the installation. The
    [OpenWrt device page](https://openwrt.org/toh/zyxel/gs1900-8) has a
    "Return to factory firmware" section, which sends you on to the
    [GS1900-8HP page](https://openwrt.org/toh/zyxel/gs1900-8hp_v1#oem_easy_installation).

### What you need

- A serial adapter for the console (115200 8N1).
- A PC with a TFTP server, connected to one of the switch's ports.
- From the `ethernet-switch-os-zyxel-gs1900-8-a1` artifact, see
  [Download](download.md):

| File | Used for |
|---|---|
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin` | Booted over TFTP with `bootm`. The kernel with its initramfs, running entirely from RAM. For the first installation, and for recovery. |
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1-rt-loader.bin` | The same without the uImage header, booted with `go`. |
| `ethernet-switch-os-swu-factory-zyxel-gs1900-8-a1.swu` | The **factory** `.swu`: writes the firmware into the flash and erases the configuration. |
| `ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu` | The [update](#update) of a switch that is already installed. Keeps the configuration. |

Put the `initramfs` image into the directory of the TFTP server. The
other files in the artifact are intermediate results of the build; see
[For developers](#for-developers).

### First installation

1. Connect the serial console to the switch and the PC with the TFTP
   server to one of its ports. Give the PC a fixed address; the example
   below uses `192.168.1.12`.
2. Power the switch on and stop the original bootloader: press SPACE when
   it says `Press SPACE to abort boot script`. Its prompt appears.
3. Boot the `initramfs` image over TFTP. Pass the address to `bootm`
   explicitly, because a bare `bootm` uses `$loadaddr`:

    ```text
    rtk network on
    tftpboot 0x84f00000 192.168.1.12:ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin
    bootm 0x84f00000
    ```

    The switch has 128 MB of RAM, so addresses stop at `0x88000000`; do
    not use `0x8f000000` or higher, that is past the end of RAM.

    If you prefer the headerless image, use `go` instead:

    ```text
    tftpboot 0x84f00000 192.168.1.12:ethernet-switch-os-initramfs-zyxel-gs1900-8-a1-rt-loader.bin
    go 0x84f00000
    ```

    The two files are **not** interchangeable: `bootm` on the headerless
    one gives `Bad Header Checksum`, because it has no uImage header.

4. The switch comes up at `192.168.1.1`, running from RAM. Check that the
   bootloader will start the firmware from the first slot. The setting
   `bootpartition` is in the second bootloader environment, which
   `/etc/fw_env.config` does not list on purpose, so read it explicitly on
   the switch's console:

    ```sh
    echo '/dev/mtd2 0x0 0x1000 0x10000' > /tmp/env2.config
    fw_printenv -c /tmp/env2.config bootpartition   # must print bootpartition=0
    ```

5. Open `http://192.168.1.1:8080` and upload the **factory** `.swu`. It
   writes `firmware`, wipes `data` and does not touch either bootloader
   environment.
6. Reboot. The switch now starts Ethernet Switch OS from flash.

Continue with [First login](first-login.md).

### Update

Later updates are uploaded to the running switch as the **upgrade** `.swu`,
on the [firmware update page](../maintenance.md#firmware-update) or with
`swupdate`. The switch reboots by itself, and your configuration is kept.

There is only one firmware slot (see
[Non-A/B updates](../maintenance.md#non-ab-updates)): an update rewrites
the running firmware in place. If it is interrupted, boot the `initramfs`
image over TFTP again and repeat the first installation.

### Flash layout

The 16 MB flash is divided like this:

| Offset | Partition | Size | Content |
|---|---|---|---|
| `0x000000` | `u-boot` | 256 kB | The bootloader; read-only, never written |
| `0x040000` | `u-boot-env` | 64 kB | Bootloader environment |
| `0x050000` | `u-boot-env2` | 64 kB | Second environment; `bootpartition` must be `0` |
| `0x060000` | `data` | 2 MB | JFFS2, the writable part of the root filesystem and the saved configuration; kept on update |
| `0x260000` | `firmware` | 13952 kB | The kernel (uImage, padded to 64 kB), then the squashfs root filesystem |

`firmware` is the two firmware slots of the original firmware merged into
one (as in OpenWrt), and `data` its two JFFS2 partitions. So there is no
A/B here.

### For developers

How the boot image is put together, how the kernel configuration is
maintained and what went wrong on the way is in the
[TECHNICAL.md](https://github.com/AlbrechtL/meta-rtl83xx-bsp/blob/master/TECHNICAL.md)
of [meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp), the
Yocto layer for the hardware. The userspace is described in the
[TECHNICAL.md of meta-ethernet-switch-os](https://github.com/AlbrechtL/meta-ethernet-switch-os/blob/master/TECHNICAL.md).
To build the images yourself, see [Building the firmware](../development/building.md).

A build leaves more files than you need for an installation, in
`build/tmp/deploy/images/zyxel-gs1900-8-a1/`:

| File | What it is |
|---|---|
| `ethernet-switch-os-kernel-zyxel-gs1900-8-a1.bin` | The kernel of the flash, without initramfs. The head of `firmware`. |
| `rtl83xx-image-zyxel-gs1900-8-a1.rootfs.rtl83xx-fw` | The `firmware` partition: the kernel padded to 64 kB, then the squashfs. Inside both `.swu` files. |
| `rtl83xx-image-zyxel-gs1900-8-a1.rootfs.rtl83xx-data` | An empty JFFS2 filling the whole `data` partition. Inside the factory `.swu`. |
| `rtl83xx-image-zyxel-gs1900-8-a1.rootfs.squashfs-xz` | The root filesystem of the flash. |
| `rtl83xx-image-initramfs-zyxel-gs1900-8-a1.cpio.gz` | The initramfs that is built into the TFTP kernel. |
| `vmlinux.bin-*.bin`, `rtl8380_zyxel_gs1900-8-a1.dtb` | The raw kernels before compression, and the device tree that is appended to them. |

## QEMU

You can try Ethernet Switch OS without a switch.
[rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the Zyxel
GS1900-8, its 16 MB flash included, and runs the same images as the real
switch. The CLI, RESTCONF, the web pages, VLANs, the DHCP client, spanning
tree, SNMP and firmware updates all work as on the real switch.

The emulated switch is installed like the real one: it boots the
`initramfs` image, you install the **factory** `.swu` into its flash, and from
then on it starts from flash. The flash is a file on your computer, so the
configuration you save stays there until you delete the file.

Mainline QEMU, as packaged by Linux distributions, does not have the
RTL8380 machine. So this is the one case where you have to compile
something: the emulator, not the firmware. You need Docker, git and a
Linux host.

### 1. Build the emulator

```sh
git clone https://github.com/AlbrechtL/rtl838x-qemu
cd rtl838x-qemu
git submodule update --init
./rtl838x.sh build
```

The build runs in a Docker container and takes about 10 minutes the first
time. The emulator ends up in `out/qemu/bin/qemu-system-mips`, and it runs
directly on your computer. The
[rtl838x-qemu README](https://github.com/AlbrechtL/rtl838x-qemu) explains
the emulator itself.

### 2. Download the images

From the `ethernet-switch-os-zyxel-gs1900-8-a1` artifact (see
[Download](download.md)), unzip these next to the `rtl838x-qemu` directory:

| File | Content |
|---|---|
| `ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin` | The image for the first installation, running from RAM. |
| `ethernet-switch-os-swu-factory-zyxel-gs1900-8-a1.swu` | The **factory** `.swu`: writes the firmware into the flash and erases the configuration. |
| `ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu` | The [firmware update](#6-update-the-firmware) for a switch that is already installed. |

### 3. Create the flash

The flash of the emulated switch is a file of exactly 16 MB. Erased flash
reads as all ones, so create it filled with `0xff` bytes:

```sh
tr '\000' '\377' < /dev/zero | head -c 16M > gs1900-flash.bin
```

The switch keeps its firmware and its saved configuration in this file.
You decide when to start over: delete the file, create it again and repeat
the installation.

To try something without changing the file, add `,snapshot=on` to the
`-drive` option in the commands below: the switch keeps its writes in a
temporary file, so the flash file is as it was when QEMU exits, while a
`reboot` inside QEMU still sees them.

### 4. First installation

In the `rtl838x-qemu` directory, boot the `initramfs` image with the empty
flash:

```sh
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic -no-reboot \
    -kernel ../ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin \
    -drive if=mtd,format=raw,file=../gs1900-flash.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161
```

| Option | Meaning |
|---|---|
| `-M rtl838x -m 128` | The emulated RTL8380 switch with 128 MB of RAM, as on the GS1900-8. |
| `-nographic` | No window. The terminal becomes the switch's serial console. |
| `-no-reboot` | `reboot` on the switch ends QEMU instead of starting it again. Here that ends the installation; otherwise the switch would boot the `initramfs` image again. |
| `-kernel …` | The image to boot. The emulator starts it the way the switch's bootloader does after a TFTP boot. |
| `-drive if=mtd,…` | The switch's flash, the file from step 3. |
| `-nic user,…` | The first `-nic` is port `lan1`, connected to QEMU's built-in user network. The following options belong to it. |
| `net=192.168.1.0/24` | The user network uses the switch's factory network. |
| `host=…,dns=…,dhcpstart=…` | The addresses of QEMU's virtual gateway, DNS server and DHCP pool in that network. Without them QEMU would take `192.168.1.2` for itself. |
| `hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22` | Forwards port 2222 on your computer to SSH on the switch. The other `hostfwd` do the same for the web pages (8000), the firmware update page (8080) and SNMP (UDP 1161). |

After about 20 seconds, the switch is up. Upload the **factory** `.swu` on
the firmware update page at `http://127.0.0.1:8080/`, or from a second
terminal with `curl`:

```sh
curl -F file=@ethernet-switch-os-swu-factory-zyxel-gs1900-8-a1.swu \
    http://127.0.0.1:8080/upload
```

The switch writes the firmware into the flash and reboots, which ends QEMU.

### 5. Start the switch

From now on, start the switch without `-kernel` and without `-no-reboot`:

```sh
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic \
    -drive if=mtd,format=raw,file=../gs1900-flash.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161
```

Without `-kernel`, the emulator does what the switch's bootloader does: it
starts the firmware in the flash. `reboot` on the switch restarts it, from
the flash again, just as on the real switch.

Ports `lan2` … `lan8` have no `-nic` and therefore no cable: they show no
carrier.

The terminal shows the serial console, which is what you would see on the
real switch's console port. After about 20 seconds the login prompt
appears. Log in as `root` (no password) and start the CLI with
`clixon_cli`, or log in as `cli`. **Ctrl-A x** quits QEMU. The update
service writes its log to the console as well, so its lines can appear
between yours; press Enter to get a fresh prompt.

From your computer, the switch is reached through the forwarded ports:

| On your computer | On the switch |
|---|---|
| `ssh -p 2222 cli@127.0.0.1` | The CLI |
| `ssh -p 2222 root@127.0.0.1` | A root shell |
| `http://127.0.0.1:8000/` | [Status page](../web-ui.md) |
| `http://127.0.0.1:8000/restconf/` | RESTCONF |
| `http://127.0.0.1:8080/` | [Firmware update page](../maintenance.md#firmware-update) |
| UDP `127.0.0.1:1161` | [SNMP](../snmp/index.md), e.g. `snmpwalk ... 127.0.0.1:1161 1.3.6.1.2.1.1` |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`. The ports only listen on `127.0.0.1`.

With [DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the
switch gets `192.168.1.100` from QEMU, the gateway `192.168.1.254` and the
DNS server `192.168.1.244`.

A configuration you `save` is in `gs1900-flash.bin`, and is still there
the next time you start the switch with the same file.

### 6. Update the firmware

The emulated switch is updated like the real one: upload the **upgrade**
`.swu` of a newer [download](download.md) on the
[firmware update page](../maintenance.md#firmware-update) at
`http://127.0.0.1:8080/`, or with `curl`:

```sh
curl -F file=@ethernet-switch-os-swu-upgrade-zyxel-gs1900-8-a1.swu \
    http://127.0.0.1:8080/upload
```

The switch rewrites its firmware in the flash and reboots into it. Your
configuration is kept. As on the real switch there is only one firmware
slot (see [Non-A/B updates](../maintenance.md#non-ab-updates)): if an update
is interrupted, delete the flash file and install again from step 3.

### 7. Connect switches

A port becomes a cable to another emulated switch with a `dgram` network
device: the switch sends the port's frames as UDP packets to a local port
on your computer, where the other switch listens. The `-nic` and `-net nic`
options claim the ports in order, so the second one is always `lan2`, the
third `lan3` and so on.

Every switch needs a flash of its own. Create a second one and install it
as in steps 3 and 4:

```sh
tr '\000' '\377' < /dev/zero | head -c 16M > gs1900-flash-1.bin
```

Here `lan2` of switch 0 is cabled to `lan2` of switch 1. Start each switch
in a terminal of its own:

```sh
# Terminal 1: switch 0
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic \
    -drive if=mtd,format=raw,file=../gs1900-flash.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161 \
    -netdev dgram,id=lan2,local.type=inet,local.host=127.0.0.1,local.port=20002,remote.type=inet,remote.host=127.0.0.1,remote.port=20102 \
    -net nic,netdev=lan2

# Terminal 2: switch 1
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic \
    -drive if=mtd,format=raw,file=../gs1900-flash-1.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.253,dns=192.168.1.243,dhcpstart=192.168.1.110,hostfwd=tcp:127.0.0.1:2232-192.168.1.2:22,hostfwd=tcp:127.0.0.1:8010-192.168.1.2:80,hostfwd=tcp:127.0.0.1:8090-192.168.1.2:8080,hostfwd=udp:127.0.0.1:1171-192.168.1.2:161 \
    -netdev dgram,id=lan2,local.type=inet,local.host=127.0.0.1,local.port=20102,remote.type=inet,remote.host=127.0.0.1,remote.port=20002 \
    -net nic,netdev=lan2
```

`local.port` is where a switch receives the cable's frames, `remote.port`
where it sends them, so the two switches have them the other way round.
Every cable needs a pair of UDP ports of its own.

Cabled switches share VLAN 1, and with it their user networks. So each
switch needs addresses of its own:

| | Switch 0 | Switch 1 |
|---|---|---|
| Flash | `gs1900-flash.bin` | `gs1900-flash-1.bin` |
| Switch address | `192.168.1.1` (factory) | `192.168.1.2`, set once, see below |
| QEMU's gateway, DNS, DHCP pool | `.254`, `.244`, from `.100` | `.253`, `.243`, from `.110` |
| SSH, web pages, update page, SNMP | 2222, 8000, 8080, 1161 | 2232, 8010, 8090, 1171 |

Otherwise your SSH session or browser would end up on whichever switch
answers first. Switch 1 has to be given its address before switch 0 runs;
until then both would answer at `192.168.1.1`. Start switch 1 first, alone.
Log in as `cli` on its console (the terminal) and enter:

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
switch keeps the address in `gs1900-flash-1.bin`, so this is needed only
once. Then start switch 0 in a second terminal.

!!! note
    With the factory settings, all ports of a switch are in VLAN 1 and
    spanning tree is off. Two cables between two switches are then a loop
    that floods both switches until neither answers. Turn on
    [spanning tree](../cli/spanning-tree.md) on the first switch before
    you start the second one, or connect only one cable.

### What is different from the real switch

| | In QEMU |
|---|---|
| Flash | A file of your own; delete it to start over. The emulator boots the firmware slot at `0x260000`, as the switch's bootloader does with the factory settings. |
| MAC address | Random, new for every start of QEMU. It stays the same across a `reboot`. |
| Ports | A port with a `-nic` or `-net nic` has a link, one without has none. |
| Port counters | Always 0, in the CLI and on the status page. |
| MSTP | Only the common spanning tree is emulated, so MSTP instances have no effect on forwarding. STP and RSTP work. |

### With a firmware build of your own

If you [build the firmware](../development/building.md) yourself, append
`kas/opt/rtl838x-qemu.yml`. That builds the emulator as well, and
`scripts/mips-rtl838x-qemu` starts the switch from the build directory with
all of the options above:

```sh
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml
./kas-container --runtime-args "--network=host" \
    shell kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml \
    -c /work/scripts/mips-rtl838x-qemu
```

`--network=host` makes the forwarded ports appear on your computer. The
script needs no installation step: it always boots the firmware the last
build left in `build/tmp/deploy/images/zyxel-gs1900-8-a1/`, from a flash
that looks like a fresh factory install, and never keeps that flash: the
switch starts with the factory settings every time, and what you configure
is gone when QEMU exits. A `reboot` keeps it. To try a firmware update,
upload the upgrade `.swu` file from the same directory to the update page;
the switch reboots into the new firmware and keeps it until QEMU exits.

The emulator is built by the recipe `qemu-rtl838x-native` of
[meta-rtl83xx-bsp](https://github.com/AlbrechtL/meta-rtl83xx-bsp), which
takes the QEMU release that rtl838x-qemu pins as its submodule and applies
rtl838x-qemu's models and patch to it. The binary is called
`qemu-system-mips-rtl838x`, so that it does not collide with the
`qemu-system-native` of OpenEmbedded.

The script gives every port a link, including `lan2` … `lan8` without a
cable. For more switches, start each one with its own number in `SWITCH`
and the same list of cables in `CABLES`, written as
`switch:port-switch:port`. Here `lan2` of switch 0 goes to `lan2` of
switch 1:

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

Switch N uses the addresses and ports of the table above, counted on by N:
`192.168.1.N+1`, SSH on 2222 + 10·N, web pages on 8000 + 10·N, the update
page on 8080 + 10·N and SNMP on 1161 + 10·N. It needs its address set on
the console as above after every start of the script, since the script
starts from the factory settings; `save` is not needed. A switch without
cables is always reached at `192.168.1.1`; to forward to another address,
add `ADDRESS=...` in front of `/work/scripts/mips-rtl838x-qemu`.

Start the two terminals a few seconds apart: two `kas-container` commands
that start at the same moment can collide while checking out `layers/`.

### A flash like a factory install

Instead of booting the `initramfs` image and uploading the factory `.swu`,
you can write the flash file of a factory install directly from the build
result (see [Flash layout](#flash-layout) for the offsets):

```sh
d=build/tmp/deploy/images/zyxel-gs1900-8-a1
tr '\000' '\377' < /dev/zero | head -c 16M > flash.bin
dd if=$d/rtl83xx-image-zyxel-gs1900-8-a1.rootfs.rtl83xx-data of=flash.bin bs=64k seek=6 conv=notrunc
dd if=$d/rtl83xx-image-zyxel-gs1900-8-a1.rootfs.rtl83xx-fw of=flash.bin bs=64k seek=38 conv=notrunc
```

Start the switch with it as in [step 5](#5-start-the-switch).
