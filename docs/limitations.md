# Limitations

Ethernet Switch OS is a proof of concept. This page lists what it does not
do yet, so you can decide whether it fits your use.

## Security

!!! danger
    There is **no access control** of any kind. Do not connect the
    management address to an untrusted network.

- The users `root` and `cli` have **no password**, and passwords cannot be
  set through the configuration.
- RESTCONF and the web page have no authentication and no TLS: anyone who
  reaches port 80 can read and change the configuration.
- The firmware update page on port 8080 has no authentication either.
- There are no user accounts, roles or read-only access.

## Known problems in the current firmware

These are bugs, found while testing this guide on the emulated switch.
The guide shows the commands as they are meant to work.

**The CLI rejects most numbers on the switch.** Any value whose allowed
range starts above 0 is refused, whatever the value:

```text
switch> set vlans vlan 20 config vlan-id 20
CLI syntax error: "set vlans vlan 20 config vlan-id 20": Number 20 out of range: 1 - 4094
```

This affects all VLAN ids (`vlans`, `access-vlan`, `native-vlan`,
`trunk-vlans`, port-based group ids, MSTI ids), and the spanning tree
timers, `hold-count`, `max-hop`, port `cost` and `port-priority`. Values
whose range starts at 0 work, for example `prefix-length` and
`bridge-priority`. The same commands work in the x86 development container,
so the cause is in the CLI's number parsing on the switch's big-endian MIPS
processor.

Until it is fixed, set these values over RESTCONF. For example, to declare
VLAN 20 and put `lan3` into it:

```sh
curl -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"clixon-switch:vlans":{"vlan":[{"vlan-id":20,"config":{"vlan-id":20,"name":"office"}}]}}' \
    http://192.168.1.1/restconf/data/clixon-switch:vlans
curl -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"openconfig-vlan:config":{"interface-mode":"ACCESS","access-vlan":20}}' \
    http://192.168.1.1/restconf/data/openconfig-interfaces:interfaces/interface=lan3/openconfig-if-ethernet:ethernet/openconfig-vlan:switched-vlan/config
```

The change is applied at once; `save` in the CLI makes it permanent.
Routed VLAN interfaces can refer to their VLAN by **name** in the CLI
(`routed-vlan config vlan office`), which is not affected.

**`snmp` is missing from the CLI.** `set snmp ...` fails with
`Unknown command`. Configure [SNMP](snmp/index.md) over RESTCONF; the
[clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#snmp)
has a complete example.

**`show compare` fails** with
`compare_dbs: ... Expected arguments: <db1> <db2> <format>`.

## Firmware update

- **One firmware slot, no fallback.** An update overwrites the running
  system in place. A power failure or reset while it is written leaves the
  switch unable to start. Recovery needs the serial console and TFTP, and
  erases the configuration. See [Firmware update](getting-started/firmware-update.md).
- No automatic rollback if the new firmware does not work.
- Update files are not signed.

## IP and management

- **No static default gateway, static routes or static DNS servers.** With
  static addresses, the switch can only be reached from its own subnets.
  Only the DHCP client sets a default route and DNS.
- No IPv6.
- The host name cannot be configured.
- No time synchronisation (NTP), no time zone. The clock starts at the
  same fixed time (2018-03-09 12:34:56 UTC) on every boot, so time stamps
  in logs are not real times.
- No syslog forwarding.
- No routing between VLANs. Routed VLAN interfaces are only for reaching
  the switch itself.
- At most one DHCP client.

## Ports

- No fixed speed or duplex; every port auto-negotiates.
- No MTU or jumbo frame setting.
- No flow control.
- No link aggregation (LAG, LACP).
- No port mirroring, storm control, rate limiting or port security.
- Albrecht RTL8382MI test switch: ports 17 to 20 (RTL8214FC combo ports)
  are driven as copper ports only; their SFP side is not supported.

## Layer 2

- No IGMP/MLD snooping.
- No LLDP.
- Spanning tree: no Rapid PVST, loop guard, bridge assurance, EtherChannel
  guard or automatic recovery after BPDU guard.

## SNMP

- SNMPv3 only; no SNMPv1/v2c or communities.
- Read-only.
- No traps or informs.
- SHA and AES only; no MD5 or DES.
- No MIB for MSTP instances.

## CLI

- No factory-reset command (see [Maintenance](getting-started/maintenance.md#factory-reset)).
- No reboot command; use the root shell.
- Error messages include internal details (timestamps, function names) in
  front of the actual reason.
