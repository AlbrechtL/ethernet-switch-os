# YANG models

The data models describe much more than the switch implements. The switch
accepts only the settings below and rejects everything else when you
commit, with an error such as `config/mtu is not supported`. Settings it
does not implement are accepted only with their default value, because the
data model fills them in everywhere (for example `auto-negotiate true` or
`loopback-mode NONE`).

Paths are written as in the CLI. `{…}` lists the supported leaves.

## Interfaces (`openconfig-interfaces`, `openconfig-if-ethernet`, `openconfig-vlan`, `openconfig-if-ip`)

| Path | Notes |
|---|---|
| `interfaces interface <name> config {name, type, enabled, description}` | `type` is `ianaift:ethernetCsmacd` for switch ports or `ianaift:l3ipvlan` for routed VLAN interfaces. |
| `interfaces interface <port> ethernet switched-vlan config {interface-mode, access-vlan, native-vlan, trunk-vlans}` | `interface-mode` is `ACCESS` or `TRUNK`. 802.1Q mode only. |
| `interfaces interface <name> routed-vlan config vlan` | VLAN id or name, or port-based group id or name. |
| `interfaces interface <name> routed-vlan ipv4 addresses address <ip> config {ip, prefix-length}` | Static IPv4 addresses. |
| `interfaces interface <name> routed-vlan ipv4 config dhcp-client` | At most one interface. |

## VLANs (`clixon-switch`)

| Path | Notes |
|---|---|
| `vlans vlan <id> config {vlan-id, name, status}` | `status` is `ACTIVE` (default) or `SUSPENDED`. 802.1Q mode only. |
| `switch config vlan-mode` | `DOT1Q` (default) or `PORT_BASED`. |
| `port-based-vlans group <id> config {id, name, port}` | Port-based mode only. |

## Spanning tree (`openconfig-spanning-tree`)

| Path | Notes |
|---|---|
| `stp global config {enabled-protocol, bpdu-guard, bpdu-filter}` | `enabled-protocol`: one of `oc-stp-types:RSTP`, `oc-stp-types:MSTP`, `sw:STP`. |
| `stp rstp config {hello-time, max-age, forwarding-delay, hold-count, bridge-priority}` | Also used for STP. |
| `stp rstp interfaces interface <port> config {name, cost, port-priority}` | |
| `stp mstp config {name, revision, max-hop, hello-time, max-age, forwarding-delay, hold-count, bridge-priority}` | `bridge-priority` is the CIST's. |
| `stp mstp interfaces interface <port> config {name, cost, port-priority}` | CIST ports. |
| `stp mstp mst-instances mst-instance <id> config {mst-id, vlan, bridge-priority}` | |
| `stp mstp mst-instances mst-instance <id> interfaces interface <port> config {name, cost, port-priority}` | |
| `stp interfaces interface <port> config {name, edge-port, link-type, guard, bpdu-guard, bpdu-filter}` | `guard` is `ROOT` or `NONE`. |

## SNMP (`ietf-snmp`)

| Path | Notes |
|---|---|
| `snmp engine {enabled, engine-id}` | |
| `snmp engine version v3` | Required; the only version. |
| `snmp engine listen <name> udp {ip, port}` | IPv4 addresses. |
| `snmp usm local user <name> auth sha key` | Required for every user. 20 octets. |
| `snmp usm local user <name> priv aes key` | Optional. 16 octets. |
| `snmp vacm group <name> member <user> security-model usm` | |
| `snmp vacm group <name> access "" <model> <level> read-view <view>` | `<model>` is `usm` or `any`, `<level>` is `auth-no-priv` or `auth-priv`. |
| `snmp vacm view <name> {include, exclude}` | Numeric OIDs, no wildcards. |

## System (`clixon-switch`)

| Path | Notes |
|---|---|
| `system config {contact, location}` | One line each, up to 255 characters. |

## Status only

These show up in `show state` but cannot be configured:

- `system state`: host name, firmware, uptime, load, memory, clock
- port counters, `oper-status`, MAC address
- `routed-vlan ipv4 state dhcp-lease` and each address's `origin`
- `stp ... state`: roles, port states, root bridge
- `snmp engine engine-id-in-use`
- the MIBs served over SNMP (BRIDGE-MIB, Q-BRIDGE-MIB, RSTP-MIB)
