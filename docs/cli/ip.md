# Management IP address

The switch itself is reachable over IPv4 through **routed VLAN interfaces**.
A routed VLAN interface belongs to one VLAN and carries the switch's own
addresses in that VLAN. The factory setting has one of them:

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

- `vlan1` is the interface name. Any name works, but `vlan<id>` keeps it
  readable.
- `type ianaift:l3ipvlan` makes it a routed VLAN interface.
- `routed-vlan config vlan 1` attaches it to VLAN 1. The VLAN can also be
  given by its name, for example `vlan default`.
- An interface can have static addresses, a DHCP client, or both.

!!! warning "There is no default gateway setting"
    With static addresses only, the switch has no default route. It can only
    be reached from inside the networks its addresses are in, not through a
    router. Only the DHCP client sets a default route (and DNS servers).
    See [Limitations](../limitations.md).

!!! danger "Don't lock yourself out"
    A commit takes effect at once. Removing or changing the address you are
    connected to ends your SSH session. Always add the new address first,
    commit, connect to it, and only then remove the old one. If you do get
    locked out, power-cycle the switch: without `save`, it boots with the
    previous configuration.

## Change the static address

Example: move the switch from `192.168.1.1/24` to `10.0.0.2/24`.

1. Add the new address next to the old one:

    ```text
    switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 10.0.0.2 config ip 10.0.0.2
    switch> set interfaces interface vlan1 routed-vlan ipv4 addresses address 10.0.0.2 config prefix-length 24
    switch> commit
    ```

2. Change your PC to the new network, and log in again with
   `ssh cli@10.0.0.2`.

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

## Use a DHCP client

Turn on the DHCP client of `vlan1`:

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 config dhcp-client true
switch> commit
switch> save
```

The static address stays. That is useful: if the DHCP server fails, the
switch can still be reached at `192.168.1.1`. To use DHCP only, also delete
the static address (see above).

The DHCP client:

- adds the leased address next to the static ones,
- sets the default route to the first router the server offers,
- uses the DNS servers and domain the server offers,
- sends the switch's host name,
- releases the lease when it is turned off.

Only **one** routed VLAN interface can run the DHCP client, because it
decides the default route. A second one is rejected:

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

`router`, `dns-server` and `domain` are what the switch now uses. There is
no `dhcp-lease` while the client has no lease yet.

### Turn DHCP off

```text
switch> set interfaces interface vlan1 routed-vlan ipv4 config dhcp-client false
switch> commit
switch> save
```

The client releases the lease. The leased address and the default route go
away, and the static addresses stay. Make sure you are not connected over
the leased address, or keep a static one.

## Management in a separate VLAN

!!! bug "Known problem"
    In the current firmware the CLI on the switch rejects VLAN ids, which
    steps 1 and 2 need. Do these steps over RESTCONF for now, see
    [Known problems](../limitations.md#known-problems-in-the-current-firmware).

A common setup keeps management traffic in its own VLAN. Example: VLAN 99
for management, reached through the uplink port `lan8`, which carries VLAN
99 tagged. Everything else stays in VLAN 1.

1. Declare the VLAN, and make `lan8` a trunk that carries it (see
   [VLANs](vlans.md) for the details):

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

Each VLAN can have at most one routed VLAN interface. The switch does
not route between them: they are only for reaching the switch itself.

## Rules

| Rule | Error when broken |
|---|---|
| The VLAN of a routed VLAN interface must exist (declared VLAN, or [port-based group](vlans.md#port-based-vlans)). | `routed-vlan vlan "office": no VLAN has this name` |
| One routed VLAN interface per VLAN. | `interface vlan99: VLAN 99 already has a routed interface, mgmt2` |
| At most one DHCP client. | `ipv4 dhcp-client is already enabled on vlan1; ...` |
| Every static address needs a `prefix-length` (0 … 32). | `interface vlan99: 10.1.99.3: prefix-length is required` |
| IPv4 only. IPv6 settings are rejected. | `routed-vlan/ipv6/config/enabled false is not supported, only true` |
