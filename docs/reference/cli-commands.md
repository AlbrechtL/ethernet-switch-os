# CLI commands

All commands of the CLI. `<path>` is a path through the data model, as
described in [CLI basics](../cli/basics.md). Use `?` and TAB to build it.

## Editing the candidate

| Command | Effect |
|---|---|
| `set <path> <value>` | Set a value; creates missing list entries on the way. |
| `merge <path> <value>` | Merge a value into the candidate. |
| `create <path> <value>` | Like `set`, but fails if the item is already set. |
| `delete <path> [<value>]` | Delete an item, a list entry or a whole subtree. A single value needs the value itself. |
| `delete all` | Delete the whole candidate configuration. |

## Applying

| Command | Effect |
|---|---|
| `validate` | Check the candidate without applying it. |
| `commit` | Check the candidate and apply it: candidate → running. |
| `discard` | Throw away uncommitted changes: running → candidate. |
| `save` | Make the running configuration permanent: running → startup. |

## Showing

| Command | Shows |
|---|---|
| `show configuration [<path>]` | The candidate, as text. |
| `show configuration text\|cli\|json\|xml [<path>]` | The candidate in that format. `cli` prints the commands that create it. |
| `show compare` | Differences between running and candidate. |
| `show startup` | The saved configuration. |
| `show state [<path>]` | The running configuration with live status, as text. |
| `show state text\|json\|xml [<path>]` | The same in that format. |
| `show version` | Version of clixon and CLIgen (not the firmware; see [System](../cli/system.md)). |
| `show memory cli\|backend` | Memory use of the CLI or the configuration daemon. |

## Other

| Command | Effect |
|---|---|
| `quit` | Leave the CLI. |
| `debug level <n>` | Turn on debug output of the configuration daemon (for developers). |
| `debug` / `no debug` | Turn CLI debug output on or off. |

## Top-level paths

| Path | Chapter |
|---|---|
| `interfaces` | [Ports](../cli/interfaces.md), [Management IP address](../cli/ip.md), [VLANs](../cli/vlans.md) |
| `vlans` | [VLANs](../cli/vlans.md) |
| `switch` | [VLANs](../cli/vlans.md#port-based-vlans) (VLAN mode) |
| `port-based-vlans` | [VLANs](../cli/vlans.md#port-based-vlans) |
| `stp` | [Spanning tree](../cli/spanning-tree.md) |
| `snmp` | [SNMP](../cli/snmp.md) |
| `system` | [System](../cli/system.md) |
