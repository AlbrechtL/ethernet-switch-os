# SNMP

!!! bug "Known problem"
    In the current firmware `snmp` is missing from the CLI. Until this is fixed, configure SNMP over RESTCONF, see [Known problems](../reference/limitations.md#known-problems-in-the-current-firmware).

The switch has a read-only **SNMPv3** agent for monitoring tools. It is
**off** by factory default. SNMP can only read: the configuration is changed
through the CLI, RESTCONF or the [web page](../web-ui.md#snmp) only.

What it answers:

| MIB | Content |
|---|---|
| SNMPv2-MIB, system group | Description, uptime, `sysContact`, `sysLocation`, `sysName` (the host name) |
| IF-MIB | Ports and their counters |
| BRIDGE-MIB | Bridge address, ports (`dot1dBasePort` 1 is `lan1`), forwarding database, and spanning tree while it runs |
| Q-BRIDGE-MIB | Configured and active VLANs, port VLAN ids, forwarding database per VLAN |
| RSTP-MIB | Protocol version and per-port edge and point-to-point status, while spanning tree runs |

## How SNMPv3 security works here

SNMPv3 users log in with two passphrases: one for authentication (SHA) and
one for encryption (AES). The switch does **not** store these passphrases.
It stores **keys** derived from each passphrase and the switch's
**engine ID** (RFC 3414). This has two consequences:

- You compute the keys on your own computer. The passphrases never go to
  the switch.
- Keys belong to one engine ID. If the engine ID changes, you have to
  compute the keys again.

So the order is: choose the engine ID, compute the keys, configure the
switch.

## Set up SNMP

### 1. Choose the engine ID

Either set one yourself, which is recommended because keys then survive a
hardware exchange:

```text
switch> set snmp engine engine-id 80:00:1f:88:04:73:77:31
```

`80:00:1f:88:04` followed by any text in hex is a valid engine ID
(`73:77:31` is "sw1"). An engine ID has 5 to 32 octets. Give every switch a
different one.

Or leave it out. The switch then derives one from its MAC address. Look it
up after SNMP is enabled:

```text
switch> show state text snmp engine
engine {
   ...
   clixon-switch:engine-id-in-use 80:00:1f:88:04:73:77:31;
}
```

### 2. Compute the keys

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

### 3. Configure the switch

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

### 4. Test

From your computer, with the net-snmp tools:

```text
$ snmpwalk -v3 -l authPriv -u nms -a SHA -A 'auth passphrase' -x AES -X 'priv passphrase' \
      192.168.1.1 1.3.6.1.2.1.1
$ snmpwalk -v3 -l authPriv -u nms -a SHA -A 'auth passphrase' -x AES -X 'priv passphrase' \
      192.168.1.1 1.3.6.1.2.1.17
```

## Common changes

**Restrict a view.** Views take numeric OIDs only. `exclude` cuts out part
of an `include`:

```text
switch> set snmp vacm view bridge include 1.3.6.1.2.1.17
switch> set snmp vacm view bridge exclude 1.3.6.1.2.1.17.4
```

**Change a group's access**, for example to allow unencrypted requests.
Once an `access ""` entry exists, the CLI cannot parse further commands for
it (`'usm' is not a number`). Delete the group and set it up again, in
the same commit:

```text
switch> delete snmp vacm group readers
switch> set snmp vacm group readers member nms security-model usm
switch> set snmp vacm group readers access "" usm auth-no-priv read-view all
switch> commit
```

**Add a user.** Compute its keys with the same engine ID, then add it
with its own `usm local user` entry and a `vacm group ... member` entry.

**Remove a user.**

```text
switch> delete snmp usm local user nms
switch> delete snmp vacm group readers member nms
switch> commit
```

While SNMP is enabled, at least one user must remain
(`snmp: usm: a local user is required while the engine is enabled`). To
remove the last one, turn SNMP off in the same commit.

**Turn SNMP off.**

```text
switch> set snmp engine enabled false
switch> commit
```

## Contact and location

`sysContact` and `sysLocation` come from the system settings, see
[System](system.md). `sysName` is the switch's host name.

## Not supported

Rejected when you commit:

- SNMPv1 and SNMPv2c, communities
- traps and informs (`notify`, `target`, `target-params`)
- write access (`write-view`), `notify-view`
- MD5 and DES, `no-auth-no-priv`
- contexts other than `""`, OID wildcards in views
- proxies, TLS/DTLS, remote users
