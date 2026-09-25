# First login

## Factory settings

A freshly installed switch starts with this configuration:

| Setting | Value |
|---|---|
| Ports | `lan1` … `lan8`, all enabled, all untagged members of VLAN 1 |
| VLANs | VLAN 1, named `default` |
| Management address | `192.168.1.1/24` on interface `vlan1` (VLAN 1) |
| DHCP client | off |
| Default gateway | none |
| Spanning tree | off |
| SNMP | off |

So every port is in the same network, and the switch answers on
`192.168.1.1` on all of them.

## Connecting

1. Connect your PC to any port.
2. Give the PC an address in the same network, for example `192.168.1.10`
   with netmask `255.255.255.0`.
3. Check that the switch answers: `ping 192.168.1.1`.

## Logging in

There are two user accounts. **Neither has a password.**

| User | Command | You get |
|---|---|---|
| `cli` | `ssh cli@192.168.1.1` | The switch CLI, directly. |
| `root` | `ssh root@192.168.1.1` | A Linux shell. Type `clixon_cli` to start the CLI. |

```text
$ ssh cli@192.168.1.1
switch>
```

`quit` leaves the CLI and closes the SSH session.

On the serial console (115200 8N1), the same users log in at the
`zyxel-gs1900-8-a1 login:` prompt.

!!! tip "In QEMU"
    With the [QEMU setup](qemu.md#2-boot-the-switch),
    use `ssh -p 2222 cli@127.0.0.1` and `http://127.0.0.1:8000/` instead of
    `192.168.1.1`.

!!! danger "No security"
    Anyone who can reach the switch over the network can log in as `root`,
    change the configuration over RESTCONF, and upload firmware. Only connect
    the management address to a network you trust. See
    [Limitations](../reference/limitations.md#security).

## Web pages

| URL | Content |
|---|---|
| `http://192.168.1.1/` | Status and settings page: firmware version, uptime, management address, ports, VLANs, spanning tree, SNMP. See [Web UI](../web-ui.md). |
| `http://192.168.1.1:8080/` | Firmware update (SWUpdate). See [Firmware update](firmware-update.md). |

## Next steps

Most people first want to:

1. Read [CLI basics](../cli/basics.md), especially the part about
   `commit` and `save`.
2. Give the switch an address in their own network, or turn on the DHCP
   client: [Management IP address](../cli/ip.md).
3. Set up VLANs: [VLANs](../cli/vlans.md).
