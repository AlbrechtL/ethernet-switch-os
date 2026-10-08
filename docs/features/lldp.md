# LLDP

LLDP (Link Layer Discovery Protocol, IEEE 802.1AB) lets neighboring devices
tell each other who they are. The switch announces its name, its port and
its management address on every port, and learns the same from the switches,
routers, access points and phones connected to it. This answers "what is
plugged into `lan5`?" without following the cable, and lets network
management tools draw the topology.

LLDP is **on** by factory default, on all ports. The switch sends an LLDP
frame on each port every 30 seconds, and neighbors keep its information for
four times that (120 seconds). LLDP frames never leave the link they are
sent on, so a neighbor is always directly connected.

What the switch announces:

| Information | Value |
|---|---|
| Chassis ID | The switch's MAC address |
| Port ID and port description | The port's name, for example `lan5` |
| System name | The host name, unless a system name is configured |
| System description | The firmware name and version, for example `Ethernet Switch OS 1.0`, unless a description is configured. SNMP's `sysDescr` says the same. |
| Capabilities | Bridge, and router while the switch routes IP |
| Management address | The switch's IPv4 address on its routed VLAN interface, and an IPv6 address (usually the link-local one) |

!!! warning "What neighbors learn"
    Every device on a port with LLDP learns the switch's name, firmware
    version and management address. Turn LLDP off on ports that face
    networks you do not trust, or leave out the management address (see
    below).

### Settings

| Setting | Default | Allowed |
|---|---|---|
| `enabled` | `true` | `false` turns LLDP off on all ports. |
| `hello-timer` | 30 | 1 … 3600 seconds between two LLDP frames. Neighbors keep the information for four times this. |
| `system-name` | the host name | One line, up to 255 characters. |
| `system-description` | the firmware name and version | One line, up to 255 characters. |
| `suppress-tlv-advertisement` | none | `oc-lldp-types:MANAGEMENT_ADDRESS` leaves out the management address, `oc-lldp-types:SYSTEM_CAPABILITIES` the capabilities. |
| per port: `enabled` | `true` | `false` turns LLDP off on the port: the switch neither announces itself there nor learns the neighbor. |

The switch checks these rules when you commit:

| Rule | Error when broken |
|---|---|
| `hello-timer` is 1 … 3600 | `lldp: hello-timer 0 is out of range 1..3600` |
| Only the management address and the capabilities can be left out: chassis ID, port ID and TTL are mandatory, and the switch always sends port description, system name and system description | `lldp: suppress-tlv-advertisement PORT_ID is not supported, only SYSTEM_CAPABILITIES and MANAGEMENT_ADDRESS` |
| A port setting names a switch port | `lldp: interfaces: interface vlan1 is not a configured switch port` |
| Name and description are one line | `lldp: system-name must be one line without control characters` |

### Status

For the switch:

| Field | Meaning |
|---|---|
| `enabled`, `hello-timer`, `suppress-tlv-advertisement` | The settings in use |
| `system-name`, `system-description` | What the switch announces |
| `chassis-id`, `chassis-id-type` | The switch's chassis ID (`MAC_ADDRESS`) |
| `counters` | LLDP frames of all ports: `frame-in` received, `frame-out` sent, `frame-discard` received but invalid, `tlv-unknown` parts not understood, `entries-aged-out` neighbors forgotten because they stopped sending |

Per port, `enabled` and the same counters (without `entries-aged-out`), and
one entry per neighbor:

| Field | Meaning |
|---|---|
| `id` | A number the switch gives the neighbor |
| `system-name`, `system-description` | The neighbor's name and description |
| `chassis-id`, `chassis-id-type` | The neighbor's identity, usually its MAC address (`MAC_ADDRESS`) |
| `port-id`, `port-id-type`, `port-description` | The neighbor's port the switch is connected to: its name (`INTERFACE_NAME`), MAC address (`MAC_ADDRESS`) or a local name (`LOCAL`) |
| `management-address`, `management-address-type` | Where the neighbor can be managed. Type `1` is IPv4, `2` IPv6. With several addresses, the first IPv4 address is shown. |
| `capabilities` | What the neighbor is (`MAC_BRIDGE`, `ROUTER`, `WLAN_ACCESS_POINT`, `TELEPHONE`, `STATION_ONLY`, …), each with `enabled` true if that function is active |
| `ttl` | How many seconds the neighbor asked to be remembered |
| `age` | Seconds since the neighbor's information last changed |

A neighbor that stops sending is forgotten once its `ttl` has passed. A
port can have more than one neighbor, for example behind an unmanaged
switch.

## Web UI

