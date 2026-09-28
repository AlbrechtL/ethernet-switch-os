# System information

The switch reports what it is and how it is doing: host name, firmware
version, uptime, load, memory and clock. Two settings describe it for the
people who run it: **contact** (who is responsible) and **location** (where
it is). SNMP reports them as `sysContact` and `sysLocation`.

Contact and location are each one line of up to 255 characters. Line breaks
and other control characters are rejected. Both are empty by factory
default.

| Field | Name in the data model | Meaning |
|---|---|---|
| Host name | `hostname` | The switch's host name. Fixed by the firmware; it cannot be configured yet. |
| Firmware | `os-name`, `os-version` | The firmware and its version. There are no releases yet, so the version is a base version and the git revision of `meta-ethernet-switch-os` the firmware was built from. |
| Build id | `os-build-id` | That revision on its own. Once releases are tagged, the version is the tag and this stays the commit. |
| Kernel | `kernel-release` | Linux kernel version. |
| Clock | `current-datetime` | In UTC. The switch has no battery-backed clock and no time synchronisation, so it starts at the same fixed time on every boot (2018-03-09 12:34:56 UTC in the current firmware). |
| Uptime | `uptime` | Seconds since boot. |
| Load | `load-average-1`, `-5`, `-15` | CPU load over 1, 5 and 15 minutes. |
| Memory | `memory-total`, `memory-available` | RAM in kilobytes. |

A switch also carries `/etc/buildinfo`, which names the branch and revision
of every layer the firmware was built from, not just the one in the version.
It is readable in the `root` shell.

## Web UI

The **System** card of the [status page](../getting-started/web-ui.md#status-page)
shows the fields above, with the clock in your browser's time zone. Its
**Edit** button changes contact and location. The host name cannot be
changed.

## CLI

### Contact and location

```text
switch> set system config contact "Network team, noc@example.com"
switch> set system config location "Rack 3, room 101"
switch> commit
switch> save
```

### Status

```text
switch> show state text system
clixon-switch:system {
   config {
      contact "Network team, noc@example.com";
      location "Rack 3, room 101";
   }
   state {
      contact "Network team, noc@example.com";
      location "Rack 3, room 101";
      hostname zyxel-gs1900-8-a1;
      os-name "Ethernet Switch OS";
      os-version 0.0.0-3eae8394;
      os-build-id 3eae8394;
      kernel-release 6.18.39-yocto-tiny;
      current-datetime 2018-03-09T12:36:02Z;
      uptime 67;
      load-average-1 0.22;
      load-average-5 0.07;
      load-average-15 0.02;
      memory-total 122528;
      memory-available 52168;
   }
}
```

`show version` shows the version of the configuration software (clixon),
not the firmware version.

## RESTCONF

!!! note "Coming later"
    Examples are not written yet. See [Using RESTCONF](../getting-started/restconf.md)
    for how the CLI paths above map to RESTCONF resources.

The feature is configured under:

```text
/restconf/data/clixon-switch:system
```

For example, the firmware version:

```sh
curl -sk -u ops https://192.168.1.1/restconf/data/clixon-switch:system/state/os-version
```
