# Management IP address

The switch itself is reachable over IPv4 through **routed VLAN interfaces**.
A routed VLAN interface belongs to one VLAN and carries the switch's own
addresses in that VLAN. The factory setting has one of them: `vlan1`, in
VLAN 1, with the address `192.168.1.1/24`.

- The interface name can be anything, but `vlan<id>` keeps it readable.
- The VLAN can be given by its id or its name (for example `default`), or
  by a [port-based group](vlans.md#port-based-vlans).
- An interface can have static addresses, a DHCP client, or both.
- Each VLAN can have at most one routed VLAN interface. The switch does not
  route between them: they are only for reaching the switch itself.

!!! warning "There is no default gateway setting"
    With static addresses only, the switch has no default route. It can only
    be reached from inside the networks its addresses are in, not through a
    router. Only the DHCP client sets a default route (and DNS servers).
    See [Limitations](../limitations.md).

!!! danger "Don't lock yourself out"
    A change takes effect at once. Removing or changing the address you are
    connected to ends your session. Always add the new address first,
    connect to it, and only then remove the old one. If you do get locked
    out, power-cycle the switch: without a save, it boots with the previous
    configuration.

### DHCP client

The DHCP client:

- adds the leased address next to the static ones,
- sets the default route to the first router the server offers,
- uses the DNS servers and domain the server offers,
- sends the switch's host name,
- releases the lease when it is turned off.

Static addresses stay when the client is on. That is useful: if the DHCP
server fails, the switch can still be reached at its static address. To use
DHCP only, also delete the static address. When the client is turned off,
the leased address and the default route go away; make sure you are not
connected over the leased address, or keep a static one.

Only **one** routed VLAN interface can run the DHCP client, because it
decides the default route.

The lease shows:

| Field | Meaning |
|---|---|
| Address, prefix length | The leased address. Each address of the interface is marked as static or DHCP. |
| Router, DNS servers, domain | What the switch now uses. |
| Server | The DHCP server that gave the lease. |
| Lease time, remaining time | In seconds. |

There is no lease while the client is waiting for one.

### Management in a separate VLAN

A common setup keeps management traffic in its own VLAN. The
[example below](#example-management-in-vlan-99) uses VLAN 99, reached
through the uplink port `lan8`, which carries VLAN 99 tagged. Everything
else stays in VLAN 1. It takes three steps:

1. Declare the VLAN and make the uplink a trunk that carries it (see
   [VLANs](vlans.md)).
2. Create a routed VLAN interface in it with its address.
3. Connect over the new address, then remove the old one.

### Rules

| Rule | Error when broken |
|---|---|
| The VLAN of a routed VLAN interface must exist (declared VLAN, or [port-based group](vlans.md#port-based-vlans)). | `routed-vlan vlan "office": no VLAN has this name` |
| One routed VLAN interface per VLAN. | `interface vlan99: VLAN 99 already has a routed interface, mgmt2` |
| At most one DHCP client. | `ipv4 dhcp-client is already enabled on vlan1; only one interface may run a DHCP client` |
| Every static address needs a `prefix-length` (0 … 32). | `interface vlan99: 10.1.99.3: prefix-length is required` |
| IPv4 only. IPv6 settings are rejected. | `routed-vlan/ipv6/config/enabled false is not supported, only true` |

## Web UI

The **Management** card of the [status page](../getting-started/web-ui.md#status-page)
has one block per routed VLAN interface, for example `vlan1`, with its
link state (`UP` or down):

| Field | Meaning |
|---|---|
| VLAN | The VLAN (or port-based group) the interface is in. |
| IPv4 | Its addresses, each marked `static` or `dhcp`. |
| DHCP client | `off`, `waiting for a lease`, or `bound`. |
| Gateway, DNS, Domain, Lease expires in | From the DHCP lease, when there is one. |

**Edit** on an interface changes its DHCP client and its static IPv4
addresses, one `address/prefix-length` per line.

Removing the address the page is open on cuts it off. The page then links
to the new address, where you check that it works and click **Save
configuration**. If you cannot reach the switch any more, reboot it.

!!! note "Not in the web UI"
    Creating or deleting a routed VLAN interface, and moving it to another
    VLAN, is done with the [CLI](#cli) or [RESTCONF](#restconf).

## CLI

The factory setting:

```text
switch> show configuration cli interfaces interface vlan1
interface vlan1
interface vlan1 config name vlan1
interface vlan1 config type ianaift:l3ipvlan
interface vlan1 config enabled true
interface vlan1 routed-vlan config vlan 1
interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1
interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1 config ip 192.168.1.1
interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1 config prefix-length 24
```

`type ianaift:l3ipvlan` makes it a routed VLAN interface, and
`routed-vlan config vlan 1` attaches it to VLAN 1 (`vlan default` would do
the same).

### Change the static address

Example: move the switch from `192.168.1.1/24` to `10.0.0.2/24`.

1. Add the new address next to the old one:

    ```text
    switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 10.0.0.2 config ip 10.0.0.2
    switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 10.0.0.2 config prefix-length 24
    switch> commit
    ```

2. Change your PC to the new network, and log in again with
   `ssh <username>@10.0.0.2`.

3. Remove the old address and save:

    ```text
    switch> delete interfaces interface vlan1 routed-vlan ipv4 addresses address 192.168.1.1
    switch> commit
    switch> save
    ```

The address appears twice in the command: once as the list key
(`address 10.0.0.2`) and once as the value (`config ip 10.0.0.2`). Both
must be the same.

To change only the prefix length of an existing address, set it again:

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 10.0.0.2 config prefix-length 16
switch> commit
```

### Turn the DHCP client on

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 config dhcp-client true
switch> commit
switch> save
```

A second interface with a DHCP client is rejected:

```text
validate: interface vlan20: ipv4 dhcp-client is already enabled on vlan1; only one interface may run a DHCP client
```

### See the lease

`show state` shows the lease and, for each address, where it comes from
(`origin STATIC` or `origin DHCP`):

```text
switch> show state text interfaces interface vlan1
...
         addresses {
            address 10.99.0.107 {
               state {
                  ip 10.99.0.107;
                  prefix-length 24;
                  type PRIMARY;
                  origin DHCP;
               }
            }
            address 192.168.1.1 {
               config {
                  ip 192.168.1.1;
                  prefix-length 24;
               }
               state {
                  ip 192.168.1.1;
                  prefix-length 24;
                  type PRIMARY;
                  origin STATIC;
               }
            }
         }
...
         state {
            enabled true;
            dhcp-client true;
            clixon-switch:dhcp-lease {
               address 10.99.0.107;
               prefix-length 24;
               router [
                  10.99.0.1
              ]
               dns-server [
                  10.99.0.53
              ]
               domain lab.example;
               server 10.99.0.1;
               lease-time 600;
               remaining-time 593;
            }
         }
```

### Turn the DHCP client off

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 config dhcp-client false
switch> commit
switch> save
```

### Example: management in VLAN 99

!!! bug "Known problem"
    In the current firmware the CLI on the switch rejects VLAN ids, which
    steps 1 and 2 need. Do these steps over RESTCONF for now, see
    [Known problems](../limitations.md#known-problems-in-the-current-firmware).

1. Declare the VLAN, and make `lan8` a trunk that carries it:

    ```text
    switch> set vlans vlan 99 config vlan-id 99
    switch> set vlans vlan 99 config name mgmt
    switch> delete interfaces interface lan8 ethernet switched-vlan config access-vlan 1
    switch> set interfaces interface lan8 ethernet switched-vlan config interface-mode TRUNK
    switch> set interfaces interface lan8 ethernet switched-vlan config native-vlan 1
    switch> set interfaces interface lan8 ethernet switched-vlan config trunk-vlans 99
    ```

2. Create the routed VLAN interface with its address:

    ```text
    switch> set interfaces interface vlan99 config name vlan99
    switch> set interfaces interface vlan99 config type ianaift:l3ipvlan
    switch> set interfaces interface vlan99 routed-vlan config vlan 99
    switch> set interfaces interface vlan99 routed-vlan ipv4 addresses address 10.1.99.2 config ip 10.1.99.2
    switch> set interfaces interface vlan99 routed-vlan ipv4 addresses address 10.1.99.2 config prefix-length 24
    switch> commit
    ```

3. Log in over `10.1.99.2`. When that works, remove the address from
   `vlan1`, or the whole interface:

    ```text
    switch> delete interfaces interface vlan1
    switch> commit
    switch> save
    ```

## RESTCONF

!!! note "Coming later"
    Examples are not written yet. See [Using RESTCONF](../getting-started/restconf.md)
    for how the CLI paths above map to RESTCONF resources.

A routed VLAN interface is configured under:

```text
/restconf/data/openconfig-interfaces:interfaces/interface=vlan1
/restconf/data/openconfig-interfaces:interfaces/interface=vlan1/openconfig-vlan:routed-vlan/openconfig-if-ip:ipv4
```

The [clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#dhcp-client)
has an example that turns on the DHCP client.
