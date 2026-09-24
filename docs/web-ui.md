# Web UI

The switch has two web pages:

| URL | Page |
|---|---|
| `http://<switch-ip>/` | [Status page](#status-page): what the switch is doing. Read-only. |
| `http://<switch-ip>:8080/` | [Firmware update page](#firmware-update-page). |

Both work in any current browser and need no login.

!!! danger "No password"
    Anyone who can reach the switch can open both pages, and can install
    firmware through the update page. See
    [Limitations](reference/limitations.md#security).

## Status page

![The status page of a switch with a DHCP lease](assets/status-page.png)

The status page shows the state of the switch at a glance. You cannot
change anything here; use the [CLI](cli/basics.md) or RESTCONF for that.

It updates itself every 5 seconds while it is visible. **Refresh** updates
it at once, and the time of the last update is next to it.

### Header

- The switch's host name and firmware version.
- **Firmware update** opens the [firmware update page](#firmware-update-page)
  in a new tab.

### System

| Field | Meaning |
|---|---|
| Host name | The switch's host name. |
| Firmware | Name and version of the installed firmware. |
| Kernel | Linux kernel version. |
| Uptime | Time since the last boot. |
| Switch clock | The switch's clock, in your browser's time zone. It is not synchronised and starts at the same fixed date on every boot. |
| Load | CPU load over 1, 5 and 15 minutes. |
| Memory | RAM in use. |

### Management

One block per [routed VLAN interface](cli/ip.md), for example `vlan1`, with
its link state (`UP` or down):

| Field | Meaning |
|---|---|
| VLAN | The VLAN (or port-based group) the interface is in. |
| IPv4 | Its addresses, each marked `static` or `dhcp`. |
| DHCP client | `off`, `waiting for a lease`, or `bound`. |
| Gateway, DNS, Domain, Lease expires in | From the DHCP lease, when there is one. |

### Ports

One row per port:

| Column | Meaning |
|---|---|
| Link | `UP` with a link. `LOWER_LAYER_DOWN` or `DOWN` without. `DISABLED` if the port is switched off in the configuration. |
| VLAN | `access 20`, `trunk: native 1, 20, 30..40`, or `group 1 (office)` in port-based mode. |
| Description | The port's description. |
| Received, Sent | Bytes since boot. |
| MAC address | The port's MAC address. |

Ports that were [removed from the configuration](cli/interfaces.md#remove-a-port-from-the-configuration)
are not listed.

### VLANs

In 802.1Q mode, the declared VLANs with name, status (`UP` for active,
`SUSPENDED`) and the ports that carry them. In
[port-based mode](cli/vlans.md#port-based-vlans), the groups with their
names and member ports.

### When the page shows an error

"Cannot read the switch's state" means the page could not get the data
from the switch, for example while it reboots. The page keeps trying every
5 seconds and recovers by itself.

## Firmware update page

![The firmware update page](assets/swupdate-page.jpg)

The update page is SWUpdate's own web interface. How to use it, and what
to watch out for, is described in
[Firmware update](getting-started/firmware-update.md#update-in-the-browser).
In short:

- **Software Update**: drop a `.swu` file here, or click to choose one. The
  upload and installation start at once.
- The status line below it ("Update not started", "Updated successfully",
  "Update failed") and the progress bar show how far it got.
- **Messages** (click to open) lists what SWUpdate is doing, including the
  reason when an update fails. It only shows messages of updates that run
  while the page is open.
- **Restart System** (top right) reboots the switch at once. Committed but
  unsaved configuration changes are lost.
