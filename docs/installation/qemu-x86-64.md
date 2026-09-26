# QEMU x86-64 switch

The QEMU x86-64 switch is an emulated 8 port switch with a board of its own.
It is not a copy of any real switch; it is a virtual PC whose front ports are
virtual network cards. Its board name is `qemux86-64-switch`. Unlike the
[emulated Zyxel GS1900-8](zyxel-gs1900-8.md#qemu), it:

- runs in the standard QEMU of your Linux distribution, so nothing has to
  be compiled,
- boots in seconds, because it runs at full speed with KVM,
- keeps its configuration on a virtual disk, and
- has two firmware slots (A/B) with automatic rollback, so
  [firmware updates](../maintenance.md#firmware-update) work as they will
  on hardware that has two slots.

!!! note "Tested on"
    This guide was tested on Ubuntu 26.04.

## 1. Install QEMU

On Ubuntu or Debian, install QEMU and its UEFI firmware (OVMF):

```sh
sudo apt install qemu-system-x86 ovmf
```

The switch boots with UEFI; OVMF is the UEFI firmware for QEMU. The
package puts it into `/usr/share/OVMF/`.

For full speed, QEMU needs access to KVM, the virtualization in the Linux
kernel. Without KVM the switch still runs, but slowly: it takes about a
minute to boot. See [without KVM](#without-kvm).

## 2. Download the image

Download the `ethernet-switch-os-qemux86-64-switch` artifact (see
[Download](download.md)) and unzip it. It contains:

| File | Content |
|---|---|
| `qemu-switch-image-qemux86-64-switch.rootfs.wic` | The switch's disk: bootloader, both firmware slots and the configuration partition. |
| `qemu-switch-image-qemux86-64-switch.rootfs.wic.bmap` | Which blocks of the disk are used. Only needed for `bmaptool`. |
| `ethernet-switch-os-swu-upgrade-qemux86-64-switch.swu` | The [firmware update](#5-update-the-firmware) for a switch that is already running. |

The disk is the switch's own, and it writes its configuration onto it.
Work on a copy, so that the downloaded file stays as it is. The UEFI
firmware keeps its settings in a file of its own, which needs a copy per
switch as well:

```sh
cp qemu-switch-image-qemux86-64-switch.rootfs.wic switch0.wic
cp /usr/share/OVMF/OVMF_VARS_4M.fd switch0-vars.fd
```

To start over with the factory settings later, copy both again.

## 3. Start the switch

```sh
qemu-system-x86_64 \
    -machine q35 -enable-kvm -cpu host -smp 2 -m 512 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=switch0-vars.fd \
    -drive if=virtio,format=raw,file=switch0.wic \
    -device i6300esb -action watchdog=reset \
    -netdev user,id=lan1,net=192.168.1.0/24,host=192.168.1.254,dns=192.168.1.244,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080 \
    -device virtio-net-pci,netdev=lan1,addr=0x10 \
    -device virtio-net-pci,addr=0x11 \
    -device virtio-net-pci,addr=0x12 \
    -device virtio-net-pci,addr=0x13 \
    -device virtio-net-pci,addr=0x14 \
    -device virtio-net-pci,addr=0x15 \
    -device virtio-net-pci,addr=0x16 \
    -device virtio-net-pci,addr=0x17 \
    -nographic
```

What the options do:

| Option | Meaning |
|---|---|
| `-machine q35` | A current PC with a PCI Express chipset. |
| `-enable-kvm -cpu host` | Runs the switch on your CPU with KVM, at full speed. |
| `-smp 2 -m 512` | Two CPU cores and 512 MB of RAM. |
| `-drive if=pflash,…,file=…/OVMF_CODE_4M.fd` | The UEFI firmware, read-only. It starts the bootloader on the disk. |
| `-drive if=pflash,…,file=switch0-vars.fd` | The UEFI settings of this switch, writable. |
| `-drive if=virtio,format=raw,file=switch0.wic` | The switch's disk. |
| `-device i6300esb -action watchdog=reset` | A hardware watchdog, which resets the switch when it hangs. The bootloader refuses to start without it, and it is what lets a hanging [firmware update](../maintenance.md#ab-updates) roll back. |
| `-netdev user,id=lan1,…` | QEMU's built-in user network, the network behind port `lan1`. |
| `net=192.168.1.0/24` | The user network uses the switch's factory network. |
| `host=…,dns=…,dhcpstart=…` | The addresses of QEMU's virtual gateway, DNS server and DHCP pool in that network. Without them QEMU would take `192.168.1.2` for itself. |
| `hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22` | Forwards port 2222 on your computer to SSH on the switch. The other two `hostfwd` do the same for the web pages (8000) and the firmware update page (8080). |
| `-device virtio-net-pci,netdev=lan1,addr=0x10` | Network card of port `lan1`, connected to the user network. |
| `-device virtio-net-pci,addr=0x11` … `0x17` | Network cards of ports `lan2` … `lan8`, without a cable. The switch names its ports by their PCI address: `0x10` is `lan1`, `0x17` is `lan8`. All eight must be there. |
| `-nographic` | No window. The terminal becomes the switch's serial console. |

QEMU warns `nic virtio-net-pci.1 has no peer` for every port without a
cable; that is expected.

The terminal shows the serial console. After a few seconds the login prompt
appears. Log in as `root` (no password) and start the CLI with `clixon_cli`,
or log in as `cli`. **Ctrl-A x** quits QEMU.

From your computer, the switch is reached through the forwarded ports:

| On your computer | On the switch |
|---|---|
| `ssh -p 2222 cli@127.0.0.1` | The CLI |
| `ssh -p 2222 root@127.0.0.1` | A root shell |
| `http://127.0.0.1:8000/` | [Status page](../web-ui.md) |
| `http://127.0.0.1:8000/restconf/` | RESTCONF |
| `http://127.0.0.1:8080/` | [Firmware update page](../maintenance.md#firmware-update) |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`. The ports only listen on `127.0.0.1`.

With [DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the
switch gets `192.168.1.100` from QEMU, the gateway `192.168.1.254` and the
DNS server `192.168.1.244`.

A saved configuration is on `switch0.wic`, and is still there the next
time you start the switch with the same files.

### Without KVM

Without access to `/dev/kvm`, replace `-enable-kvm -cpu host` with:

```sh
    -cpu Skylake-Client \
```

QEMU then emulates the CPU in software. `Skylake-Client` is a CPU model
that has all the instructions the firmware is built for (x86-64-v3); the
warnings about features it does not support (`pcid`, `rtm` and others) can
be ignored.

## 4. Connect switches

`lan2` … `lan8` can be cabled to ports of other emulated switches, for
example to try VLAN trunks or spanning tree. This needs QEMU 7.2 or newer
(Ubuntu 24.04 or Debian 13 and later).

A cable is a `dgram` network device on each side: the switch sends the
port's frames as UDP packets to a local port on your computer, where the
other switch listens. For `lan2`, replace the line
`-device virtio-net-pci,addr=0x11` with two lines. On switch 0:

```sh
    -netdev dgram,id=lan2,local.type=inet,local.host=127.0.0.1,local.port=20002,remote.type=inet,remote.host=127.0.0.1,remote.port=20102 \
    -device virtio-net-pci,netdev=lan2,addr=0x11 \
```

and on switch 1 with the ports the other way round:

```sh
    -netdev dgram,id=lan2,local.type=inet,local.host=127.0.0.1,local.port=20102,remote.type=inet,remote.host=127.0.0.1,remote.port=20002 \
    -device virtio-net-pci,netdev=lan2,addr=0x11 \
```

`local.port` is where a switch receives the cable's frames, `remote.port`
where it sends them. Every cable needs a pair of UDP ports of its own. For
another port, change the `id`, the ports and the PCI address: `lan3` is
`addr=0x12`, and so on.

Cabled switches share VLAN 1, and with it their user networks. So
everything that identifies a switch in that network must be its own:

| | Switch 0 | Switch 1 |
|---|---|---|
| Files | `switch0.wic`, `switch0-vars.fd` | `switch1.wic`, `switch1-vars.fd`, copied the same way |
| Switch address | `192.168.1.1` (factory) | `192.168.1.2`, set once, see below |
| QEMU's gateway, DNS, DHCP pool | `host=192.168.1.254`, `dns=192.168.1.244`, `dhcpstart=192.168.1.100` | `host=192.168.1.253`, `dns=192.168.1.243`, `dhcpstart=192.168.1.110` |
| Forwarded ports | `2222-192.168.1.1:22`, `8000-192.168.1.1:80`, `8080-192.168.1.1:8080` | `2232-192.168.1.2:22`, `8010-192.168.1.2:80`, `8090-192.168.1.2:8080` |
| MAC addresses | QEMU's default | `,mac=52:54:00:00:01:01` on the `lan1` card, `…:01:02` on `lan2`, up to `…:01:08` on `lan8` |

QEMU gives the network cards of every switch the same MAC addresses unless
told otherwise, which is why switch 1 needs its own. For switch 1, the
`lan1` card and the first uncabled one then read:

```sh
    -device virtio-net-pci,netdev=lan1,addr=0x10,mac=52:54:00:00:01:01 \
    …
    -device virtio-net-pci,addr=0x12,mac=52:54:00:00:01:03 \
```

Switch 1 has to be given its address before switch 0 runs; until then both
would answer at `192.168.1.1`. Start switch 1 first, alone. Log in as `cli`
on its console (the terminal) and enter:

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
switch keeps the address on `switch1.wic`, so this is needed only once.
Then start switch 0 in a second terminal.

!!! note
    With the factory settings, all ports of a switch are in VLAN 1. Two
    cables between two switches are then a loop. Turn on
    [spanning tree](../cli/spanning-tree.md) on the first switch before you
    start the second one, or connect only one cable.

## 5. Update the firmware

The switch is updated like a real one: with the `.swu` file of a newer
[download](download.md) on the
[firmware update page](../maintenance.md#firmware-update) at
`http://127.0.0.1:8080/`, or with `curl`:

```sh
curl -F file=@ethernet-switch-os-swu-upgrade-qemux86-64-switch.swu \
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

## With a firmware build of your own

If you [build the firmware](../development/building.md) yourself, the build
also produces a QEMU and the UEFI firmware to run it with, and
`scripts/x86-64-q35-qemu` starts the switch with all of the options above:

```sh
./kas-container build kas/board/qemux86-64-switch.yml
./kas-container --kvm --runtime-args "--network=host" \
    shell kas/board/qemux86-64-switch.yml -c /work/scripts/x86-64-q35-qemu
```

`--network=host` makes the forwarded ports appear on your computer. The
script always boots the image the last build left in
`build/tmp/deploy/images/qemux86-64-switch/`, and never changes it: the
switch starts with the factory settings every time, and what you configure
is gone when QEMU exits. To try a firmware update, upload the `.swu` file from
the same directory to the update page; the switch reboots into the new
firmware and keeps it until QEMU exits.

For more switches, start each one with its own number in `SWITCH` and the
same list of cables in `CABLES`, written as `switch:port-switch:port`. Here
two cables, so that spanning tree has a loop to break:

```sh
# Terminal 1
./kas-container --kvm --runtime-args "--network=host" shell kas/board/qemux86-64-switch.yml \
    -c "SWITCH=0 CABLES='0:2-1:2 0:3-1:3' /work/scripts/x86-64-q35-qemu"

# Terminal 2
./kas-container --kvm --runtime-args "--network=host" shell kas/board/qemux86-64-switch.yml \
    -c "SWITCH=1 CABLES='0:2-1:2 0:3-1:3' /work/scripts/x86-64-q35-qemu"
```

Switch N uses the addresses and ports of the table above, counted on by N:
`192.168.1.N+1`, SSH on 2222 + 10·N, web pages on 8000 + 10·N and the
update page on 8080 + 10·N. It needs its address set as above after every
start. A switch without cables is always reached at
`192.168.1.1`; to forward to another address, add `ADDRESS=...` in front of
`/work/scripts/x86-64-q35-qemu`.

Start the two terminals a few seconds apart: two `kas-container` commands
that start at the same moment can collide while checking out `layers/`.
