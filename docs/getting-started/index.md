# Getting started

Don't have Ethernet Switch OS on the switch yet? Start with
[Download](../installation/download.md) instead.

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
| LLDP | on, on all ports |
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
| Admin, with a name you choose | SSH, serial console, web | Chosen in the first-login setup | The switch CLI, directly. |
| `root` | Serial console only | None | A Linux shell. Type `clixon_cli` to start the CLI. |

### First login: create the admin account

A new switch, and one after a [factory reset](../installation/update.md#factory-reset),
has no admin account yet. Nobody can log in over SSH until you create it in
the web page:

1. Open `https://192.168.1.1/` and accept the certificate (see
   [Web pages](#web-pages)).
2. The page shows only **Set up the admin account**. Choose a username and a
   password, then click **Create account**.
    - Username: a lower case letter or `_`, then up to 31 lower case
      letters, digits, `_` or `-`. Names the switch uses itself, such as
      `root`, are refused.
    - Password: 8 to 128 characters.
3. The browser asks for the login next: the username and password you just
   chose.

The same username and password now log in everywhere:

```text
$ ssh ops@192.168.1.1
ops@192.168.1.1's password:

  --- Random switch joke ---
  The switch is on a strict diet and counts every single byte.
  1500 bytes per meal on weekdays, jumbo frames on the weekend.

switch>
```

The username stays until a factory reset. Without a browser, a script can
create the account with the [RESTCONF](../features/administration.md#create-the-admin-account) RPC `set-password`,
and `root` on the serial console with `ethernet-switch-os-set-password`.

Every interactive login prints a random switch joke first, marked with a
`--- Random switch joke ---` header.

`quit` leaves the CLI and closes the SSH session.

On the serial console (115200 8N1), log in at the
`zyxel-gs1900-8-a1 login:` prompt, with the admin username and password, or
as `root` without a password. `root` cannot log in over SSH.

!!! warning "Create the admin account before connecting the switch to a network"
    Until the admin account exists, anyone who reaches the switch's web page
    can create it. Do the setup with only your PC connected.

### Changing or resetting the password

- In the CLI: `password` asks for the current password and the new one.
- In the web page: **Administration → Change password**.
- Forgotten: a [factory reset](../installation/update.md#factory-reset) erases
  the admin account together with all settings. With a serial cable, `root`
  can set a new password instead and keep the settings:
  `ethernet-switch-os-set-password`.
!!! tip "In QEMU"
    In the emulated [Zyxel GS1900-8](../installation/zyxel-gs1900-8.md#5-start-the-switch)
    or the [QEMU x86-64 switch](../installation/qemu-x86-64.md#3-start-the-switch), use `https://127.0.0.1:8443/` and `ssh -p 2222 <username>@127.0.0.1` instead of
    `192.168.1.1`.

!!! note "Security"
    Management traffic is encrypted (SSH, HTTPS) and needs the admin
    login. There is one admin account and no read-only access, and the
    HTTPS certificate is self-signed. See [Limitations](../limitations.md#security).

## Web pages

| URL | Content |
|---|---|
| `https://192.168.1.1/` | Status and settings page: firmware version, uptime, management address, ports, VLANs, spanning tree, LLDP neighbors, SNMP, password. See [Using the web UI](web-ui.md). |
| `https://192.168.1.1/update/` | Firmware update (SWUpdate). See [Firmware update](../installation/update.md#firmware-update). |

The certificate is made by the switch itself, so the browser warns that it
does not know who issued it. Accept it once for the switch's address. On a
new switch the page then shows the [first-login setup](#first-login-create-the-admin-account);
afterwards the browser asks for the admin username and password.

## Three ways to configure

The switch has one configuration, and three ways to change it. All three
work on the same data, so a change made in one shows up in the others.

| Interface | Where | Good for |
|---|---|---|
| [Web UI](web-ui.md) | `https://<switch-ip>/` | The everyday settings, and the status at a glance. |
| [CLI](cli.md) | `ssh <username>@<switch-ip>`, serial console | Every setting, interactively. |
| [RESTCONF](restconf.md) | `https://<switch-ip>/restconf` | Every setting, from scripts and tools. |

Changes take effect at once, but are **not saved** until you save them:
**Save configuration** in the web UI, `save` in the CLI, or a
`copy-config` over RESTCONF. A reboot goes back to the saved
configuration, which is also how you recover from a change that cut you
off. The CLI has one more step before that: changes are collected in a
candidate and only take effect with `commit`.

Each feature has its own page, with an introduction and then one section
per interface:

| Feature | Web UI | CLI | RESTCONF |
|---|---|---|---|
| [System information](../features/system.md) | ✓ | ✓ | ✓ |
| [Management IP address](../features/management-ip.md) | addresses and DHCP client | ✓ | ✓ |
| [Ports](../features/ports.md) | ✓ | ✓ | ✓ |
| [VLANs](../features/vlans.md) | ✓ | ✓ | ✓ |
| [Spanning tree](../features/spanning-tree.md) | without MSTP and guards | ✓ | ✓ |
| [LLDP](../features/lldp.md) | ✓ | ✓ | ✓ |
| [SNMP](../features/snmp.md) | users, on/off | ✓ | ✓ |
| [Password and factory reset](../features/administration.md) | ✓ | ✓ | ✓ |

## Next steps

Most people first want to:

1. Read [Using the CLI](cli.md), especially the part about
   `commit` and `save`, or [Using the web UI](web-ui.md).
2. Give the switch an address in their own network, or turn on the DHCP
   client: [Management IP address](../features/management-ip.md).
3. Set up VLANs: [VLANs](../features/vlans.md).
