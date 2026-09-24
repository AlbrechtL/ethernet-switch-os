# CLI basics

!!! bug "Known problem"
    In the current firmware the CLI on the switch rejects most numbers (VLAN ids, spanning tree timers), `snmp` is missing, and `show compare` fails. See [Known problems](../reference/limitations.md#known-problems-in-the-current-firmware) for workarounds.

The CLI is generated from the switch's YANG data models. Every setting has a
path, and CLI commands spell that path out word by word. For example, the
access VLAN of port `lan3` is set with:

```text
switch> set interfaces interface lan3 ethernet switched-vlan config access-vlan 20
```

The words are the same as in the RESTCONF API and the OpenConfig
documentation, so what you learn here carries over.

## Getting help

- **`?`** lists what can come next, with a short description:

    ```text
    switch> set ?
      interfaces            Top level container for interfaces, including configuration
                            and state data.
      port-based-vlans      Port-based VLAN groups, used in vlan-mode PORT_BASED only.
      snmp                  Top-level container for SNMP-related configuration and
                            status objects.
      stp                   Top-level container for spanning tree configuration and
                            state data
      switch                Switch-wide settings.
      system                The switch as a whole.
      vlans                 Container for VLAN configuration and state
                            variables
    ```

- **TAB** completes the current word, including list keys that already
  exist (port names, VLAN ids) and values with a fixed set of choices.

- Both are the fastest way to find a setting. For values such as spanning
  tree protocols, `?` shows the exact spelling to type (descriptions left
  out here):

    ```text
    switch> set stp global config enabled-protocol ?
      <enabled-protocol>
      oc-stp-types:MSTP
      oc-stp-types:RAPID_PVST
      oc-stp-types:RSTP
      sw:STP
    ```

The model offers more settings than the switch implements.
`?` also shows settings that the switch rejects when you commit.
[Supported configuration](../reference/supported-configuration.md) lists
what works.

## Candidate, running, startup

The switch keeps three copies of its configuration:

| Configuration | What it is | Changed by |
|---|---|---|
| **candidate** | Your workspace. Changes here have no effect yet. | `set`, `delete`, `merge`, `create` |
| **running** | What the switch is doing right now. | `commit` (copies candidate → running) |
| **startup** | What the switch loads when it boots. | `save` (copies running → startup) |

So every change takes up to three steps:

```text
switch> set vlans vlan 20 config vlan-id 20
switch> commit
switch> save
```

1. `set` changes the candidate. Nothing happens yet, and you can make as many
   changes as you like.
2. `commit` checks the whole candidate and, if it is valid, applies it at
   once. If it is not valid, nothing changes and an error explains why.
3. `save` makes the running configuration permanent. **Without `save`, a
   reboot brings back the previous configuration.**

!!! tip "Not saving is a safety net"
    If a committed change locks you out, power-cycle the switch. It
    boots with the last saved configuration.

`discard` throws away all uncommitted changes in the candidate, and resets
it to the running configuration.

Because the candidate is only checked as a whole, you can make changes that
depend on each other in any order. For example, you can switch
[VLAN modes](vlans.md#port-based-vlans), which changes almost everything at
once.

## Editing commands

| Command | Effect |
|---|---|
| `set <path> <value>` | Sets a value. Creates the list entries on the path if needed. |
| `merge <path> <value>` | Same as `set` in practice. |
| `create <path> <value>` | Like `set`, but fails with `Data already exists` if the item is already set. |
| `delete <path>` | Removes an item or a whole subtree. |
| `delete all` | Removes the **whole** candidate configuration. |

To delete a single value, give the value too:

```text
switch> delete interfaces interface lan8 ethernet switched-vlan config access-vlan 1
```

To delete a list entry or a container with everything in it, stop at its
name:

```text
switch> delete vlans vlan 30
switch> delete interfaces interface lan8 ethernet switched-vlan
```

Put values with spaces in double quotes:

```text
switch> set system config location "Rack 3, room 101"
```

!!! warning "`delete all` followed by `commit`"
    An empty configuration is valid. Committing it takes every port out of
    the bridge and removes the management address, which cuts off your
    session. `delete all` is only useful when you are building a new
    configuration in the same candidate before the commit.

## Checking before you commit

| Command | Shows |
|---|---|
| `validate` | Checks the candidate as `commit` would, without applying it. |
| `show compare` | The difference between running and candidate: `-` lines go away, `+` lines are new. |

```text
switch> set system config location "Rack 4"
switch> show compare
      config {
-        location "Rack 3, room 101";
+        location "Rack 4";
      }
```

## Showing the configuration

| Command | Shows |
|---|---|
| `show configuration` | The candidate, in text form. |
| `show configuration cli` | The candidate, as the `set` commands that would create it. |
| `show configuration json` / `xml` / `text` | The candidate, in that format. |
| `show startup` | The saved configuration. |
| `show state` | The running configuration together with live status (counters, DHCP lease, spanning tree roles, uptime …). Also as `show state text` / `json` / `xml`. |

You can narrow each `show` to a part of the tree by adding a path after the
format:

```text
switch> show configuration cli interfaces interface lan8
interface lan8
interface lan8 config name lan8
interface lan8 config type ianaift:ethernetCsmacd
interface lan8 config enabled true
interface lan8 ethernet switched-vlan config interface-mode ACCESS
interface lan8 ethernet switched-vlan config access-vlan 1

switch> show state text interfaces interface vlan1
switch> show state text system
```

!!! tip "Let the switch write the commands for you"
    `show configuration cli` prints `set` commands without the leading
    `set`. To copy a configuration from one switch to another, or to find
    the right syntax for something already configured, run it, put `set `
    in front of each line and paste the lines into the CLI.

`show state` can only narrow down along configuration paths. To see the
status of `lan3`, show the whole interface
(`show state text interfaces interface lan3`); `... lan3 state` is not
accepted.

## When a commit fails

A failed commit prints the reason and leaves both running and candidate as
they were. Fix the candidate and commit again, or `discard`.

```text
switch> set interfaces interface lan3 ethernet switched-vlan config access-vlan 20
switch> commit
Sep 24 18:48:51.390887: clicon_rpc_commit: 1548: Netconf error: Commit failed.
Edit and try again or discard changes: application operation-failed validate:
interface lan3: VLAN 20 is not declared in vlans
```

The useful part is at the end, after `validate:`. It names the item (here
`interface lan3`) and the problem. Several problems are separated by `;`.

Two other kinds of errors come from the data model itself, not from the
switch:

- `WHEN condition failed, xpath is ../interface-mode = 'ACCESS' ... error-path: .../access-vlan`:
  a value that is only allowed in a certain case, here an `access-vlan` on a
  port that is not in access mode. `error-path` says which one.
- `Identityref validation failed, RSTP not derived from STP_PROTOCOL`: a
  value that needs its prefix, here `oc-stp-types:RSTP` instead of `RSTP`.
  Use `?` to see the right spelling.

While the candidate holds an invalid change, `show` commands may print
`CLI command error` lines. They go away once the candidate is valid again.

## Leaving

`quit` leaves the CLI. Uncommitted changes in the candidate are **not**
lost. All CLI sessions share one candidate, and it keeps your changes until
someone commits or discards them. Before you leave, `commit` or `discard`,
so the next person does not find your half-done changes.
