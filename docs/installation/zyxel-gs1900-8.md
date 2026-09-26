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
GS1900-8 and boots the same `initramfs` image that is used for the first
installation on real hardware. The CLI, RESTCONF, the web pages, VLANs,
the DHCP client, spanning tree and SNMP all work as on the real switch.

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

### 2. Download the image

From the `ethernet-switch-os-zyxel-gs1900-8-a1` artifact (see
[Download](download.md)), you need only
`ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin`. Unzip it next to the
`rtl838x-qemu` directory.

### 3. Boot the switch

In the `rtl838x-qemu` directory:

```sh
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic -no-reboot \
    -kernel ../ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161
```

| Option | Meaning |
|---|---|
| `-M rtl838x -m 128` | The emulated RTL8380 switch with 128 MB of RAM, as on the GS1900-8. |
| `-nographic` | No window. The terminal becomes the switch's serial console. |
| `-no-reboot` | `reboot` on the switch ends QEMU instead of starting it again. |
| `-kernel …` | The image to boot. The emulator starts it the way the switch's bootloader does after a TFTP boot. |
| `-nic user,…` | The first `-nic` is port `lan1`, connected to QEMU's built-in user network. The following options belong to it. |
| `net=192.168.1.0/24` | The user network uses the switch's factory network. |
| `host=…,dns=…,dhcpstart=…` | The addresses of QEMU's virtual gateway, DNS server and DHCP pool in that network. Without them QEMU would take `192.168.1.2` for itself. |
| `hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22` | Forwards port 2222 on your computer to SSH on the switch. The other `hostfwd` do the same for the web pages (8000), the firmware update page (8080) and SNMP (UDP 1161). |

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

### 4. Connect switches

A port becomes a cable to another emulated switch with a `dgram` network
device: the switch sends the port's frames as UDP packets to a local port
on your computer, where the other switch listens. The `-nic` and `-net nic`
options claim the ports in order, so the second one is always `lan2`, the
third `lan3` and so on.

Here `lan2` of switch 0 is cabled to `lan2` of switch 1. Start each switch
in a terminal of its own:

```sh
# Terminal 1: switch 0
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic -no-reboot \
    -kernel ../ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161 \
    -netdev dgram,id=lan2,local.type=inet,local.host=127.0.0.1,local.port=20002,remote.type=inet,remote.host=127.0.0.1,remote.port=20102 \
    -net nic,netdev=lan2

# Terminal 2: switch 1
out/qemu/bin/qemu-system-mips \
    -M rtl838x -m 128 -nographic -no-reboot \
    -kernel ../ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin \
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
| Switch address | `192.168.1.1` (factory) | `192.168.1.2`, set on the console, see below |
| QEMU's gateway, DNS, DHCP pool | `.254`, `.244`, from `.100` | `.253`, `.243`, from `.110` |
| SSH, web pages, update page, SNMP | 2222, 8000, 8080, 1161 | 2232, 8010, 8090, 1171 |

Otherwise your SSH session or browser would end up on whichever switch
answers first. The emulated switch has no flash, so it forgets its address
when it stops: after every boot, log in as `cli` on the console of switch 1
and give it its address:

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config ip 192.168.1.2
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.2 config prefix-length 24
switch> delete interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1
switch> commit
```

!!! note
    With the factory settings, all ports of a switch are in VLAN 1 and
    spanning tree is off. Two cables between two switches are then a loop
    that floods both switches until neither answers. Turn on
    [spanning tree](../cli/spanning-tree.md) on the first switch before
    you start the second one -- after every boot, since the emulated switch
    forgets it. Or connect only one cable.

### What is different from the real switch

| | In QEMU |
|---|---|
| Configuration after a reboot | **Lost.** The emulated switch has no flash memory. `save` works, but the next boot starts with the factory settings again. |
| Firmware update | Uploading works, and the file is checked, but writing fails (`Wrong MTD device in description: firmware`). The TFTP image runs the factory update anyway. |
| Ports | A port with a `-nic` or `-net nic` has a link, one without has none. |
| Port counters | Always 0, in the CLI and on the status page. |
| MSTP | Only the common spanning tree is emulated, so MSTP instances have no effect on forwarding. STP and RSTP work. |
| Reboot | `reboot` ends QEMU. Start it again for a fresh switch with the factory settings. |

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
script gives every port a link, including `lan2` … `lan8` without a cable.
For more switches, start each one with its own number in `SWITCH` and the
same list of cables in `CABLES`, written as `switch:port-switch:port`. Here
`lan2` of switch 0 goes to `lan2` of switch 1:

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
page on 8080 + 10·N and SNMP on 1161 + 10·N. It still needs its address set
on the console after every boot. A switch without cables is always reached
at `192.168.1.1`; to forward to another address, add `ADDRESS=...` in front
of `/work/scripts/mips-rtl838x-qemu`.

Start the two terminals a few seconds apart: two `kas-container` commands
that start at the same moment can collide while checking out `layers/`.
