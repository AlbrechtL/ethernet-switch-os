# SNMP

The switch has a read-only **SNMPv3** agent for monitoring tools. It is
**off** by factory default. SNMP can only read: the configuration is
changed through the web UI, the CLI or RESTCONF.

What it answers:

| MIB | Content |
|---|---|
| SNMPv2-MIB, system group | Description, uptime, `sysContact`, `sysLocation`, `sysName` (the host name) |
| IF-MIB | Ports and their counters |
| BRIDGE-MIB | Bridge address, ports (`dot1dBasePort` 1 is `lan1`), forwarding database, and spanning tree while it runs |
| Q-BRIDGE-MIB | Configured and active VLANs, port VLAN ids, forwarding database per VLAN |
| RSTP-MIB | Protocol version and per-port edge and point-to-point status, while spanning tree runs |

`sysContact` and `sysLocation` come from the
[system information](system.md). `sysName` is the switch's host name.

### How SNMPv3 security works here

SNMPv3 users log in with two passphrases: one for authentication (SHA) and
one for encryption (AES). The switch does **not** store these passphrases.
It stores **keys** derived from each passphrase and the switch's
**engine ID** (RFC 3414). This has two consequences:

- The keys are computed outside the switch: by the browser in the web UI,
  or on your own computer for the CLI and RESTCONF. The passphrases never
  go to the switch.
- Keys belong to one engine ID. If the engine ID changes, the keys have to
  be computed again.

So the order is: choose the engine ID, compute the keys, configure the
switch.

### Engine ID

Either set one yourself, which is recommended because keys then survive a
hardware exchange, or leave it out. The switch then derives one from its
MAC address.

`80:00:1f:88:04` followed by any text in hex is a valid engine ID
(`80:00:1f:88:04:73:77:31` ends in "sw1"). An engine ID has 5 to 32 octets.
Give every switch a different one.

### Users, groups and views

Access is granted in three parts:

- A **user** has an authentication key (SHA, required) and optionally an
  encryption key (AES). Without the encryption key the user can only make
  unencrypted requests (`auth-no-priv`).
- A **group** has users as members, and grants them read access to a view,
  either only when they authenticate **and** encrypt (`auth-priv`) or also
  unencrypted (`auth-no-priv`).
- A **view** is a set of OID subtrees: numeric OIDs to include, and parts
  of them to exclude.

While SNMP is on, at least one user must exist
(`snmp: usm: a local user is required while the engine is enabled`).

### Test

From your computer, with the net-snmp tools:

```text
$ snmpwalk -v3 -l authPriv -u nms -a SHA -A 'auth passphrase' -x AES -X 'priv passphrase' \
      192.168.1.1 1.3.6.1.2.1.1
$ snmpwalk -v3 -l authPriv -u nms -a SHA -A 'auth passphrase' -x AES -X 'priv passphrase' \
      192.168.1.1 1.3.6.1.2.1.17
```

## Web UI

