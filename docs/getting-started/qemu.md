# Running in QEMU

You can try Ethernet Switch OS without a switch.
[rtl838x-qemu](https://github.com/AlbrechtL/rtl838x-qemu) emulates the Zyxel
GS1900-8, and it boots the same `initramfs` image that is used for the first
installation on real hardware. The CLI, RESTCONF, the web pages, VLANs,
the DHCP client, spanning tree and SNMP all work as on the real switch.

Everything runs in Docker containers. You need Docker, git and a Linux host.

## 1. Get an image

Either build it (see the
[README](https://github.com/AlbrechtL/ethernet-switch-os#building)), which
leaves it in `build/tmp/deploy/images/zyxel-gs1900-8-a1/`, or download the
image artifact of a
[CI run](https://github.com/AlbrechtL/ethernet-switch-os/actions). You need
`ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin`.

## 2. Build the emulator

Once, next to your `ethernet-switch-os` checkout:

```sh
git clone --recurse-submodules https://github.com/AlbrechtL/rtl838x-qemu
cd rtl838x-qemu
./rtl838x.sh build            # about 10 minutes the first time
./rtl838x.sh runtime-image    # the container image that runs it
```

## 3. Boot the switch

### Console only

The quickest start. You get the serial console, which is what you would
see on the real switch's console port:

```sh
./rtl838x.sh run ../ethernet-switch-os/build/tmp/deploy/images/zyxel-gs1900-8-a1/ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin
```

After about 20 seconds the login prompt appears. Log in as `root` (no
password) and start the CLI with `clixon_cli`, or log in as `cli`.
**Ctrl-A x** quits QEMU. The update service writes its log to the console
as well, so its lines can appear between yours; press Enter to get a fresh
prompt.

In this mode, SSH, the web pages and RESTCONF cannot be reached from your
computer.

### With network access from your computer

To use SSH, the web pages, RESTCONF and SNMP from your computer, connect
the emulated `lan1` to QEMU's user network and forward ports to the
switch's factory address `192.168.1.1`:

```sh
cd ../ethernet-switch-os/build/tmp/deploy/images/zyxel-gs1900-8-a1
docker run --rm -it --network host -v "$PWD:/images:ro" rtl838x-qemu-runtime \
  qemu-system-mips -M rtl838x -m 128 -nographic -no-reboot \
    -kernel /images/ethernet-switch-os-initramfs-zyxel-gs1900-8-a1.bin \
    -nic user,net=192.168.1.0/24,host=192.168.1.2,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22,hostfwd=tcp:127.0.0.1:8000-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:8080,hostfwd=udp:127.0.0.1:1161-192.168.1.1:161
```

The terminal shows the serial console as before. On your computer:

| On your computer | On the switch |
|---|---|
| `ssh -p 2222 cli@127.0.0.1` | The CLI |
| `ssh -p 2222 root@127.0.0.1` | A root shell |
| `http://127.0.0.1:8000/` | [Status page](../web-ui.md) |
| `http://127.0.0.1:8000/restconf/` | RESTCONF |
| `http://127.0.0.1:8080/` | [Firmware update page](firmware-update.md) |
| UDP `127.0.0.1:1161` | [SNMP](../cli/snmp.md), e.g. `snmpwalk ... 127.0.0.1:1161 1.3.6.1.2.1.1` |

So wherever this guide says `192.168.1.1`, use `127.0.0.1` with these
ports. `scp` needs `-P 2222`.

`--network host` makes the forwarded ports appear on your computer, and
they only listen on `127.0.0.1`. Publishing them with `docker -p` instead
does not work with QEMU's user network.

QEMU's user network also has a DHCP server. With
[DHCP turned on](../cli/ip.md#use-a-dhcp-client) for `vlan1`, the switch gets
`192.168.1.100`, the gateway `192.168.1.2` and the DNS server `192.168.1.3`.

## What is different from the real switch

| | In QEMU |
|---|---|
| Configuration after a reboot | **Lost.** The emulated switch has no flash memory. `save` works, but the next boot starts with the factory settings again. |
| Firmware update | Uploading works, and the file is checked, but writing fails (`Wrong MTD device in description: firmware`). The TFTP image runs the factory update anyway. |
| Cabled ports | Only `lan1` has a "cable" (the user network); `lan2` … `lan8` show `LOWER_LAYER_DOWN`. |
| Port counters | Always 0, in the CLI and on the status page. |
| MSTP | Only the common spanning tree is emulated, so MSTP instances have no effect on forwarding. STP and RSTP work. |
| Reboot | `reboot` ends QEMU. Start it again for a fresh switch with the factory settings. |

Two emulated switches can be connected, for example to try spanning tree
between them. The
[rtl838x-qemu README](https://github.com/AlbrechtL/rtl838x-qemu#networking)
explains how.
