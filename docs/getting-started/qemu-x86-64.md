# QEMU x86-64 switch

The QEMU x86-64 switch is an emulated 8 port switch with a board of its own.
It is not a copy of any real switch; it is a virtual PC whose front ports are
virtual network cards. Unlike [Running in QEMU](qemu.md), which emulates the
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

## 1. Build it

The board is built like any other (see
[Building the firmware](../development/building.md)). The
build also produces the UEFI firmware and a QEMU to run it with, so nothing
else has to be installed:

```sh
git clone https://github.com/AlbrechtL/ethernet-switch-os
cd ethernet-switch-os
./kas-container build kas/board/qemux86-64-switch.yml
```

## 2. Start the switch

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

## 3. Connect switches

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

## 4. Update the firmware

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

## What is different from a real switch

| | QEMU x86-64 switch |
|---|---|
| Hardware | A virtual PC. The ports are handled by the Linux bridge in software; nothing is offloaded to a switch chip. |
| Firmware | Its own image. Firmware for another board is refused, and its firmware does not work on real switches. |
| Firmware slots | Two (A/B), with rollback. The Zyxel GS1900-8 has one. |
| Ports `lan2` … `lan8` | Always show a link, even without a cable. Frames sent there without a cable are lost. |
| Port speed | Reported by the virtual network card, not a real Gigabit link. |
| First installation | None needed: the build produces the disk. |