The **SNMP** card of the [status page](../getting-started/web-ui.md#status-page)
shows whether the agent is on, the engine ID, and the SNMP users.

- **Add user** creates a user. You type the two passphrases (at least 8
  characters each) in the dialog. The browser turns them into keys, and
  only the keys go to the switch. The user can read everything with
  `authPriv`, like user `nms` in the [CLI example](#configure-the-switch).
  For the first user, the dialog proposes an engine ID if none is set; use
  your own if you want, and give every switch a different one.
- **Delete** removes a user. Deleting the last user turns the agent off.
- **Turn on** / **Turn off** starts and stops the agent.

!!! note "Not in the web UI"
    Views, and groups other than the one the page creates, are configured
    with the [CLI](#cli) or [RESTCONF](#restconf).

## CLI

!!! bug "Known problem"
    In the current firmware `snmp` is missing from the CLI. Until this is fixed, configure SNMP over RESTCONF, see [Known problems](../limitations.md#known-problems-in-the-current-firmware).

### Choose the engine ID

```text
switch> set snmp engine engine-id 80:00:1f:88:04:73:77:31
```

Without one, look up the derived engine ID after SNMP is enabled:

```text
switch> show state text snmp engine
engine {
   ...
   clixon-switch:engine-id-in-use 80:00:1f:88:04:73:77:31;
}
```

### Compute the keys

On your computer, with `snmp-localize-key` from
[clixon-switch-rs](https://github.com/AlbrechtL/clixon-switch-rs/blob/master/scripts/snmp-localize-key)
(Python 3, no other dependencies):

```text
$ ./snmp-localize-key --engine-id 80:00:1f:88:04:73:77:31 \
      --auth 'auth passphrase' --priv 'priv passphrase'
auth sha key: 98:ee:4f:0a:b9:a7:6b:bf:61:e1:46:e1:3b:92:8e:ff:81:73:03:ee
priv aes key: 1c:ee:55:a4:50:94:f9:54:c5:9b:dd:4a:b8:7c:c3:38
```

Without `--auth` and `--priv`, it asks for the passphrases instead, so they
do not end up in your shell history. Passphrases need at least
8 characters. An empty `priv` passphrase at the prompt means no encryption
key.

### Configure the switch

This creates user `nms` with read access to everything:

```text
switch> set snmp engine enabled true
switch> set snmp engine engine-id 80:00:1f:88:04:73:77:31
switch> set snmp engine version v3
switch> set snmp engine listen all udp ip 0.0.0.0
switch> set snmp usm local user nms auth sha key 98:ee:4f:0a:b9:a7:6b:bf:61:e1:46:e1:3b:92:8e:ff:81:73:03:ee
switch> set snmp usm local user nms priv aes key 1c:ee:55:a4:50:94:f9:54:c5:9b:dd:4a:b8:7c:c3:38
switch> set snmp vacm group readers member nms security-model usm
switch> set snmp vacm group readers access "" usm auth-priv read-view all
switch> set snmp vacm view all include 1.3.6.1
switch> commit
switch> save
```

Line by line:

| Command | Meaning |
|---|---|
| `engine enabled true` | Starts the agent. |
| `engine version v3` | Required. SNMPv3 is the only version. |
| `engine listen all udp ip 0.0.0.0` | A listener named `all` on UDP port 161 of every address. Use one of the switch's addresses to listen only there; add `port <n>` for another port. |
| `usm local user nms auth sha key …` | User `nms` with its authentication key. Required for every user. |
| `usm local user nms priv aes key …` | Its encryption key. Optional, but without it the user can only use `auth-no-priv`. |
| `vacm group readers member nms security-model usm` | Puts `nms` into group `readers`. |
| `vacm group readers access "" usm auth-priv read-view all` | Members of `readers` may read view `all` when they authenticate **and** encrypt. The `""` is the context, which must be empty. Use `auth-no-priv` to allow unencrypted requests. |
| `vacm view all include 1.3.6.1` | View `all` is everything below `1.3.6.1`. |

### Restrict a view

Views take numeric OIDs only. `exclude` cuts out part of an `include`:

```text
switch> set snmp vacm view bridge include 1.3.6.1.2.1.17
switch> set snmp vacm view bridge exclude 1.3.6.1.2.1.17.4
```

### Change a group's access

For example, to allow unencrypted requests. Once an `access ""` entry
exists, the CLI cannot parse further commands for it
(`'usm' is not a number`). Delete the group and set it up again, in the
same commit:

```text
switch> delete snmp vacm group readers
switch> set snmp vacm group readers member nms security-model usm
switch> set snmp vacm group readers access "" usm auth-no-priv read-view all
switch> commit
```

### Add a user

Compute its keys with the same engine ID, then add it with its own
`usm local user` entry and a `vacm group ... member` entry.

### Remove a user

```text
switch> delete snmp usm local user nms
switch> delete snmp vacm group readers member nms
switch> commit
```

To remove the last user, turn SNMP off in the same commit.

### Turn SNMP off

```text
switch> set snmp engine enabled false
switch> commit
```

## RESTCONF

!!! note "Coming later"
    Examples are not written yet. See [Using RESTCONF](../getting-started/restconf.md)
    for how the CLI paths above map to RESTCONF resources.

SNMP is configured under:

```text
/restconf/data/ietf-snmp:snmp
```

The keys are computed as for the CLI. The
[clixon-switch-rs README](https://github.com/AlbrechtL/clixon-switch-rs#snmp)
has an example that sets up a user.

## Not supported

Rejected when you commit:

- SNMPv1 and SNMPv2c, communities
- traps and informs (`notify`, `target`, `target-params`)
- write access (`write-view`), `notify-view`
- MD5 and DES, `no-auth-no-priv`
- contexts other than `""`, OID wildcards in views
- proxies, TLS/DTLS, remote users