The **LLDP** card of the [status page](../getting-started/web-ui.md#status-page)
shows whether LLDP is on, the interval, and the system name and chassis ID
the switch announces. Below, one row per port with whether LLDP is on there,
and its neighbor: name (the description shows when you hover over it), the
neighbor's port, chassis ID, management address and capabilities. A port
with several neighbors has a row for each.

- **Edit** on the card turns LLDP on or off, and sets the interval, the
  system name and description, and whether the management address and the
  capabilities are announced.
- **Edit** on a port turns LLDP on or off for that port.

Remember **Save configuration** to keep the changes after a reboot.

## CLI

### Turn LLDP off and on

```text
switch> set lldp config enabled false
switch> commit
switch> save
```

`set lldp config enabled true`, or `delete lldp config enabled`, turns it on
again.

### Turn LLDP off on one port

```text
switch> set lldp interfaces interface lan8 config name lan8
switch> set lldp interfaces interface lan8 config enabled false
switch> commit
switch> save
```

### Change the interval

```text
switch> set lldp config hello-timer 10
switch> commit
```

### Name and description

By default the switch announces its host name and its firmware. To announce
something else:

```text
switch> set lldp config system-name core-1
switch> set lldp config system-description "Rack 4, top"
switch> commit
```

`delete lldp config system-name` goes back to the host name.

### Leave out the management address

```text
switch> set lldp config suppress-tlv-advertisement oc-lldp-types:MANAGEMENT_ADDRESS
switch> commit
```

### Neighbors

`show lldp` shows the settings, the counters, and the neighbors of each port:

```text
switch> show lldp
openconfig-lldp:lldp {
   state {
      enabled true;
      hello-timer 30;
      system-name switch;
      system-description "Ethernet Switch OS 1.0";
      chassis-id 02:00:5e:10:00:01;
      chassis-id-type MAC_ADDRESS;
      ...
   }
   interfaces {
      ...
      interface lan8 {
         state {
            name lan8;
            enabled true;
            ...
         }
         neighbors {
            neighbor 1 {
               state {
                  system-name office-switch;
                  system-description "Example switch 2.1";
                  chassis-id c2:03:75:2a:2b:71;
                  chassis-id-type MAC_ADDRESS;
                  id 1;
                  age 3;
                  ttl 120;
                  port-id port3;
                  port-id-type INTERFACE_NAME;
                  port-description port3;
                  management-address 10.99.0.1;
                  management-address-type 1;
               }
               capabilities {
                  capability oc-lldp-types:MAC_BRIDGE {
                     state {
                        name oc-lldp-types:MAC_BRIDGE;
                        enabled true;
                     }
                  }
                  ...
               }
            }
         }
      }
   }
}
```

## RESTCONF

LLDP is configured under:

```text
/restconf/data/openconfig-lldp:lldp
```

RESTCONF spells identities out in full, for example
`openconfig-lldp-types:MANAGEMENT_ADDRESS`.

Turn LLDP off:

```sh
curl -k -u ops -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"openconfig-lldp:config":{"enabled":false}}' \
    https://192.168.1.1/restconf/data/openconfig-lldp:lldp/config
```

Send every 10 seconds, with a name of its own, without the management
address, and not on `lan8` (`/lldp` may not exist yet, so the PATCH goes to
the datastore):

```sh
curl -k -u ops -X PATCH -H 'Content-Type: application/yang-data+json' \
    -d '{"ietf-restconf:data":{"openconfig-lldp:lldp":{
          "config":{"hello-timer":10,"system-name":"core-1",
                    "suppress-tlv-advertisement":["openconfig-lldp-types:MANAGEMENT_ADDRESS"]},
          "interfaces":{"interface":[{"name":"lan8","config":{"name":"lan8","enabled":false}}]}}}}' \
    https://192.168.1.1/restconf/data
```

Back to the factory settings:

```sh
curl -k -u ops -X DELETE https://192.168.1.1/restconf/data/openconfig-lldp:lldp
```

The neighbors of `lan5`:

```sh
curl -k -u ops -H 'Accept: application/yang-data+json' \
    https://192.168.1.1/restconf/data/openconfig-lldp:lldp/interfaces/interface=lan5/neighbors
```

## SNMP

While the [SNMP agent](snmp.md) is on, it also answers LLDP-MIB (IEEE
802.1AB): what the switch announces, and the neighbors of each port.
LLDP-MIB lives below `1.0.8802.1.1.2`, outside `1.3.6.1`, so the SNMP view
has to include `1.0.8802` (see [Users, groups and views](snmp.md#users-groups-and-views)).

## Not supported

Rejected when you commit:

- setting the chassis ID (`chassis-id`, `chassis-id-type`): it is always
  the switch's MAC address
- leaving out other parts than the management address and the capabilities

Not available at all: CDP, EDP, FDP and SONMP (the switch neither sends nor
understands them), LLDP-MED (the extensions for IP phones), custom TLVs,
setting the TTL other than through the interval, and LLDP traps.
