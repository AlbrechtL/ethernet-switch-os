# Spanning tree

!!! bug "Known problem"
    In the current firmware the CLI on the switch rejects the timers, `hold-count`, `max-hop`, `cost`, `port-priority` and MSTI ids. Turning a protocol on, `bridge-priority` and the port features work. See [Known problems](../reference/limitations.md#known-problems-in-the-current-firmware).

Spanning tree finds loops between switches and blocks ports so that frames
cannot circle forever. It is **off** by factory default. Turn it on if the
switch is connected to other switches over more than one path, or if loops
could happen by mistake.

Three protocols are available. Only one can be on at a time:

| Protocol | Value for `enabled-protocol` | Configured under |
|---|---|---|
| RSTP, IEEE 802.1w (recommended) | `oc-stp-types:RSTP` | `stp rstp` |
| MSTP, IEEE 802.1s | `oc-stp-types:MSTP` | `stp mstp` |
| STP, IEEE 802.1D (legacy) | `sw:STP` | `stp rstp` (same settings as RSTP) |

RSTP and MSTP fall back to classic STP on their own on ports that face an
old 802.1D switch.

All switch ports take part in spanning tree. Per-port settings are only
needed to change the defaults.

## Turn on RSTP

```text
switch> set stp global config enabled-protocol oc-stp-types:RSTP
switch> commit
switch> save
```

That is enough for most networks. To make this switch the root bridge,
give it a lower priority than the others (default 32768):

```text
switch> set stp rstp config bridge-priority 4096
switch> commit
```

### Bridge settings

| Setting | Default | Allowed |
|---|---|---|
| `bridge-priority` | 32768 | 0 … 61440 in steps of 4096. Lower wins the root election. |
| `hello-time` | 2 | 2 only |
| `max-age` | 20 | Must satisfy `max-age <= 2 × (forwarding-delay − 1)` |
| `forwarding-delay` | 15 | See `max-age` |
| `hold-count` | 6 | |

All under `stp rstp config`, for example
`set stp rstp config forwarding-delay 10`. Values that break the rules are
rejected with an explanation:

```text
validate: stp: rstp: bridge-priority 5000 is not a multiple of 4096 in 0..61440
validate: stp: rstp: max-age 20 is greater than 2 * (forwarding-delay 10 - 1)
```

### Port cost and priority

These change which port is blocked when there is a loop. Set them per
port under `stp rstp interfaces`:

```text
switch> set stp rstp interfaces interface lan3 config name lan3
switch> set stp rstp interfaces interface lan3 config cost 20000
switch> set stp rstp interfaces interface lan3 config port-priority 64
switch> commit
```

- `cost`: path cost. Without it, the cost follows the link speed.
- `port-priority`: a multiple of 16, default 128. Lower is preferred.

## Port features

These apply to all protocols and are set under `stp interfaces`:

```text
switch> set stp interfaces interface lan8 config name lan8
switch> set stp interfaces interface lan8 config edge-port oc-stp-types:EDGE_ENABLE
switch> commit
```

| Setting | Values | Meaning |
|---|---|---|
| `edge-port` | `oc-stp-types:EDGE_AUTO` (default), `oc-stp-types:EDGE_ENABLE`, `oc-stp-types:EDGE_DISABLE` | An edge port has an end device, not a switch, behind it and forwards at once. `EDGE_AUTO` detects this. Set `EDGE_ENABLE` on ports to PCs to save the start-up delay. |
| `link-type` | `P2P`, `SHARED` | Whether the port is a point-to-point link. Detected automatically when unset. |
| `guard` | `ROOT`, `NONE` | Root guard: the port may never become the root port. Blocks a foreign switch from taking over the root role. |
| `bpdu-guard` | `true`, `false` | Shut the port down when a spanning tree frame (BPDU) arrives. For ports where no switch may be connected. |
| `bpdu-filter` | `true`, `false` | Neither send nor process BPDUs on the port. Use with care: this can create loops. |

`bpdu-guard` and `bpdu-filter` can also be turned on for all ports at once
under `stp global config`. A port setting overrides the global one.

## MSTP

MSTP runs several spanning tree instances (MSTIs), each for a group of
VLANs, so different VLANs can use different paths. All switches of an
MSTP **region** must have the same region name, revision and VLAN-to-MSTI
mapping.

```text
switch> set stp global config enabled-protocol oc-stp-types:MSTP
switch> set stp mstp config name region1
switch> set stp mstp config revision 1
switch> set stp mstp config bridge-priority 8192
switch> set stp mstp mst-instances mst-instance 1 config mst-id 1
switch> set stp mstp mst-instances mst-instance 1 config vlan 20
switch> set stp mstp mst-instances mst-instance 1 config vlan 30..40
switch> set stp mstp mst-instances mst-instance 1 config bridge-priority 4096
switch> commit
```

- `stp mstp config` holds the region (`name`, `revision`), `max-hop`
  (6 … 40, default 20), the timers (as for RSTP), and `bridge-priority`
  of the common spanning tree (CIST). VLANs that are in no MSTI belong
  to the CIST.
- `mst-instance <id>` (1 … 4094) has its `vlan` list (ids and `x..y`
  ranges) and its own `bridge-priority`. A VLAN belongs to at most one MSTI.
  The list counts as written, whether the VLANs are declared or not, because
  it has to match the other switches of the region.
- Port cost and priority per MSTI: `mst-instance 1 interfaces interface lan8 config ...`.
  For the CIST: `stp mstp interfaces interface lan8 config ...`.

## Change protocol or turn it off

`enabled-protocol` is a list. To switch protocols, delete the old entry and
add the new one before you commit. Two entries are rejected
(`only one protocol may be enabled`):

```text
switch> delete stp global config enabled-protocol oc-stp-types:RSTP
switch> set stp global config enabled-protocol oc-stp-types:MSTP
switch> commit
```

To turn spanning tree off, delete the entry and commit. The settings of
the protocols can stay; they have no effect while their protocol is not
enabled.

## Status

```text
switch> show state text stp
...
   rstp {
      state {
         hello-time 2;
         max-age 20;
         forwarding-delay 15;
         hold-count 6;
         bridge-priority 4096;
         bridge-address 92:b6:82:b9:ac:79;
         designated-root-priority 4096;
         designated-root-address 92:b6:82:b9:ac:79;
         root-cost 0;
         topology-changes 0;
      }
      interfaces {
         interface lan1 {
            state {
               name lan1;
               port-priority 128;
               port-num 1;
               role oc-stp-types:DESIGNATED;
               port-state oc-stp-types:FORWARDING;
               ...
               forward-transisitions 1;
               counters {
                  bpdu-sent 10;
                  bpdu-received 0;
               }
            }
         }
...
```

Here the switch is the root bridge itself: the root address is its own,
and there is no `root-port`. Ports without a link show `port-state
oc-stp-types:DISABLED` and no role.

For the bridge (under `rstp state`, or `mstp state` for the CIST, and per
`mst-instance`):

| Field | Meaning |
|---|---|
| `bridge-address`, `bridge-priority` | This switch. |
| `designated-root-address`, `designated-root-priority` | The root bridge. If it equals the bridge, this switch is the root. |
| `root-port`, `root-cost` | The port towards the root and the path cost to it. |
| `topology-changes` | How often the topology changed. |

And per port (under `... interfaces interface lanN state`):

| Field | Meaning |
|---|---|
| `role` | `ROOT`, `DESIGNATED`, `ALTERNATE` or `BACKUP` |
| `port-state` | `FORWARDING`, `LEARNING`, `BLOCKING` (RSTP's "discarding"), `DISABLED` |
| `cost`, `port-priority`, `port-num` | Values in use |
| `designated-*` | The bridge and port this port hears from |
| `forward-transisitions` | How often the port went to forwarding (spelled this way in OpenConfig) |
| `counters`: `bpdu-sent`, `bpdu-received` | Spanning tree frames counted |

## Not supported

Rapid PVST, loop guard, bridge assurance, EtherChannel guard and automatic
recovery after BPDU guard are rejected, for example
`stp/global/config/loop-guard true is not supported, only false`.
