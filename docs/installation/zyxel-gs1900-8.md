# Zyxel GS1900-8

The Zyxel GS1900-8 (rev A1) is the main board of Ethernet Switch OS: eight
Gigabit Ethernet ports `lan1` … `lan8` on a Realtek RTL8380 switch chip.
Its board name is `zyxel-gs1900-8-a1`.

You can run it on the [real switch](#real-switch), or try the very same
image without a switch in the [emulated GS1900-8](#qemu) in QEMU. Both
start from the downloaded images; there is no need to build the firmware.

## Real switch

Ethernet Switch OS replaces the original firmware. The first installation
is done once, over the serial console and TFTP. After that, updates go
through a web page or the `swupdate` command (see
[Firmware update](../maintenance.md#firmware-update)).

You need the `initramfs` image and the **factory** `.swu` from the
`ethernet-switch-os-zyxel-gs1900-8-a1` artifact, see [Download](download.md).

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

Continue with [First login](first-login.md).

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
