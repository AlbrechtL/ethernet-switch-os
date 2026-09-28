# Getting started

Don't have Ethernet Switch OS on the switch yet? Start with
[Download](installation/download.md) instead.

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

There are two user accounts:

| User | Where | Password | You get |
|---|---|---|---|
| `cli` | SSH, serial console, web | The admin password, set at the first login | The switch CLI, directly. |
| `root` | Serial console only | None | A Linux shell. Type `clixon_cli` to start the CLI. |

### First login: set the admin password

A new switch, and one after a [factory reset](installation/update.md#factory-reset),
has no admin password yet. The first login as `cli` asks for one, over SSH,
on the serial console or in the web page. It has to have 8 to 128
characters, and it is the password for all three from then on.

```text
$ ssh cli@192.168.1.1
Set the admin password. It is used for SSH, the serial console and the web interface.
New password:
Repeat new password:
Password changed.

  --- Random switch joke ---
  The switch is on a strict diet and counts every single byte.
  1500 bytes per meal on weekdays, jumbo frames on the weekend.

switch>
```

From then on, `ssh cli@192.168.1.1` asks for that password.

Every interactive login prints a random switch joke first, marked with a
`--- Random switch joke ---` header.

`quit` leaves the CLI and closes the SSH session.

On the serial console (115200 8N1), log in at the
`zyxel-gs1900-8-a1 login:` prompt, as `cli` with the admin password or as
`root` without a password. `root` cannot log in over SSH.

!!! warning "Set the password before connecting the switch to a network"
    Until the admin password is set, anyone who reaches the switch can set
    it. Do the first login with only your PC connected.

### Changing or resetting the password

- In the CLI: `password` asks for the current password and the new one.
- In the web page: **Administration → Change password**.
- Forgotten: a [factory reset](installation/update.md#factory-reset) erases
  the password together with all settings. With a serial cable, `root` can
  set a new one instead and keep the settings:
  `ethernet-switch-os-set-password cli`.
!!! tip "In QEMU"
    In the emulated [Zyxel GS1900-8](installation/zyxel-gs1900-8.md#5-start-the-switch)
    or the [QEMU x86-64 switch](installation/qemu-x86-64.md#3-start-the-switch), use `ssh -p 2222 cli@127.0.0.1` and `https://127.0.0.1:8443/` instead of
    `192.168.1.1`.

!!! note "Security"
    Management traffic is encrypted (SSH, HTTPS) and needs the admin
    password. There is one admin account and no read-only access, and the
    HTTPS certificate is self-signed. See [Limitations](limitations.md#security).

## Web pages

| URL | Content |
|---|---|
| `https://192.168.1.1/` | Status and settings page: firmware version, uptime, management address, ports, VLANs, spanning tree, SNMP, password. See [Web UI](web-ui.md). |
| `https://192.168.1.1/update/` | Firmware update (SWUpdate). See [Firmware update](installation/update.md#firmware-update). |

The certificate is made by the switch itself, so the browser warns that it
does not know who issued it. Accept it once for the switch's address. Then
log in as `cli` with the admin password.

## Next steps

Most people first want to:

1. Read [CLI basics](cli/basics.md), especially the part about
   `commit` and `save`.
2. Give the switch an address in their own network, or turn on the DHCP
   client: [Management IP address](cli/ip.md).
3. Set up VLANs: [VLANs](cli/vlans.md).
