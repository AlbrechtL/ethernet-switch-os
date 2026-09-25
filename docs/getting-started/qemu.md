# Running in QEMU

You can try Ethernet Switch OS without a switch.
[rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the Zyxel
GS1900-8, and it boots the same `initramfs` image that is used for the first
installation on real hardware. The CLI, RESTCONF, the web pages, VLANs,
the DHCP client, spanning tree and SNMP all work as on the real switch.

Everything runs in Docker containers. You need Docker, git and a Linux host.

## 1. Build the image and the emulator

The GS1900-8 is built as usual (see
[Building the firmware](../development/building.md)), with
`kas/opt/rtl838x-qemu.yml` appended. That also builds QEMU with the RTL8380
machine, so nothing else has to be installed:

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
./kas-container build kas/board/zyxel-gs1900-8-a1.yml:kas/opt/rtl838x-qemu.yml
```

## 2. Boot the switch

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
| UDP `127.0.0.1:1161` | [SNMP](../cli/snmp.md), e.g. `snmpwalk ... 127.0.0.1:1161 1.3.6.1.2.1.1` |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`. The ports only listen on `127.0.0.1`;
`--network=host` is what makes them appear on your computer.

QEMU's user network also has a DHCP server. With
[DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the switch gets
`192.168.1.100`, the gateway `192.168.1.254` and the DNS server `192.168.1.244`.

## 3. Connect switches

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

## What is different from the real switch

| | In QEMU |
|---|---|
| Configuration after a reboot | **Lost.** The emulated switch has no flash memory. `save` works, but the next boot starts with the factory settings again. |
| Firmware update | Uploading works, and the file is checked, but writing fails (`Wrong MTD device in description: firmware`). The TFTP image runs the factory update anyway. |
| Cabled ports | All eight ports have a link. `lan2` … `lan8` lead to another emulated switch, or nowhere when `CABLES` does not name them. |
| Port counters | Always 0, in the CLI and on the status page. |
| MSTP | Only the common spanning tree is emulated, so MSTP instances have no effect on forwarding. STP and RSTP work. |
| Reboot | `reboot` ends QEMU. Start it again for a fresh switch with the factory settings. |
