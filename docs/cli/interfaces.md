# Ports

The switch ports are named after the labels on the front: `lan1` … `lan8`
on the Zyxel GS1900-8. In the configuration they are
`interfaces interface lanN` with type `ianaift:ethernetCsmacd`.

What a port does with VLANs is described in [VLANs](vlans.md). This page
covers the other port settings.

## Enable and disable a port

```text
switch> set interfaces interface lan6 config enabled false
switch> commit
```

A disabled port has its link down. `enabled true` turns it on again.

## Description

A free-text label, for example what is connected:

```text
switch> set interfaces interface lan5 config description "Printer, room 2"
switch> commit
```

## Port status

```text
switch> show state text interfaces interface lan1
interface lan1 {
   config {
      name lan1;
      type ianaift:ethernetCsmacd;
      enabled true;
   }
   state {
      ...
      enabled true;
      admin-status UP;
      oper-status UP;
      counters {
         in-octets 1226;
         in-pkts 11;
         out-octets 1416;
         out-pkts 11;
      }
      ...
   }
   ...
   openconfig-if-ethernet:ethernet {
      state {
         ...
         hw-mac-address a6:55:c6:1d:fa:a0;
      }
   }
}
```

| Field | Meaning |
|---|---|
| `admin-status` | `UP` if the port is enabled in the configuration. |
| `oper-status` | `UP` when there is a link. `LOWER_LAYER_DOWN` when no cable is connected, `DOWN` when the port is disabled. |
| `counters` | Bytes (`octets`) and frames (`pkts`) received and sent since boot. |
| `hw-mac-address` | The port's MAC address. |

The rest of the output shows the fixed values of settings the switch does
not implement (see below).

To see all ports at once, use `show state text interfaces`. The
[status page](../installation/first-login.md#web-pages) at
`http://<switch-ip>/` shows the ports in a table.

## Remove a port from the configuration

A port that is not in the configuration at all is taken out of the bridge
and switched off. This is an alternative to `enabled false` for unused
ports:

```text
switch> delete interfaces interface lan7
switch> commit
```

In [port-based mode](vlans.md#port-based-vlans), also remove it from its
group in the same commit.

To bring it back, add it with all its settings:

```text
switch> set interfaces interface lan7 config name lan7
switch> set interfaces interface lan7 config type ianaift:ethernetCsmacd
switch> set interfaces interface lan7 config enabled true
switch> set interfaces interface lan7 ethernet switched-vlan config interface-mode ACCESS
switch> set interfaces interface lan7 ethernet switched-vlan config access-vlan 1
switch> commit
```

In the current firmware the `access-vlan 1` line is rejected by the CLI
(see [Known problems](../limitations.md#known-problems-in-the-current-firmware)); add the port
back over RESTCONF instead.

Only real ports can be added. Other names are rejected:

```text
validate: interface lan9: not a port of this switch (ports: lan1, lan2, lan3, lan4, lan5, lan6, lan7, lan8)
```

## Not supported

These port settings exist in the model, and `?` offers them, but the switch
rejects them. Every port auto-negotiates speed and duplex.

| Setting | Error |
|---|---|
| `auto-negotiate false` | `ethernet/config/auto-negotiate false is not supported, only true` |
| Fixed speed or duplex (`port-speed`, `duplex-mode`) | `ethernet/config/port-speed is not supported` |
| MTU | `config/mtu is not supported` |
| Flow control | `ethernet/config/enable-flow-control true is not supported, only false` |
| Hold time, dampening | `hold-time/config/up 100 is not supported, only 0` |
| Link aggregation (`aggregate-id`, `aggregation`), subinterfaces, MAC address, FEC | rejected |
